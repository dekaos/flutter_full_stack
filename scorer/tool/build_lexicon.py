"""Gera o lexico que o app Flutter embarca.

O texto dos exercicios e curado, entao o G2P roda aqui no build e nunca no
device -- e por isso que o app nao precisa de espeak-ng.

    python tool/build_lexicon.py exercises/en.json > ../flutter_full_stack_flutter/assets/lexicons/en.json
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from gop import calibration as calib  # noqa: E402
from gop.acoustic import MODEL_REVISION, MODELS, vocab_file  # noqa: E402
from gop.g2p import phonemize  # noqa: E402


def load_vocab(lang: str) -> dict[str, int]:
    with open(vocab_file(MODELS[lang]), encoding="utf-8") as f:
        return json.load(f)


def build(exercises: list[dict], lang: str) -> dict:
    vocab = load_vocab(lang)
    out = []
    for ex in exercises:
        phones, words, dropped = phonemize(ex["text"], lang, vocab)
        if dropped:
            print(f"[aviso] {ex['id']}: fonemas ignorados {sorted(set(dropped))}",
                  file=sys.stderr)
        ranges = []
        for idx in range(len(words)):
            hits = [i for i, p in enumerate(phones) if p.word_idx == idx]
            ranges.append({"w": words[idx], "p": [hits[0], hits[-1] + 1] if hits else [0, 0]})
        out.append({
            "id": ex["id"],
            # "word" ou "phrase": a UI separa os dois, e fluencia nao faz
            # sentido em item de uma palavra so.
            "kind": ex.get("kind", "phrase"),
            "text": ex["text"],
            "words": ranges,
            "phones": [{"s": p.symbol, "t": p.token_ids} for p in phones],
        })
    # Tabela id -> simbolo: e ela que deixa o app dizer "ouvi /t/ no lugar
    # de /d/" em vez de so mostrar um numero.
    symbols = [""] * len(vocab)
    for sym, i in vocab.items():
        symbols[i] = sym

    return {
        "lang": lang,
        "model": f"phoneme_{lang}_{MODEL_REVISION}.int8.onnx",
        "vocab": symbols,
        "blankId": vocab.get("<pad>", 0),
        # Medido, nao decidido: vem de calibration/<lang>.json.
        "calibration": calib.load(lang),
        "exercises": out,
    }


def main() -> int:
    src = Path(sys.argv[1])
    data = json.loads(src.read_text(encoding="utf-8"))
    print(json.dumps(build(data["exercises"], data["lang"]), ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
