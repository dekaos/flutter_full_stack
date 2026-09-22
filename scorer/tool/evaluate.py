"""Compara o nosso score com a nota de avaliadores humanos.

O speechocean762 e o unico corpus publico com nota de pronuncia dada por
especialista: 5000 falas de 250 falantes nao nativos, cinco avaliadores
independentes, nota por fonema, palavra e frase. CC BY 4.0.

E a primeira medida de acuracia que este projeto tem. Tudo que medimos antes
-- separacao nativo/sotaque, paridade int8, curvas por fonema -- compara o
modelo com ele mesmo. Isto compara com um professor.

    python tool/evaluate.py --limit 600 --device mps

Ressalva que nao se deve esquecer ao ler o numero: os falantes tem mandarim
como lingua materna, e a nossa calibracao foi ajustada contra confusoes de
brasileiro. O que isto mede e se a regua acompanha julgamento humano, nao se
ela esta certa para o nosso aluno.
"""
from __future__ import annotations

import argparse
import json
import random
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from gop import acoustic, calibration as calib, g2p, score as scoring  # noqa: E402

ROOT = Path(__file__).resolve().parents[1] / "corpus" / "speechocean762"


def correlations(ours: list[float], theirs: list[float]) -> tuple[float, float]:
    a, b = np.array(ours), np.array(theirs)
    pearson = float(np.corrcoef(a, b)[0, 1])
    rank = lambda x: np.argsort(np.argsort(x)).astype(float)  # noqa: E731
    spearman = float(np.corrcoef(rank(a), rank(b))[0, 1])
    return pearson, spearman


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--split", default="test")
    ap.add_argument("--limit", type=int, default=600)
    ap.add_argument("--device", default="cpu")
    ap.add_argument("--seed", type=int, default=7)
    args = ap.parse_args()

    scores = json.loads((ROOT / "resource" / "scores.json").read_text())
    texts = {}
    for line in (ROOT / args.split / "text").read_text().splitlines():
        uid, _, text = line.partition("\t")
        texts[uid] = text
    wavs = {}
    for line in (ROOT / args.split / "wav.scp").read_text().splitlines():
        uid, _, path = line.partition("\t" if "\t" in line else " ")
        wavs[uid] = ROOT / path.strip().lstrip("./")

    rec = acoustic.PhonemeRecognizer("en", device=args.device)
    cal = calib.load("en")

    utt_ours, utt_human = [], []
    word_ours, word_human = [], []
    skipped = 0

    # Amostra aleatoria, nao as primeiras N. O arquivo vem agrupado por
    # falante, entao pegar do inicio mede um punhado de vozes: a primeira
    # rodada deu media humana 8,7 com desvio 0,8 quando o conjunto inteiro tem
    # 7,7 e 1,54. Correlacao sobre faixa comprimida nao significa nada.
    sample = list(texts)
    random.Random(args.seed).shuffle(sample)

    for n, uid in enumerate(sample[: args.limit], 1):
        label = scores.get(uid)
        if label is None or not wavs[uid].exists():
            skipped += 1
            continue
        try:
            audio = acoustic.load_audio(wavs[uid])
            phones, words, dropped = g2p.phonemize(texts[uid], "en", rec.vocab)
            if dropped or not phones:
                skipped += 1
                continue
            em = rec.emissions(audio)
            targets = [i for p in phones for i in p.token_ids]
            if em.log_probs.shape[0] < len(targets):
                skipped += 1
                continue
            spans = acoustic.align(em, targets, rec.blank_id)
            result = scoring.compute(
                texts[uid], "en", phones, words, spans, em,
                rec.blank_id, rec.id_to_sym, rec.special_ids, cal,
            )
        except Exception as error:
            print(f"[pulou] {uid}: {error}", file=sys.stderr)
            skipped += 1
            continue

        utt_ours.append(result.accuracy)
        utt_human.append(label["accuracy"])

        # palavra a palavra: a mesma sequencia, na mesma ordem
        if len(result.words) == len(label["words"]):
            for mine, theirs in zip(result.words, label["words"]):
                word_ours.append(mine.score)
                word_human.append(theirs["accuracy"])

        if n % 50 == 0:
            print(f"  {n}/{args.limit}", file=sys.stderr)

    print()
    print(f"falas avaliadas: {len(utt_ours)}  (puladas: {skipped})")
    if len(utt_ours) > 2:
        p, s = correlations(utt_ours, utt_human)
        print(f"NIVEL DE FALA   Pearson {p:.3f}   Spearman {s:.3f}")
        print(f"  nosso  media {np.mean(utt_ours):5.1f}  dp {np.std(utt_ours):5.1f}")
        print(f"  humano media {np.mean(utt_human):5.1f}  dp {np.std(utt_human):5.1f}  (escala 0-10)")
    if len(word_ours) > 2:
        p, s = correlations(word_ours, word_human)
        print(f"NIVEL DE PALAVRA ({len(word_ours)} palavras)"
              f"  Pearson {p:.3f}   Spearman {s:.3f}")
        # 90% das palavras levam nota 10 do humano, entao correlacao sobre elas
        # e quase ruido. A pergunta util e de deteccao: o nosso score ordena as
        # imperfeitas abaixo das perfeitas? AUC e a probabilidade de uma
        # imperfeita sorteada receber score menor que uma perfeita sorteada.
        ours = np.array(word_ours)
        bad = np.array(word_human) < 10
        if bad.any() and (~bad).any():
            order = np.argsort(ours)
            ranks = np.empty(len(ours))
            ranks[order] = np.arange(1, len(ours) + 1)
            n_bad, n_good = bad.sum(), (~bad).sum()
            auc = 1 - (ranks[bad].sum() - n_bad * (n_bad + 1) / 2) / (n_bad * n_good)
            print(f"  deteccao de palavra imperfeita: AUC {auc:.3f}"
                  f"  ({n_bad} imperfeitas de {len(ours)})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
