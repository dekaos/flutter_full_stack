"""Dois experimentos sobre o GOP cru cacheado, sem reprocessar audio.

1. **Agregacao.** Hoje a nota da fala e a media dos fonemas, o que dilui os
   poucos ruins. Avaliador humano pesa o erro saliente. Aqui se testa se
   percentil baixo, minimo ou media dos piores acompanha melhor o julgamento.

2. **Calibracao supervisionada.** As curvas atuais foram ajustadas contra erro
   *simulado* -- o log-posterior de um fonema que nao foi dito, em audio
   nativo. O speechocean762 traz erro real de aluno real, rotulado por
   especialista. Reajustar contra ele troca o negativo inventado pelo medido.

Os fonemas nossos (IPA do espeak) e os deles (ARPAbet) sao pareados por
posicao dentro da palavra, quando as duas sequencias tem o mesmo comprimento.
Nao e preciso traduzir os alfabetos: ambas descrevem a mesma palavra, na mesma
ordem. Palavras em que os comprimentos divergem sao descartadas, e a taxa de
aproveitamento e reportada.

    python tool/tune.py /tmp/so762_cache.json
"""
from __future__ import annotations

import argparse
import json
import math
import statistics
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from gop import calibration as calib  # noqa: E402

LOGIT_NATIVE = math.log(0.90 / 0.10)
LOGIT_WRONG = math.log(0.30 / 0.70)
MIN_SAMPLES = 40
SCALE_RANGE = (0.10, 8.00)


def pearson(a: list[float], b: list[float]) -> float:
    return float(np.corrcoef(np.array(a), np.array(b))[0, 1])


def auc(scores: list[float], bad: list[bool]) -> float:
    ours, flags = np.array(scores), np.array(bad)
    if not flags.any() or flags.all():
        return float("nan")
    order = np.argsort(ours)
    ranks = np.empty(len(ours))
    ranks[order] = np.arange(1, len(ours) + 1)
    n_bad, n_good = flags.sum(), (~flags).sum()
    return float(
        1 - (ranks[flags].sum() - n_bad * (n_bad + 1) / 2) / (n_bad * n_good)
    )


# --- agregadores -----------------------------------------------------------

def _mean(xs): return sum(xs) / len(xs)
def _low(p): return lambda xs: float(np.percentile(xs, p))
def _worst_share(share):
    def agg(xs):
        k = max(1, round(len(xs) * share))
        return _mean(sorted(xs)[:k])
    return agg
def _harmonic(xs):
    return len(xs) / sum(1 / max(x, 1.0) for x in xs)
def _penalty(threshold):
    # so o que fica abaixo do limiar custa, e custa proporcionalmente: e o
    # comportamento de quem ouve, que ignora o que saiu bem e reage ao que
    # saiu errado
    return lambda xs: 100 - _mean([max(0.0, threshold - x) for x in xs])


AGGREGATORS = {
    "media (atual)": _mean,
    "percentil 10": _low(10),
    "percentil 25": _low(25),
    "minimo": min,
    "media dos 20% piores": _worst_share(0.20),
    "media dos 40% piores": _worst_share(0.40),
    "harmonica": _harmonic,
    "penalidade abaixo de 60": _penalty(60),
    "penalidade abaixo de 80": _penalty(80),
}


def score_of(lpp: float, cal: dict, symbol: str) -> float:
    return calib.to_score(cal, symbol, lpp)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("cache", type=Path)
    ap.add_argument("--out", type=Path,
                    help="grava a calibracao supervisionada aqui")
    ap.add_argument("--correct-at", type=float, default=2.0)
    ap.add_argument("--wrong-at", type=float, default=1.0)
    args = ap.parse_args()

    data = json.loads(args.cache.read_text())
    cal = calib.load("en")
    print(f"{len(data)} falas no cache\n")

    # --- 1. agregacao ------------------------------------------------------
    print("AGREGACAO (curva atual, Pearson no nivel de fala)")
    human = [u["humanUtt"] for u in data]
    per_utt = [[score_of(p["lpp"], cal, p["s"]) for p in u["phones"]] for u in data]
    results = []
    for name, agg in AGGREGATORS.items():
        ours = [agg(scores) for scores in per_utt]
        results.append((pearson(ours, human), name))
    for r, name in sorted(results, reverse=True):
        mark = "  <-- atual" if name.startswith("media (") else ""
        print(f"  {r:.3f}  {name}{mark}")

    # --- 2. calibracao supervisionada -------------------------------------
    correct: dict[str, list[float]] = {}
    wrong: dict[str, list[float]] = {}
    paired = mismatched = 0
    for u in data:
        by_word: dict[int, list[dict]] = {}
        for p in u["phones"]:
            by_word.setdefault(p["w"], []).append(p)
        theirs: dict[int, list[dict]] = {}
        for h in u["humanPhones"]:
            theirs.setdefault(h["w"], []).append(h)
        for w, mine in by_word.items():
            other = theirs.get(w, [])
            if len(other) != len(mine):
                mismatched += 1
                continue
            paired += 1
            for m, h in zip(mine, other):
                # A nota e a media de cinco avaliadores, entao vem
                # fracionada: 1.8 quer dizer que a maioria achou certo. Tratar
                # tudo abaixo de 2 como erro joga quase-certo na distribuicao
                # de erro e borra as duas. A faixa do meio e descartada.
                if h["a"] >= args.correct_at:
                    correct.setdefault(m["s"], []).append(m["lpp"])
                elif h["a"] <= args.wrong_at:
                    wrong.setdefault(m["s"], []).append(m["lpp"])

    total = paired + mismatched
    print(f"\nCALIBRACAO SUPERVISIONADA")
    print(f"  palavras pareadas: {paired}/{total} ({100*paired/total:.0f}%)")

    phones_out: dict[str, dict] = {}
    for symbol in sorted(set(correct) & set(wrong)):
        good, bad = correct[symbol], wrong[symbol]
        if len(good) < MIN_SAMPLES or len(bad) < MIN_SAMPLES:
            continue
        separation = statistics.median(good) - statistics.median(bad)
        if separation <= 0:
            continue
        scale = separation / (LOGIT_NATIVE - LOGIT_WRONG)
        if not SCALE_RANGE[0] <= scale <= SCALE_RANGE[1]:
            continue
        phones_out[symbol] = {
            "center": round(statistics.median(good) - LOGIT_NATIVE * scale, 4),
            "scale": round(scale, 4),
        }
    print(f"  fonemas com curva humana: {len(phones_out)}"
          f" (de {len(set(correct) & set(wrong))} candidatos)")

    if not phones_out:
        print("  amostra insuficiente")
        return 1

    # A base global tem que ser a MEDIDA, nao o fallback chutado: os fonemas
    # sem curva humana caem nela, e usar o chute aqui compararia duas coisas
    # diferentes e culparia a curva humana pela diferenca.
    tuned = {k: v for k, v in cal.items() if k != "phones"}
    tuned["phones"] = phones_out
    best_agg = max(results)[1]
    for label, active, agg in (
        ("curva simulada + media", cal, _mean),
        ("curva humana  + media", tuned, _mean),
        (f"curva humana  + {best_agg}", tuned, AGGREGATORS[best_agg]),
    ):
        ours = [
            agg([score_of(p["lpp"], active, p["s"]) for p in u["phones"]])
            for u in data
        ]
        word_scores, word_bad = [], []
        for u in data:
            groups: dict[int, list[float]] = {}
            for p in u["phones"]:
                groups.setdefault(p["w"], []).append(
                    score_of(p["lpp"], active, p["s"])
                )
            if len(groups) != len(u["humanWords"]):
                continue
            for w, human_score in enumerate(u["humanWords"]):
                if w in groups:
                    word_scores.append(_mean(groups[w]))
                    word_bad.append(human_score < 10)
        print(f"\n  {label}")
        print(f"    fala   Pearson {pearson(ours, human):.3f}")
        print(f"    palavra   AUC  {auc(word_scores, word_bad):.3f}")

    if args.out:
        args.out.write_text(
            json.dumps(tuned, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        print(f"\nescrito: {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
