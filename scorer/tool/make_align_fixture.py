"""Gera a fixture que trava o alinhador Dart no resultado do torchaudio.

Emissoes sinteticas pequenas e deterministicas: o teste compara span a span,
entao qualquer divergencia no Viterbi aparece como falha, nao como score ruim.
"""
import json, pathlib, torch
import torchaudio.functional as AF

torch.manual_seed(7)
cases = []
for frames, vocab, targets in [
    (12, 6, [1, 2, 3]),
    (20, 8, [2, 2, 5, 1]),      # alvo repetido: exige o blank entre os dois
    (30, 5, [1, 3, 1, 4, 2]),
]:
    logits = torch.randn(frames, vocab)
    # favorece os alvos em ordem, senao o caminho otimo fica degenerado
    for i, t in enumerate(targets):
        lo = i * frames // len(targets)
        logits[lo:lo + frames // len(targets), t] += 3.0
    lp = torch.log_softmax(logits, dim=-1)
    spans = AF.merge_tokens(
        *[x[0] for x in AF.forced_align(lp.unsqueeze(0),
                                        torch.tensor([targets], dtype=torch.int32),
                                        blank=0)],
        blank=0,
    )
    cases.append({
        "frames": frames,
        "vocabSize": vocab,
        "targets": targets,
        "logProbs": [round(v, 6) for v in lp.flatten().tolist()],
        "expected": [{"tokenId": int(s.token), "start": int(s.start), "end": int(s.end)}
                     for s in spans],
    })

out = pathlib.Path("../flutter_full_stack_flutter/test/fixtures/ctc_alignment.json")
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps({"cases": cases}), encoding="utf-8")
print("casos:", len(cases), "->", out)
for c in cases:
    print(" ", c["targets"], "=>", [(s["tokenId"], s["start"], s["end"]) for s in c["expected"]])
