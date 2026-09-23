"""CLI: gop score --lang en --text "..." --audio a.wav"""
from __future__ import annotations

import argparse
import json
import sys

from . import acoustic, calibration as calib, g2p, score as scoring


def color(s: float) -> str:
    if s >= 80: return "\033[32m"   # verde
    if s >= 60: return "\033[33m"   # amarelo
    return "\033[31m"               # vermelho


def render(res: scoring.Result) -> None:
    r = "\033[0m"
    print(f"\n  texto: {res.text}")
    print(f"  {color(res.overall)}GERAL {res.overall}{r}"
          f"   pronuncia {res.accuracy}   fluencia {res.fluency}"
          f"   ritmo {res.speech_rate} fon/s   pausas {res.pauses}\n")
    for w in res.words:
        bad = [p for p in w.phones if p.score < 60]
        detail = "  ".join(
            f"{p.symbol}->{p.substituted_by}({p.score:.0f})" for p in bad
        )
        print(f"  {color(w.score)}{w.score:5.1f}{r}  {w.word:<16} {detail}")
    print()


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="gop")
    ap.add_argument("--lang", choices=["en", "es"], required=True)
    ap.add_argument("--text", required=True, help="texto de referencia que o aluno deve ler")
    ap.add_argument("--audio", required=True)
    ap.add_argument("--model", default=None)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)

    rec = acoustic.PhonemeRecognizer(args.lang, args.model)
    phones, words, dropped = g2p.phonemize(args.text, args.lang, rec.vocab)
    if dropped:
        print(f"[aviso] fonemas fora do vocabulario, ignorados: {sorted(set(dropped))}",
              file=sys.stderr)
    if not phones:
        print("[erro] nenhum fonema mapeado", file=sys.stderr)
        return 1

    audio = acoustic.load_audio(args.audio)
    em = rec.emissions(audio)
    target_ids = [i for p in phones for i in p.token_ids]
    spans = acoustic.align(em, target_ids, rec.blank_id)
    if len(spans) != len(target_ids):
        print(f"[aviso] {len(spans)} spans para {len(target_ids)} alvos", file=sys.stderr)

    res = scoring.compute(
        args.text, args.lang, phones, words, spans, em,
        rec.blank_id, rec.id_to_sym, rec.special_ids,
        calib.load(args.lang),
    )
    if args.json:
        print(json.dumps(res.to_dict(), ensure_ascii=False, indent=2))
    else:
        render(res)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
