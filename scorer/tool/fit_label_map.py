"""Mede em fala real qual rotulo do vocabulario o modelo associa a cada
simbolo que o espeak-ng produz para o idioma.

O espeak e o modelo nasceram separados: para o mesmo som coreano, o espeak
diz /ɐ/ e o modelo pode ter aprendido aquilo como /a/. Antes de calibrar,
alinhamento forcado contra a transcricao canonica + media do log-posterior
por janela responde, por simbolo do espeak, quais rotulos do vocabulario o
modelo de fato ouve naquela janela. O resultado vira LABEL_MAP em g2p.py --
decisao medida, nao chutada.

A janela vem do alinhamento contra a sequencia NAO mapeada. Trocar /ɐ/ por
/a/ quase nao move a fronteira que o Viterbi encontra (mesmo raciocinio do
negative sampling do calibrate.py), entao a medida e valida.

    python tool/fit_label_map.py ko --manifest corpus/ko/manifest.tsv \
        --limit 200 --device mps
"""
from __future__ import annotations

import argparse
import sys
from collections import defaultdict
from pathlib import Path

import torch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from gop import acoustic, g2p, score as scoring  # noqa: E402


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("lang", choices=["ko"])  # so coreano tem o problema hoje
    ap.add_argument("--manifest", type=Path, required=True)
    ap.add_argument("--limit", type=int, default=200)
    ap.add_argument("--device", default="cpu")
    ap.add_argument("--min-count", type=int, default=20,
                    help="minimo de janelas para o simbolo entrar no relatorio")
    args = ap.parse_args()

    rows = []
    for line in args.manifest.read_text(encoding="utf-8").splitlines():
        audio, _, text = line.partition("\t")
        if text:
            rows.append((Path(audio), text))
        if len(rows) >= args.limit:
            break

    rec = acoustic.PhonemeRecognizer(args.lang, device=args.device)

    # soma dos log-posteriores e contagem por simbolo bruto do espeak
    summed: dict[str, torch.Tensor] = defaultdict(
        lambda: torch.zeros(len(rec.vocab))
    )
    counts: dict[str, int] = defaultdict(int)

    done = 0
    for audio_path, text in rows:
        try:
            audio = acoustic.load_audio(audio_path)
            phones, _, dropped = g2p.phonemize(text, args.lang, rec.vocab)
            if dropped or len(phones) < 4:
                continue
            em = rec.emissions(audio)
        except Exception as error:
            print(f"[pulou] {audio_path.name}: {error}", file=sys.stderr)
            continue
        targets = [i for p in phones for i in p.token_ids]
        if em.log_probs.shape[0] < len(targets):
            continue
        spans = acoustic.align(em, targets, rec.blank_id)
        measured = scoring.measure(phones, spans, em, rec.blank_id,
                                   rec.id_to_sym, rec.special_ids)
        if len(measured) != len(phones):
            continue
        for m in measured:
            window = em.log_probs[m.start_frame:m.end_frame].mean(dim=0)
            summed[m.symbol] += window
            counts[m.symbol] += 1
        done += 1
        if done % 25 == 0:
            print(f"  {done} falas", file=sys.stderr)

    print(f"\n{done} falas usadas de {len(rows)}\n")
    print(f"{'simb':>5} {'n':>5}  {'proprio':>8}  top candidatos (log-posterior medio)")
    for symbol in sorted(counts, key=lambda s: -counts[s]):
        n = counts[symbol]
        if n < args.min_count:
            continue
        mean = summed[symbol] / n
        own_id = rec.vocab.get(symbol)
        own = f"{mean[own_id]:.2f}" if own_id is not None else "-"
        top = torch.topk(mean, 5)
        cands = "  ".join(
            f"{rec.id_to_sym[i.item()]}:{v.item():.2f}"
            for v, i in zip(top.values, top.indices)
            if rec.id_to_sym[i.item()] not in ("<pad>", "<unk>", "<s>", "</s>", "|")
        )
        print(f"{symbol:>5} {n:>5}  {own:>8}  {cands}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
