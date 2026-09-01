# Third-Party Licenses

Noteez uses the following third-party components. ONNX Runtime ships with the
app. Embedding models are optional downloads fetched directly from their
authors' Hugging Face repositories. The model download request contains no note
content.

## Optional on-device embedding models — intfloat/multilingual-e5

- **Source:** https://huggingface.co/intfloat/multilingual-e5-small
- **Alternative:** https://huggingface.co/intfloat/multilingual-e5-base
- **License:** MIT
- **Form downloaded:** publisher-provided int8 ONNX model and tokenizer JSON.
- **Integrity:** Noteez pins a repository revision and SHA-256 for every file
  listed in its model catalog.

Inference runs fully on-device; no note content leaves the machine.

## User-selected Hugging Face models

Noteez can discover additional compatible models but does not redistribute
them. A model is fetched only after the user chooses it, directly from its
publisher at a pinned revision. Noteez accepts only a small permissive-license
allowlist and displays the repository and license before download. Each model
remains subject to the license and terms shown by its publisher; Noteez's MIT
license does not relicense those files. Remote repository code is never run.

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
