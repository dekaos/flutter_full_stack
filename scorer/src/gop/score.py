"""GOP (Goodness of Pronunciation) a partir do alinhamento CTC."""
from __future__ import annotations

from dataclasses import dataclass, field, asdict

import torch

from . import calibration as calib
from .acoustic import Emissions, Span
from .g2p import Phone

PAUSE_SEC = 0.30  # gap entre palavras que conta como pausa


@dataclass
class PhoneScore:
    symbol: str
    start: float
    end: float
    lpp: float               # log-posterior medio do fonema canonico
    lpr: float               # margem para o melhor concorrente
    substituted_by: str | None  # o que o modelo "ouviu" no lugar
    score: float


@dataclass
class WordScore:
    word: str
    start: float
    end: float
    score: float
    weakest: str | None
    phones: list[PhoneScore] = field(default_factory=list)


@dataclass
class Result:
    text: str
    lang: str
    overall: float
    accuracy: float
    fluency: float
    speech_rate: float       # fonemas por segundo
    pauses: int
    words: list[WordScore]

    def to_dict(self) -> dict:
        return asdict(self)


def _competitor(mean_lp: torch.Tensor, exclude: set[int], id_to_sym: dict[int, str]):
    masked = mean_lp.clone()
    for i in exclude:
        masked[i] = -float("inf")
    best = int(torch.argmax(masked))
    return id_to_sym.get(best, "?"), float(masked[best])


@dataclass
class PhoneMeasurement:
    """O GOP cru de um fonema, antes de virar nota."""
    symbol: str
    lpp: float               # log-posterior medio do fonema canonico
    competitor: str          # fonema que o modelo ouviu com mais forca
    competitor_lpp: float
    start_frame: int
    end_frame: int


def measure(
    phones: list[Phone],
    spans: list[Span],
    emissions: Emissions,
    blank_id: int,
    id_to_sym: dict[int, str],
    special_ids: set[int],
) -> list[PhoneMeasurement]:
    """Extrai o GOP por fonema a partir de um alinhamento.

    Separado de `compute` porque a calibracao precisa exatamente disto e nada
    mais: se ela medisse o GOP de um jeito e o score de outro, calibrar-se-ia
    uma grandeza e pontuaria-se outra.
    """
    lp = emissions.log_probs
    out: list[PhoneMeasurement] = []
    cursor = 0
    for ph in phones:
        my = spans[cursor:cursor + len(ph.token_ids)]
        cursor += len(ph.token_ids)
        if not my:
            continue
        start_f, end_f = my[0].start, my[-1].end
        if end_f <= start_f:
            continue
        # cada token do fonema e avaliado no SEU proprio span (um ditongo
        # decomposto em 2 tokens tem 2 janelas distintas), depois faz-se a media
        lpps, means = [], []
        for span, tid in zip(my, ph.token_ids):
            frames = lp[span.start:max(span.end, span.start + 1)]
            m = frames.mean(dim=0)
            means.append(m)
            lpps.append(float(m[tid]))
        mean_lp = torch.stack(means).mean(dim=0)
        sym, comp_lpp = _competitor(
            mean_lp, special_ids | {blank_id} | set(ph.token_ids), id_to_sym
        )
        out.append(PhoneMeasurement(
            symbol=ph.symbol, lpp=sum(lpps) / len(lpps),
            competitor=sym, competitor_lpp=comp_lpp,
            start_frame=start_f, end_frame=end_f,
        ))
    return out


def compute(
    text: str,
    lang: str,
    phones: list[Phone],
    words: list[str],
    spans: list[Span],
    emissions: Emissions,
    blank_id: int,
    id_to_sym: dict[int, str],
    special_ids: set[int],
    cal: dict | None = None,
) -> Result:
    cal = cal or {**calib.FALLBACK, "phones": {}}
    fs = emissions.frame_sec

    phone_scores: list[PhoneScore] = []
    measured = measure(phones, spans, emissions, blank_id, id_to_sym, special_ids)
    for m in measured:
        score = calib.to_score(cal, m.symbol, m.lpp)
        phone_scores.append(PhoneScore(
            symbol=m.symbol, start=m.start_frame * fs, end=m.end_frame * fs,
            lpp=round(m.lpp, 3), lpr=round(m.lpp - m.competitor_lpp, 3),
            substituted_by=m.competitor if score < 60 else None,
            score=round(score, 1),
        ))

    # agrega por palavra
    word_scores: list[WordScore] = []
    for idx, word in enumerate(words):
        group = [(p, ps) for p, ps in zip(phones, phone_scores) if p.word_idx == idx]
        if not group:
            continue
        ss = [ps for _, ps in group]
        weakest = min(ss, key=lambda s: s.score)
        word_scores.append(WordScore(
            word=word, start=ss[0].start, end=ss[-1].end,
            score=round(sum(s.score for s in ss) / len(ss), 1),
            weakest=weakest.symbol if weakest.score < 60 else None,
            phones=ss,
        ))

    accuracy = (sum(w.score * len(w.phones) for w in word_scores)
                / max(1, sum(len(w.phones) for w in word_scores)))

    # fluencia: ritmo + pausas indevidas entre palavras
    pauses = sum(1 for a, b in zip(word_scores, word_scores[1:]) if b.start - a.end > PAUSE_SEC)
    speech_sec = max(1e-6, word_scores[-1].end - word_scores[0].start) if word_scores else 1e-6
    n_phones = sum(len(w.phones) for w in word_scores)
    rate = n_phones / speech_sec
    # banda alvo ~9-15 fonemas/s (fala corrente); fora dela penaliza suave
    rate_pen = max(0.0, 9.0 - rate) * 6 + max(0.0, rate - 15.0) * 4
    fluency = max(0.0, 100.0 - rate_pen - pauses * 8)

    return Result(
        text=text, lang=lang,
        # A nota E a pronuncia. A fluencia acompanha mas fica de fora: ela so
        # perde ponto por pausa ou ritmo fora da faixa, entao fica perto de
        # 100 em quase toda tentativa e, misturada, levantava leitura ruim.
        # Mantido igual ao app (gop_scorer.dart), senao a referencia deixa de
        # ser referencia.
        overall=round(accuracy, 1),
        accuracy=round(accuracy, 1), fluency=round(fluency, 1),
        speech_rate=round(rate, 1), pauses=pauses, words=word_scores,
    )
