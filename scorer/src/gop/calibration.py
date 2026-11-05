"""Curva log-posterior -> 0..100, por fonema.

Uma curva unica para todos os fonemas estaria errada mesmo com dado perfeito:
o GOP nao e comparavel entre fonemas. O modelo e quase certo num /s/, que nao
tem vizinho proximo, e estruturalmente inseguro num /e/ reduzido, confusavel
com meia duzia de vogais. Curva unica pune schwa por ser schwa.

Os numeros ficam em `calibration/<lang>.json`, produzido a partir de gravacoes
-- o `center` de cada fonema deve ser a mediana do log-posterior de falantes
nativos dizendo aquele fonema. Enquanto nao existir o arquivo, tudo cai no
FALLBACK, que e chute educado e esta documentado como tal.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

# As ancoras usadas no ajuste. Viajam junto porque a escala inteira so
# significa algo em relacao a elas: "scale" e a separacao medida dividida pela
# distancia entre os dois alvos em logit. Sem isso, o app nao consegue derivar
# nem o corte de erro nem a separacao de volta.
TARGET_NATIVE = 0.90
TARGET_WRONG = 0.30

FALLBACK = {
    "center": -1.75,
    "scale": 0.80,
    "targetNative": TARGET_NATIVE,
    "targetWrong": TARGET_WRONG,
}

CALIBRATION_DIR = Path(__file__).resolve().parents[2] / "calibration"


def load(lang: str) -> dict:
    path = CALIBRATION_DIR / f"{lang}.json"
    if not path.exists():
        return {**FALLBACK, "phones": {}}
    data = json.loads(path.read_text(encoding="utf-8"))
    return {
        "center": data.get("center", FALLBACK["center"]),
        "scale": data.get("scale", FALLBACK["scale"]),
        "targetNative": data.get("targetNative", TARGET_NATIVE),
        "targetWrong": data.get("targetWrong", TARGET_WRONG),
        "phones": data.get("phones", {}),
    }


def to_score(cal: dict, symbol: str, lpp: float) -> float:
    tuned = cal["phones"].get(symbol, cal)
    center = tuned.get("center", cal["center"])
    scale = tuned.get("scale", cal["scale"])
    return 100.0 / (1.0 + math.exp(-(lpp - center) / scale))
