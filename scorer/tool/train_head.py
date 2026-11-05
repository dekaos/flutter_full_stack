"""Treina a cabeca de regressao sobre as features de GOP.

A cabeca aprende o que a curva calibrada nao consegue expressar: que o peso de
um fonema depende de qual fonema e, de quanto ele durou, de quem ficou em
segundo lugar e do que veio antes e depois. A curva trata cada fonema
isoladamente e depois tira media; isto le a sequencia.

Segue a forma do GOPT (ICASSP 2022): projecao das features para 24 dimensoes,
somada a embedding do fonema canonico e a posicional, tres camadas de encoder
transformer, e cabecas de regressao em fonema, palavra e fala. Sao ~25 mil
parametros -- cabe em kilobytes, o que e o ponto: o sistema que ganha do nosso
por 0,2 de correlacao e menor que o lexico que ja embarcamos.

    python tool/train_head.py
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import torch
from torch import nn

FEATURES = Path(__file__).resolve().parents[1] / "features"
MAX_LEN = 128


def load(split: str):
    data = np.load(FEATURES / f"{split}.npz", allow_pickle=True)
    # Materializa uma vez. Indexar `data[...]` dentro do laco redescomprime o
    # array inteiro a cada iteracao -- 2500 vezes, ate o processo morrer.
    feats = data["feats"]
    phone_ids = data["phone_ids"]
    word_ids = data["word_ids"]
    phone_labels = data["phone_labels"]
    word_label_all = data["word_labels"]
    lengths = data["lengths"]
    offsets = np.concatenate([[0], np.cumsum(lengths)])
    utt_labels = data["utt_labels"]
    word_offsets = np.concatenate([[0], np.cumsum(data["word_counts"])])
    utterances = []
    for i, n in enumerate(lengths):
        if n > MAX_LEN:
            continue
        a, b = offsets[i], offsets[i + 1]
        utterances.append({
            "feats": feats[a:b],
            "phone_ids": phone_ids[a:b],
            "word_ids": word_ids[a:b],
            "phone_labels": phone_labels[a:b],
            "word_labels": word_label_all[word_offsets[i]:word_offsets[i + 1]],
            "utt_label": utt_labels[i],
        })
    return utterances


class Head(nn.Module):
    def __init__(self, n_features: int, n_phones: int, dim: int = 24,
                 dropout: float = 0.1):
        super().__init__()
        self.project = nn.Linear(n_features, dim)
        self.phone = nn.Embedding(n_phones, dim)
        self.position = nn.Embedding(MAX_LEN, dim)
        layer = nn.TransformerEncoderLayer(
            d_model=dim, nhead=2, dim_feedforward=dim * 2,
            batch_first=True, dropout=dropout,
        )
        self.encoder = nn.TransformerEncoder(layer, num_layers=3)
        self.phone_head = nn.Linear(dim, 1)
        self.utt_head = nn.Linear(dim, 1)

    def forward(self, feats, phone_ids, mask):
        positions = torch.arange(feats.shape[1], device=feats.device)
        x = self.project(feats) + self.phone(phone_ids) + self.position(positions)
        x = self.encoder(x, src_key_padding_mask=~mask)
        per_phone = self.phone_head(x).squeeze(-1)
        pooled = (x * mask.unsqueeze(-1)).sum(1) / mask.sum(1, keepdim=True)
        return per_phone, self.utt_head(pooled).squeeze(-1)


def batches(data, size, shuffle, device, stats):
    order = np.random.permutation(len(data)) if shuffle else np.arange(len(data))
    mean, std = stats
    for i in range(0, len(order), size):
        chunk = [data[j] for j in order[i:i + size]]
        width = max(len(u["feats"]) for u in chunk)
        feats = torch.zeros(len(chunk), width, chunk[0]["feats"].shape[1])
        ids = torch.zeros(len(chunk), width, dtype=torch.long)
        mask = torch.zeros(len(chunk), width, dtype=torch.bool)
        phone_y = torch.full((len(chunk), width), float("nan"))
        utt_y = torch.zeros(len(chunk))
        for k, u in enumerate(chunk):
            n = len(u["feats"])
            feats[k, :n] = torch.from_numpy((u["feats"] - mean) / std)
            ids[k, :n] = torch.from_numpy(u["phone_ids"])
            mask[k, :n] = True
            phone_y[k, :n] = torch.from_numpy(u["phone_labels"])
            utt_y[k] = float(u["utt_label"])
        yield (feats.to(device), ids.to(device), mask.to(device),
               phone_y.to(device), utt_y.to(device), chunk)


def pearson(a, b) -> float:
    return float(np.corrcoef(np.array(a), np.array(b))[0, 1])


def evaluate(model, data, device, stats):
    model.eval()
    utt_pred, utt_true, ph_pred, ph_true = [], [], [], []
    with torch.no_grad():
        for feats, ids, mask, phone_y, utt_y, _ in batches(
            data, 64, False, device, stats
        ):
            per_phone, utt = model(feats, ids, mask)
            utt_pred += utt.cpu().tolist()
            utt_true += utt_y.cpu().tolist()
            keep = mask & ~torch.isnan(phone_y)
            ph_pred += per_phone[keep].cpu().tolist()
            ph_true += phone_y[keep].cpu().tolist()
    return pearson(utt_pred, utt_true), pearson(ph_pred, ph_true)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--epochs", type=int, default=60)
    ap.add_argument("--batch", type=int, default=32)
    ap.add_argument("--lr", type=float, default=1e-3)
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--dropout", type=float, default=0.1)
    ap.add_argument("--dim", type=int, default=24)
    ap.add_argument("--weight-decay", type=float, default=0.0)
    ap.add_argument("--val-share", type=float, default=0.15)
    args = ap.parse_args()

    torch.manual_seed(args.seed)
    np.random.seed(args.seed)

    # Validacao separada do TREINO, nunca do teste. Escolher a epoca olhando o
    # teste e vazamento: o numero reportado deixa de ser o que o sistema faria
    # em dado novo e vira o melhor de N tentativas contra o proprio gabarito.
    full_train, test = load("train"), load("test")
    rng = np.random.default_rng(args.seed)
    order = rng.permutation(len(full_train))
    cut = int(len(order) * (1 - args.val_share))
    train = [full_train[i] for i in order[:cut]]
    val = [full_train[i] for i in order[cut:]]
    inventory = json.loads((FEATURES / "inventory.json").read_text())
    stacked = np.concatenate([u["feats"] for u in train])
    stats = (stacked.mean(0), stacked.std(0) + 1e-6)
    print(f"treino {len(train)}  validacao {len(val)}  teste {len(test)}  |  "
          f"{stacked.shape[1]} features, {len(inventory)} fonemas")

    device = "cpu"
    model = Head(stacked.shape[1], len(inventory), args.dim, args.dropout).to(device)
    params = sum(p.numel() for p in model.parameters())
    print(f"cabeca: {params/1000:.1f}k parametros (~{params*4/1024:.0f} KB em fp32)\n")

    optimiser = torch.optim.Adam(
        model.parameters(), lr=args.lr, weight_decay=args.weight_decay
    )
    best = (0.0, 0.0, -1)
    for epoch in range(1, args.epochs + 1):
        model.train()
        total = 0.0
        for feats, ids, mask, phone_y, utt_y, _ in batches(
            train, args.batch, True, device, stats
        ):
            per_phone, utt = model(feats, ids, mask)
            keep = mask & ~torch.isnan(phone_y)
            loss = nn.functional.mse_loss(utt, utt_y)
            if keep.any():
                loss = loss + nn.functional.mse_loss(per_phone[keep], phone_y[keep])
            optimiser.zero_grad()
            loss.backward()
            optimiser.step()
            total += float(loss)
        if epoch % 5 == 0 or epoch == args.epochs:
            utt_r, phone_r = evaluate(model, val, device, stats)
            flag = ""
            if utt_r > best[0]:
                best = (utt_r, phone_r, epoch)
                torch.save(model.state_dict(), FEATURES / "head.pt")
                np.savez(FEATURES / "stats.npz", mean=stats[0], std=stats[1])
                flag = "  *"
            print(f"  epoca {epoch:3d}  perda {total/len(train):.3f}"
                  f"   validacao: fala {utt_r:.3f}  fonema {phone_r:.3f}{flag}")

    print(f"\nmelhor na validacao: fala {best[0]:.3f} (epoca {best[2]})")
    model.load_state_dict(torch.load(FEATURES / "head.pt"))
    utt_r, phone_r = evaluate(model, test, device, stats)
    print(f"TESTE (uma vez, no ponto escolhido pela validacao):")
    print(f"  fala   Pearson {utt_r:.3f}   |  GOP + curva 0.546  ·  GOPT 0.742")
    print(f"  fonema Pearson {phone_r:.3f}   |  GOPT 0.612")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
