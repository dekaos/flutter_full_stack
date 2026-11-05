"""Extrai as features de GOP que a cabeca de regressao consome.

A cabeca nao ve audio: ve, por fonema, o quanto o modelo acustico acreditou no
fonema canonico e o quanto acreditou em cada alternativa. E a mesma entrada do
GOPT -- log-posterior, razao contra as demais, duracao e identidade do fonema
-- so que vinda de um CTC em vez de um alinhador Kaldi.

Roda uma vez por split e guarda um .npz. Depois disso, treinar e reavaliar
custa segundos, e nenhum experimento precisa tocar em audio de novo.

    python tool/dump_features.py train --device mps
    python tool/dump_features.py test  --device mps
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from gop import acoustic, g2p, score as scoring  # noqa: E402

ROOT = Path(__file__).resolve().parents[1] / "corpus" / "speechocean762"
OUT = Path(__file__).resolve().parents[1] / "features"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("split", choices=["train", "test"])
    ap.add_argument("--device", default="cpu")
    ap.add_argument("--limit", type=int, default=0)
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

    # Inventario fixo: os simbolos que aparecem como canonicos no corpus. A
    # razao de log-posterior e medida contra ele, e a ordem precisa ser a
    # mesma em treino e em inferencia, entao vai gravada junto.
    inventory_path = OUT / "inventory.json"
    if inventory_path.exists():
        inventory = json.loads(inventory_path.read_text())
    else:
        # Sobre os DOIS splits: um fonema que so aparece no treino faria a
        # fala de teste ser descartada, e vice-versa.
        seen: set[str] = set()
        for split in ("train", "test"):
            for line in (ROOT / split / "text").read_text().splitlines():
                _, _, text = line.partition("\t")
                phones, _, _ = g2p.phonemize(text, "en", rec.vocab)
                seen.update(p.symbol for p in phones)
        inventory = sorted(seen)
        OUT.mkdir(exist_ok=True)
        inventory_path.write_text(json.dumps(inventory), encoding="utf-8")
    index = {s: i for i, s in enumerate(inventory)}
    print(f"inventario: {len(inventory)} fonemas", file=sys.stderr)

    uids = list(texts)
    if args.limit:
        uids = uids[: args.limit]

    feats, phone_ids, word_ids, utt_ids = [], [], [], []
    phone_labels, word_labels, utt_labels = [], [], []
    lengths, kept = [], []

    for n, uid in enumerate(uids, 1):
        label = scores.get(uid)
        if label is None or not wavs[uid].exists():
            continue
        try:
            audio = acoustic.load_audio(wavs[uid])
            phones, words, dropped = g2p.phonemize(texts[uid], "en", rec.vocab)
            if dropped or not phones or any(p.symbol not in index for p in phones):
                continue
            em = rec.emissions(audio)
            targets = [i for p in phones for i in p.token_ids]
            if em.log_probs.shape[0] < len(targets):
                continue
            spans = acoustic.align(em, targets, rec.blank_id)
            measured = scoring.measure(
                phones, spans, em, rec.blank_id, rec.id_to_sym, rec.special_ids
            )
            if len(measured) != len(phones):
                continue
        except Exception as error:
            print(f"[pulou] {uid}: {error}", file=sys.stderr)
            continue

        # rotulo por fonema, pareado por posicao dentro da palavra
        theirs: dict[int, list[float]] = {}
        for w, word in enumerate(label["words"]):
            theirs[w] = list(word["phones-accuracy"])
        mine_by_word: dict[int, list[int]] = {}
        for i, p in enumerate(phones):
            mine_by_word.setdefault(p.word_idx, []).append(i)
        phone_target = np.full(len(phones), np.nan, dtype=np.float32)
        for w, idxs in mine_by_word.items():
            other = theirs.get(w, [])
            if len(other) == len(idxs):
                for i, a in zip(idxs, other):
                    phone_target[i] = a

        log_probs = em.log_probs.numpy()
        rows = np.zeros((len(phones), 3 + len(inventory)), dtype=np.float32)
        for i, (m, p) in enumerate(zip(measured, phones)):
            window = log_probs[m.start_frame:m.end_frame].mean(axis=0)
            rows[i, 0] = m.lpp
            rows[i, 1] = m.lpp - m.competitor_lpp
            rows[i, 2] = (m.end_frame - m.start_frame) * em.frame_sec
            for symbol, j in index.items():
                ids = [rec.vocab[symbol]] if symbol in rec.vocab else []
                if ids:
                    rows[i, 3 + j] = window[ids[0]] - m.lpp

        feats.append(rows)
        phone_ids.append(np.array([index[p.symbol] for p in phones], dtype=np.int64))
        word_ids.append(np.array([p.word_idx for p in phones], dtype=np.int64))
        phone_labels.append(phone_target)
        word_labels.append(
            np.array([w["accuracy"] for w in label["words"]], dtype=np.float32)
        )
        utt_labels.append(np.float32(label["accuracy"]))
        utt_ids.append(uid)
        lengths.append(len(phones))
        kept.append(uid)

        if n % 100 == 0:
            print(f"  {n}/{len(uids)}", file=sys.stderr)

    OUT.mkdir(exist_ok=True)
    out = OUT / f"{args.split}.npz"
    np.savez_compressed(
        out,
        feats=np.concatenate(feats),
        phone_ids=np.concatenate(phone_ids),
        word_ids=np.concatenate(word_ids),
        phone_labels=np.concatenate(phone_labels),
        word_labels=np.concatenate([w for w in word_labels]),
        word_counts=np.array([len(w) for w in word_labels], dtype=np.int64),
        utt_labels=np.array(utt_labels, dtype=np.float32),
        lengths=np.array(lengths, dtype=np.int64),
        uids=np.array(kept),
    )
    print(f"\n{len(kept)} falas, {sum(lengths)} fonemas -> {out}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
