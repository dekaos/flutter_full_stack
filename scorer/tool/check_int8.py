"""Compara o score do modelo int8 (o que vai para o device) com o fp32.

Quantizacao que passa no export mas move o score nao serve: o numero mostrado
ao aluno tem que ser o mesmo dos dois lados.

    python tool/check_int8.py          # en e es
    python tool/check_int8.py es

Sai com erro se alguma amostra mover mais que MAX_DRIFT pontos, em qualquer
palavra ou na nota geral.
"""
import json
import pathlib
import sys

import numpy as np
import onnxruntime as ort
import torch

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "src"))
from gop import acoustic, calibration as calib, g2p, score as scoring  # noqa: E402

# Texto de cada amostra em audio/. Sao sinteses do espeak-ng a 150 palavras
# por minuto: a voz do idioma como pronuncia nativa, a pt-br lendo o mesmo
# texto como proxy de sotaque (comando no README).
SAMPLES = {
    "en": ("The weather is beautiful today", ("en_ok", "en_br")),
    "es": ("El desayuno está en la mesa", ("es_ok", "es_br")),
}

# Em pontos de 0-100, na nota geral e em cada palavra. Com o fallback chutado,
# quantizar tambem as Conv movia a nota nativa em 2,6 pontos e so os MatMul em
# 0,7, e o limite foi posto entre os dois. Com a calibracao real o `r2` passa
# disso (ate 6,6 numa palavra): o limite fica, e a ferramenta reprova o modelo
# atual, que e a verdade. Ver "Paridade fp32 x int8" no README.
MAX_DRIFT = 1.5


def emissions_from_onnx(path: str, audio: np.ndarray) -> acoustic.Emissions:
    sess = ort.InferenceSession(path, providers=["CPUExecutionProvider"])
    x = (audio - audio.mean()) / np.sqrt(audio.var() + 1e-7)
    logits = sess.run(None, {"input_values": x[None, :].astype(np.float32)})[0][0]
    lp = torch.log_softmax(torch.from_numpy(logits).float(), dim=-1)
    secs = len(audio) / acoustic.SAMPLE_RATE
    return acoustic.Emissions(lp, secs / lp.shape[0], secs)


def check(lang: str) -> float:
    """Imprime fp32 contra int8 de cada amostra; devolve o maior desvio."""
    text, names = SAMPLES[lang]
    int8_path = pathlib.Path(f"build/phoneme_{lang}_{acoustic.MODEL_REVISION}.int8.onnx")
    if not int8_path.exists():
        raise SystemExit(f"{int8_path} nao existe: rode tool/export_onnx.py {lang}")

    model_id = acoustic.MODELS[lang]
    with open(acoustic.vocab_file(model_id), encoding="utf-8") as f:
        vocab = json.load(f)
    phones, words, _ = g2p.phonemize(text, lang, vocab)
    targets = [i for p in phones for i in p.token_ids]
    id_to_sym = {i: s for s, i in vocab.items()}
    special = {vocab[t] for t in ("<pad>", "<unk>", "<s>", "</s>", "|") if t in vocab}
    # A calibracao que o app usa, nao o fallback: o que importa e se o numero
    # que o aluno ve se move, e ele sai destas curvas.
    cal = calib.load(lang)

    rec = acoustic.PhonemeRecognizer(lang)
    worst = 0.0
    print(f"{lang}: {model_id} -> {int8_path.name}")
    for name in names:
        audio = acoustic.load_audio(f"audio/{name}.wav")
        results = {}
        for label, em in (
            ("fp32", rec.emissions(audio)),
            ("int8", emissions_from_onnx(str(int8_path), audio)),
        ):
            spans = acoustic.align(em, targets, rec.blank_id)
            results[label] = scoring.compute(text, lang, phones, words, spans, em,
                                             rec.blank_id, id_to_sym, special, cal)
        fp32, int8 = results["fp32"], results["int8"]
        drifts = [abs(a.score - b.score) for a, b in zip(fp32.words, int8.words)]
        drifts.append(abs(fp32.overall - int8.overall))
        worst = max(worst, *drifts)
        print(f"  {name:6s} fp32 {fp32.overall:5.1f}  int8 {int8.overall:5.1f}  "
              f"desvio geral {abs(fp32.overall - int8.overall):4.1f}  "
              f"maior numa palavra {max(drifts[:-1]):4.1f}")
    return worst


def main() -> int:
    langs = sys.argv[1:] or list(SAMPLES)
    worst = max(check(lang) for lang in langs)
    if worst > MAX_DRIFT:
        print(f"FALHOU: o int8 move a nota em {worst:.1f} pontos (limite {MAX_DRIFT})")
        return 1
    print(f"ok: maior desvio {worst:.1f} pontos (limite {MAX_DRIFT})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
