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

| | English | Spanish | Korean |
|---|---|---|---|
| Upstream model | [`facebook/wav2vec2-lv-60-espeak-cv-ft`](https://huggingface.co/facebook/wav2vec2-lv-60-espeak-cv-ft) | [`facebook/wav2vec2-xlsr-53-espeak-cv-ft`](https://huggingface.co/facebook/wav2vec2-xlsr-53-espeak-cv-ft) | [`facebook/wav2vec2-xlsr-53-espeak-cv-ft`](https://huggingface.co/facebook/wav2vec2-xlsr-53-espeak-cv-ft) |
| Upstream commit | `ae45363bf3413b374fecd9dc8bc1df0e24c3b7f4` | `2c733782da5604684829819a5eb744c193fe9398` | `2c733782da5604684829819a5eb744c193fe9398` |
| Licence | Apache-2.0 | Apache-2.0 | Apache-2.0 |
| Pre-trained on | `wav2vec2-large-lv60` — Libri-Light, English audiobooks | `wav2vec2-large-xlsr-53` — 53 languages | `wav2vec2-large-xlsr-53` — 53 languages, Korean among them |
| Fine-tuned on | Common Voice, multilingual, to espeak phoneme labels | the same | the same — **Korean was not in the fine-tuning**, so the model is zero-shot here |
| Paper | Xu, Baevski, Auli, *Simple and Effective Zero-shot Cross-lingual Phoneme Recognition*, [arXiv:2109.11680](https://arxiv.org/abs/2109.11680) | the same | the same |
| File the app downloads | `phoneme_en_r2.int8.onnx` | `phoneme_es_r2.int8.onnx` | `phoneme_ko_r2.int8.onnx` |
| Size | 354,930,937 bytes | 354,930,937 bytes | 354,930,937 bytes |
| SHA-256 | `8fb6b418aa5c1b5d9786728be1b35d21e7c1e9a2a14d2dd5e8f2af0387aa43f3` | `cf032b3ffd234e4fcf57fba3af2285a19236eb66896086eea95b0af726712e0f` | `cf032b3ffd234e4fcf57fba3af2285a19236eb66896086eea95b0af726712e0f` |

The commits are pinned in `UPSTREAM_REVISIONS` in
[scorer/src/gop/acoustic.py](../scorer/src/gop/acoustic.py), so an export redone
later starts from the same weights. `r2` in the file name is the revision of
*our* export, not of the upstream model: see [Changing a model](#changing-a-model).

The three models are the same architecture, wav2vec2-large with a CTC head over
the same 392-symbol IPA vocabulary, which is why the three files are the same
size to the byte. They differ in pre-training: `lv-60` saw only English, so it
is the stronger of the two on English; `xlsr-53` is multilingual, which is what
makes it the stronger on Spanish and the only candidate for Korean.

**The Korean file is byte-identical to the Spanish one** — same SHA-256,
because it is the same weights through the same export. It still ships under
its own name: the app stores packs by file name and never re-downloads a name
it has, and a shared file would couple the two languages' revisions forever.
355 MB twice on the host, and on the device of a learner who downloads both,
is the price of keeping the one-pack-per-language contract honest.

## Korean and the label map

Every other language here trusts the espeak-ng label as the canonical phoneme.
Korean cannot: espeak-ng and the model were born apart, and for several Korean
sounds the label espeak-ng writes is a column the model barely activates.
Measured on the Zeroth test split (457 utterances) with
[scorer/tool/fit_label_map.py](../scorer/tool/fit_label_map.py), which aligns
each utterance against the *unmapped* canonical sequence and averages the log
posterior of every vocabulary symbol per window:

| espeak-ng says | model actually hears (own → best, in nats) | mapped to |
|---|---|---|
| ㅏ /ɐ/ | −5.3 → /a/ −1.4 | `a` |
| ㅓ /ʌ/ | −5.1 → /ɔ/ −2.6 | `ɔ` |
| ㅡ /ɯ/ | −5.2 → /ə/ −3.4 | `ə` (least bad; the model has no good column for ㅡ) |
| ㄱ /q/, /ɡ/ | −7.1/−4.3 → /k/ −2.3/−0.9 | `k` |
| ㄹ final /ɫ/ | −7.9 → /l/ −2.9 | `l` |
| ㅐ /ɛ/ | −3.1 → /e/ −1.9 | `e` (ㅐ and ㅔ merge — as they do in modern Seoul speech) |
| ㄷ /d/ | −2.2 → /t/ −1.7 | `t` |
| ㅈ /dʑ/, /tɕ/ | −7.5/−4.7 → /dʒ/, /tʃ/ | `dʒ`, `tʃ` |
| ㅍ /ph/, ㅋ /kh/ | −7.9/−6.7 → /p/ −0.3, /k/ −0.4 | `p`, `k` |

The map lives in `LABEL_MAP` in
[scorer/src/gop/g2p.py](../scorer/src/gop/g2p.py) and applies everywhere the
G2P runs (lexicon build, calibration, CLI). Without it every native speaker
scores like a bad learner; with it, native Zeroth utterances land at a median
of 81.7 — the same range as native Spanish (79.3).

The price, also measured: **Korean's three-way stop contrast (plain / tense /
aspirated) collapses to the plain stop**, because the model has no column that
separates ㄱ from ㅋ from ㄲ in this language. A learner who under-aspirates ㅍ
is not caught. That is a model limitation, not a G2P one — no relabelling can
create a distinction the acoustic model does not encode.

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

The cost of the quantisation, on the four samples in `scorer/audio/` with the
calibration the app uses: up to 2.0 points on the overall score and **6.6 on a
single word** (Spanish "en", native voice). int8 is systematically kinder to
poor speech. This is over the 1.5-point limit `check_int8.py` enforces, so
**`r2` fails its own parity check.** The per-sample table, and a per-channel
quantisation that fixes Spanish but not accented English, are in the scorer
README under *Paridade fp32 × int8*.

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
3. `python tool/check_int8.py` — int8 against fp32 in both languages, with
   the shipped calibration; fails above 1.5 points on any word or the overall
   score.
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
| [Zeroth-Korean](https://www.openslr.org/40) test split, 457 utterances, 10 speakers — fetched as the [`Bingsu/zeroth-korean`](https://huggingface.co/datasets/Bingsu/zeroth-korean) parquet mirror, revision pinned, because the canonical 10 GB tarball is throttled to ~1 MB/s per connection | CC BY 4.0 | Korean native medians | as curves |
| [speechocean762](https://www.openslr.org/101) | CC BY 4.0 | agreement with human raters; the regression head | no |
| Common Voice | CC0 | the upstream fine-tuning | inside the weights |
| [espeak-ng](https://github.com/espeak-ng/espeak-ng), voices `en-us`, `es-419` and `ko` | GPL-3.0-or-later | grapheme-to-phoneme at build time | no, only its output, as the lexicon's phonemes |

**Before publishing, ask legal whether curves fitted on the OpenSLR 71 data
fall under CC BY-SA 4.0's ShareAlike clause.** They are statistics of
measurements, not audio or transcripts, but whether that makes them outside the
licence is not an engineering call.

## Known limitations

- **Korean's plain/tense/aspirated stop contrast is not scored.** The model has
  no column that separates ㄱ from ㅋ from ㄲ (measured: /kh/ scores −6.7 nats
  under its own label, /k/ −0.4 in the same windows), so all three map to the
  plain stop. Under-aspirating a ㅍ passes. See
  [Korean and the label map](#korean-and-the-label-map).
- **Korean ㅐ and ㅔ are scored as one vowel** (/e/): the model does not
  separate them either, and modern Seoul Korean merges them anyway.
- **Korean ㅡ is scored against /ə/**, the least bad column the model offers
  (−3.4 nats on native windows — far from the −1.4 of /a/ for ㅏ). Expect a
  looser curve there.
- **Korean calibration is 457 utterances from 10 speakers** (Zeroth test
  split): 22 of 23 phonemes reached their own curve, and the global curve
  does more work here than in English (which had 700 LibriSpeech utterances).
- **Korean is zero-shot**: the fine-tuning never saw the language. Native
  Zeroth utterances score a median of 81.7 (Spanish: 79.3), but agreement
  with human raters has never been measured — no public Korean corpus with
  expert pronunciation scores exists.
- **espeak-ng's Korean G2P covers only part of the phonology.** Liaison and
  nasalisation are partially applied (한국어를 comes out /h a n k u k ɔ ɾ ə l/,
  without the 한궁거를 nasalisation), so a learner who applies the rules
  *correctly* can be scored against a canonical sequence that does not.
  The curated prompts avoid the worst cases; `g2pk` is the alternative if
  this starts to matter.
- **The Korean confusion table is a starting point, not pedagogy.** The
  Brazilian-learner confusions in `calibrate.py` were written by an engineer
  from the literature, not reviewed by a Korean teacher.
- **No accent proxy for Korean in `check_int8.py`**: the pt-br espeak voice
  cannot read Hangul, so the pack's int8 parity is measured on the native
  synthetic sample only (2.1 overall, 3.2 on a word — inside the envelope the
  `r2` packs already show).
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
- **The int8 packs move scores more than the parity check allows**: up to 6.6
  points on a word, and on the samples the overall score of native Spanish
  crosses 80 and changes colour, and one diagnosed phoneme changes in accented
  English. Measured on four synthetic samples only.
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
