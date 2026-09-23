# Pronunciation models

Pronunciation practice runs one acoustic model per language, on the device.
Everything else it needs — the prompts' phonemes, the model's vocabulary, the
curves that turn a log posterior into 0–100 — is data in the lexicon the app
bundles. This page records which models those are, where they came from, what
was done to them, and what has to change together when one of them changes.

How the scoring itself works (GOP over a forced alignment) is in
[scorer/README.md](../scorer/README.md), and the app side in
`flutter_full_stack_flutter/lib/core/pronunciation/`.

## What ships

| | English | Spanish |
|---|---|---|
| Upstream model | [`facebook/wav2vec2-lv-60-espeak-cv-ft`](https://huggingface.co/facebook/wav2vec2-lv-60-espeak-cv-ft) | [`facebook/wav2vec2-xlsr-53-espeak-cv-ft`](https://huggingface.co/facebook/wav2vec2-xlsr-53-espeak-cv-ft) |
| Upstream commit | `ae45363bf3413b374fecd9dc8bc1df0e24c3b7f4` | `2c733782da5604684829819a5eb744c193fe9398` |
| Licence | Apache-2.0 | Apache-2.0 |
| Pre-trained on | `wav2vec2-large-lv60` — Libri-Light, English audiobooks | `wav2vec2-large-xlsr-53` — 53 languages |
| Fine-tuned on | Common Voice, multilingual, to espeak phoneme labels | the same |
| Paper | Xu, Baevski, Auli, *Simple and Effective Zero-shot Cross-lingual Phoneme Recognition*, [arXiv:2109.11680](https://arxiv.org/abs/2109.11680) | the same |
| File the app downloads | `phoneme_en_r2.int8.onnx` | `phoneme_es_r2.int8.onnx` |
| Size | 354,930,937 bytes | 354,930,937 bytes |
| SHA-256 | `8fb6b418aa5c1b5d9786728be1b35d21e7c1e9a2a14d2dd5e8f2af0387aa43f3` | `cf032b3ffd234e4fcf57fba3af2285a19236eb66896086eea95b0af726712e0f` |

The commits are pinned in `UPSTREAM_REVISIONS` in
[scorer/src/gop/acoustic.py](../scorer/src/gop/acoustic.py), so an export redone
later starts from the same weights. `r2` in the file name is the revision of
*our* export, not of the upstream model: see [Changing a model](#changing-a-model).

The two models are the same architecture, wav2vec2-large with a CTC head over
the same 392-symbol IPA vocabulary, which is why the two files are the same
size to the byte. They differ in pre-training: `lv-60` saw only English, so it
is the stronger of the two on English; `xlsr-53` is multilingual, which is what
makes it the stronger on Spanish.

## What our export changes

The file the app downloads is a modified version of the upstream weights, made
by [scorer/tool/export_onnx.py](../scorer/tool/export_onnx.py):

- **Weight norm removed** from the positional convolution, folding `g · v/‖v‖`
  into a plain weight. Without that, the quantiser refuses the graph.
- **Exported to ONNX**, opset 17, with the audio length and the frame count as
  dynamic axes. Input `input_values`, float32 `[1, samples]`; output `logits`,
  float32 `[1, frames, 392]`.
- **Quantised to int8 dynamically, `MatMul` only**: 146 `MatMulInteger` nodes,
  while the 8 convolutions of the feature extractor stay float. Quantising
  `Conv` produces `ConvInteger`, which ONNX Runtime on Android has no kernel
  for; the export fails if one is left in the graph.
- **No log-softmax and no input normalisation in the graph.** The app does both
  (`OnnxPhonemeModel.normalise` and `logSoftmax`), matching what
  `Wav2Vec2FeatureExtractor` does with `do_normalize`.

The cost of the quantisation, measured in English only: the native sample
scores 84.3 in fp32 and 83.4 in int8. See the numbers in the scorer README.

## The contract between model, lexicon and calibration

Three things are only valid for the exact file they were made with:

| What | Where | Why it is tied to the model |
|---|---|---|
| Vocabulary, 392 symbols, and `blankId` 0 | `assets/lexicons/<lang>.json` | Token ids index the model's output columns. |
| Each prompt's target token ids | the same file | They are those ids, per phoneme. |
| Per-phoneme calibration curves | `scorer/calibration/<lang>.json`, copied into the lexicon | Medians of *this* model's log posteriors. |

The lexicon names its model by file name, and the app never re-downloads a file
it already has: `ModelStore.ensure` returns whatever is on disk under that name.
A changed model under an old name would therefore stay stale on every device
that has the old one, scored against curves fitted to the new one.

The runtime contract the app assumes: 16 kHz mono PCM in, one frame per 320
samples (20 ms) out.

## Changing a model

Any change to the weights or to the export — another upstream model or commit,
another quantisation, a fix to the export — is a new model:

1. Change `MODELS` / `UPSTREAM_REVISIONS` if the source changes, and **bump
   `MODEL_REVISION`** in `acoustic.py` (`r2` → `r3`) in every case.
2. `python tool/export_onnx.py <lang>` — writes `build/phoneme_<lang>_r3.int8.onnx`.
3. `python tool/check_int8.py` — int8 against fp32. It only covers English
   today (`LANG = "en"`).
4. `python tool/calibrate.py <lang> ...` — refits `calibration/<lang>.json`.
   The corpora and flags are in the scorer README.
5. `python tool/build_lexicon.py exercises/<lang>.json > ../flutter_full_stack_flutter/assets/lexicons/<lang>.json`
   — picks up the new file name, vocabulary and curves.
6. `python tool/evaluate.py` — agreement with human raters, English only.
7. Publish the file on the model host, and update the size and SHA-256 above.
8. `melos run check`.

The lexicon build is deterministic. With the pinned revisions and the local
Hugging Face cache, `HF_HUB_OFFLINE=1 python tool/build_lexicon.py` reproduces
the shipped lexicons byte for byte, which is a quick way to check that nothing
upstream moved.

## Serving and storage

- **Development:** `scorer/tool/serve_models.sh` serves `scorer/build/` over
  plain HTTP on the LAN and prints the URL to use. The app takes it from
  `--dart-define=MODEL_BASE_URL=...` or `modelBaseUrl` in
  `assets/config.json`.
- **Production:** not set up yet. `assets/config.json` points at a LAN address,
  and the app does not verify the SHA-256 above after a download.
- **On the device:** `getApplicationSupportDirectory()/pronunciation_models`,
  excluded from backups on both platforms (see AGENTS.md).

## Runtime

`flutter_onnxruntime` 1.8.5, which bundles ONNX Runtime **1.23.0** on both
Android (Maven) and iOS (CocoaPods). The session asks for XNNPACK with CPU as
fallback and up to four threads.

The toolchain exports and checks with ONNX Runtime **1.30.0** on desktop. The
int8 parity has been measured there, not on the runtime the phones run.

## Data behind the curves

None of these datasets ships. What ships is derived from some of them: the
per-phoneme curves, which are summary statistics (a centre and a scale per
phoneme) of log posteriors measured on their audio.

The calibration files do not record which corpus or how many utterances they
were fitted on. The table gives what `scorer/tool/fetch_corpus.sh` downloads
for each language, which is the only corpus the calibration command is
documented against. The scorer README gives the English command line
(`--limit 700`); nothing records the one used for Spanish.

| Data | Licence | Used for | In the app? |
|---|---|---|---|
| [LibriSpeech](https://www.openslr.org/12) `test-clean` | CC BY 4.0 | English native medians | as curves |
| [OpenSLR 71](https://www.openslr.org/71), Chilean Spanish, **female speakers only** | CC BY-SA 4.0 | Spanish native medians | as curves |
| [speechocean762](https://www.openslr.org/101) | CC BY 4.0 | agreement with human raters; the regression head | no |
| Common Voice | CC0 | the upstream fine-tuning | inside the weights |
| [espeak-ng](https://github.com/espeak-ng/espeak-ng), voices `en-us` and `es-419` | GPL-3.0-or-later | grapheme-to-phoneme at build time | no, only its output, as the lexicon's phonemes |

**Before publishing, ask legal whether curves fitted on the OpenSLR 71 data
fall under CC BY-SA 4.0's ShareAlike clause.** They are statistics of
measurements, not audio or transcripts, but whether that makes them outside the
licence is not an engineering call.

## Known limitations

- **Spanish curves come from female voices only**, all Chilean: `es_cl_female`
  is the only part of OpenSLR 71 the fetch script downloads. How far a male
  voice's native median sits from them has not been measured.
- **Spanish /ð/ has no curve of its own** and falls back on the global curve,
  although it appears in 5 of the 10 Spanish phrases.
- **English is scored against US pronunciation**, which espeak-ng's `en-us`
  voice gives: "beautiful" expects the flap /ɾ/, not a clear /t/.
- **Agreement with human raters has been measured once, in English, on
  Mandarin speakers**: Pearson 0.54 at sentence level, zero-shot. Nothing has
  been measured on Brazilian learners, and nothing at all in Spanish.
- **The Spanish int8 export has never been checked against fp32**, because
  `check_int8.py` only runs English.
- **The regression head** that reaches Pearson 0.675 is not in the app. It was
  trained on Mandarin speakers.

## Licences in the app

Flutter collects the `LICENSE` of every Dart package on its own. What reaches
the app another way is registered by hand in
[lib/app/licenses.dart](../flutter_full_stack_flutter/lib/app/licenses.dart),
and shown on the licences page behind the info button in the app bar:

- **The two models**, under Apache-2.0, preceded by the notice that they were
  modified and how, which section 4(b) asks for on top of the licence text.
- **ONNX Runtime**, MIT, copied from the `onnxruntime-c` pod.
- **Inter**, SIL Open Font License, from `assets/fonts/OFL.txt`.

**Not included: ONNX Runtime's `ThirdPartyNotices.txt`**, the licences of the
libraries compiled into its binary. The only copy at hand is the Python wheel's,
for 1.30.0, while the app ships 1.23.0; neither the Maven artifact nor the pod
carries one. Get the 1.23.0 file from the ONNX Runtime release and add it
before publishing.
