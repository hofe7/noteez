#!/usr/bin/env python3
"""Run native Flutter model tests using local files or an explicitly selected verified catalog download."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from urllib.parse import unquote, urlparse


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument('--model', type=Path)
    source.add_argument('--catalog-model', choices=['multilingual-e5-small-qint8', 'multilingual-e5-base-qint8'], help='Download into a temporary directory, verify, evaluate and remove the model')
    parser.add_argument('--tokenizer', type=Path)
    parser.add_argument('--installed-directory', type=Path, help='Use local catalog artifacts after SHA-256 verification instead of downloading')
    parser.add_argument('--evaluate', action='store_true')
    parser.add_argument('--report', type=Path)
    parser.add_argument('--fixture', type=Path)
    parser.add_argument('--vector-cache', type=Path, help='Reuse synthetic embeddings only when fixture and model hashes match')
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    if args.vector_cache and not args.catalog_model:
        parser.error('--vector-cache requires --catalog-model')
    if args.installed_directory and not args.catalog_model:
        parser.error('--installed-directory requires --catalog-model')
    if args.model and not args.evaluate and (args.fixture or args.report):
        parser.error('--fixture and --report require --evaluate with local model files')
    if args.model and not args.tokenizer:
        parser.error('--model requires --tokenizer')
    if args.catalog_model and args.tokenizer:
        parser.error('--tokenizer cannot be combined with --catalog-model')
    for path in filter(None, (args.model, args.tokenizer)):
        if not path.is_file():
            parser.error(f'File not found: {path}')
    flutter = shutil.which('flutter')
    if flutter is None:
        parser.error('flutter must be on PATH')
    flutter_root = Path(flutter).resolve().parent.parent
    env = os.environ.copy()
    for key in ('NOTEEZ_TEST_MODEL_PATH', 'NOTEEZ_TEST_TOKENIZER_PATH', 'NOTEEZ_EVAL_CATALOG_MODEL', 'NOTEEZ_EVAL_REPORT', 'NOTEEZ_EVAL_FIXTURE', 'NOTEEZ_EVAL_VECTOR_CACHE'):
        env.pop(key, None)
    if args.model:
        env['NOTEEZ_TEST_MODEL_PATH'] = str(args.model.resolve())
        env['NOTEEZ_TEST_TOKENIZER_PATH'] = str(args.tokenizer.resolve())
    else:
        env['NOTEEZ_EVAL_CATALOG_MODEL'] = args.catalog_model
    if args.installed_directory:
        env['NOTEEZ_TEST_MODEL_PATH'] = str((args.installed_directory / 'model.onnx').resolve())
        env['NOTEEZ_TEST_TOKENIZER_PATH'] = str((args.installed_directory / 'tokenizer.json').resolve())
    if args.report:
        env['NOTEEZ_EVAL_REPORT'] = str(args.report.resolve())
    if args.fixture:
        env['NOTEEZ_EVAL_FIXTURE'] = str(args.fixture.resolve())
    if args.vector_cache:
        env['NOTEEZ_EVAL_VECTOR_CACHE'] = str(args.vector_cache.resolve())
    if sys.platform == 'darwin':
        config_path = root / '.dart_tool/package_config.json'
        config = json.loads(config_path.read_text())
        package = next(p for p in config['packages'] if p['name'] == 'onnxruntime')
        uri = urlparse(package['rootUri'])
        package_root = Path(unquote(uri.path)) if uri.scheme == 'file' else (config_path.parent / unquote(package['rootUri'])).resolve()
        # The Flutter shell launcher loses DYLD variables under macOS SIP.
        # Invoke its Dart entry point directly; use only the ONNX library folder.
        env['DYLD_LIBRARY_PATH'] = str(package_root / 'macos')
        command = [str(flutter_root / 'bin/cache/dart-sdk/bin/dart'),
                   str(flutter_root / 'bin/cache/flutter_tools.snapshot')]
    else:
        command = [flutter]
    tests = ['test/embedding_worker_local_test.dart'] if args.model else []
    if args.evaluate or args.catalog_model:
        tests.append('test/relevance_evaluation_test.dart')
    return subprocess.call(command + ['test', '--no-pub', '--concurrency=1', *tests], cwd=root, env=env)


if __name__ == '__main__':
    sys.exit(main())
