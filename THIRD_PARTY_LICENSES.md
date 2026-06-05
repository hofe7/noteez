# Third-Party Licenses

Noteez bundles the following third-party components. All are MIT-licensed and
may be redistributed in a commercial application provided this notice ships
with the app.

## On-device embedding model — intfloat/multilingual-e5-small

- **Source:** https://huggingface.co/intfloat/multilingual-e5-small
- **License:** MIT
- **Form bundled:** int8-quantized ONNX (`e5_int8.onnx`, ~113 MB) + tokenizer
  (`e5_tokenizer.json`, ~16 MB, XLM-RoBERTa unigram, 250,002-token vocab).
- **Identification (verified from the artifacts themselves):** 384-dimensional
  output, `input_ids`/`attention_mask`/`token_type_ids` inputs, XLM-RoBERTa
  Unigram tokenizer with a 250,002-entry vocabulary and Metaspace
  pre-tokenizer. Among the e5 family, only `multilingual-e5-small` matches a
  384-dim model paired with the XLM-R tokenizer.

The model runs fully on-device; no note content leaves the machine.

## ONNX Runtime

- **Source:** https://github.com/microsoft/onnxruntime (via the `onnxruntime`
  Dart/Flutter plugin)
- **License:** MIT
- **Copyright:** © Microsoft Corporation

---

Full MIT license text:

```
MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
