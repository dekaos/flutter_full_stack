"""Compara o score do modelo int8 (o que vai para o device) com o fp32.

Quantizacao que passa no export mas move o score nao serve: o numero mostrado
ao aluno tem que ser o mesmo dos dois lados.
"""
import json
import pathlib
import sys

import numpy as np
import onnxruntime as ort
import torch

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "src"))
from gop import acoustic, g2p, score as scoring  # noqa: E402

LANG, TEXT = "en", "The weather is beautiful today"


def emissions_from_onnx(path: str, audio: np.ndarray) -> acoustic.Emissions:
    sess = ort.InferenceSession(path, providers=["CPUExecutionProvider"])
    x = (audio - audio.mean()) / np.sqrt(audio.var() + 1e-7)
    logits = sess.run(None, {"input_values": x[None, :].astype(np.float32)})[0][0]
    lp = torch.log_softmax(torch.from_numpy(logits).float(), dim=-1)
    secs = len(audio) / acoustic.SAMPLE_RATE
    return acoustic.Emissions(lp, secs / lp.shape[0], secs)


def main() -> int:
    with open(acoustic.vocab_file(acoustic.MODELS[LANG]), encoding="utf-8") as f:
        vocab = json.load(f)
    phones, words, _ = g2p.phonemize(TEXT, LANG, vocab)
    targets = [i for p in phones for i in p.token_ids]
    id_to_sym = {i: s for s, i in vocab.items()}
    special = {vocab[t] for t in ("<pad>", "<unk>", "<s>", "</s>", "|") if t in vocab}

    rec = acoustic.PhonemeRecognizer(LANG)
    for name in ("en_ok", "en_br"):
        audio = acoustic.load_audio(f"audio/{name}.wav")
        row = [name]
        for label, em in (
            ("fp32", rec.emissions(audio)),
            ("int8", emissions_from_onnx(f"build/phoneme_{LANG}_r2.int8.onnx", audio)),
        ):
            spans = acoustic.align(em, targets, rec.blank_id)
            res = scoring.compute(TEXT, LANG, phones, words, spans, em,
                                  rec.blank_id, id_to_sym, special)
            row.append(f"{label} geral={res.overall:5.1f} pron={res.accuracy:5.1f}")
        print("  ".join(row))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
