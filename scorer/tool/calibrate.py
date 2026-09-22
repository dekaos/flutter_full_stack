"""Ajusta a curva de score por fonema sem gravar ninguem.

Duas distribuicoes sao necessarias por fonema, e nenhuma exige coletar aluno:

- **certo**: o GOP do fonema em audio nativo alinhado contra a transcricao
  verdadeira. Sai de corpus publico.
- **errado**: o GOP de um fonema que *nao foi dito*, medido na janela em que
  outro fonema foi dito. Nao e preciso gravar ninguem errando de proposito.

A janela vem do alinhamento CORRETO, e isso e essencial. A primeira versao
alinhava o audio contra uma transcricao corrompida, e nao funcionou: o Viterbi
reposiciona as fronteiras livremente e encaixa o fonema trocado onde ele for
plausivel, entao o "erro" saia com GOP alto e nao havia separacao nenhuma.

Fixando a janela do fonema canonico e perguntando "qual o log-posterior de /q/
neste trecho, onde na verdade se disse /p/?", reproduz-se exatamente o que o
app ve quando o aluno erra: a janela e do fonema esperado, o audio contem
outro.

Com as duas medianas ancoradas (nativo -> 90, erro -> 30), a logistica de dois
parametros do `GopCalibration` fica determinada por algebra.

    python tool/calibrate.py en --corpus corpus/LibriSpeech/test-clean

Escreve `calibration/<lang>.json` e imprime o relatorio por fonema no stderr.
"""
from __future__ import annotations

import argparse
import json
import math
import random
import statistics
import sys
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from gop import acoustic, g2p, score as scoring  # noqa: E402
from gop.g2p import Phone  # noqa: E402

# Onde as medianas devem cair na regua de 0..100.
TARGET_NATIVE = 0.90
TARGET_WRONG = 0.30
_LOGIT_NATIVE = math.log(TARGET_NATIVE / (1 - TARGET_NATIVE))
_LOGIT_WRONG = math.log(TARGET_WRONG / (1 - TARGET_WRONG))

# Amostras minimas nas DUAS distribuicoes para um fonema ganhar curva propria.
MIN_SAMPLES = 30

# Curvas absurdas vindas de fonema ruidoso sao piores que o fallback. A faixa
# e larga porque a separacao medida e grande: nativo fica perto de -0.1 e uma
# troca real cai varios nats abaixo.
SCALE_RANGE = (0.10, 8.00)

# Primeiro caractere IPA que indica vogal. A troca respeita a classe: dizer
# que um /a/ era um /s/ mede a distancia entre classes, nao o quanto o modelo
# confunde a vogal -- e e confusao dentro da classe que o aluno comete.
VOWEL_STARTS = set("aeiouɑɐɒæəɘɚɛɜɞɨɪɯɵøœɤʊʌʏy")

# O erro que um brasileiro realmente comete, por fonema alvo.
#
# Isto importa mais do que parece. Com troca sorteada a mediana do erro cai
# para ~-12 nats, porque ninguem diz uma consoante aleatoria no lugar de /θ/ --
# diz /t/. Ancorar num erro grande demais estica a escala e produz uma curva
# frouxa, que da nota alta para pronuncia sofrivel. A confusao real e o
# negativo dificil, e e contra ele que a regua tem que ser ajustada.
CONFUSIONS = {
    "en": {
        "θ": ["t", "s", "f"],
        "ð": ["d", "z", "v"],
        "ɪ": ["i", "iː"],
        "iː": ["ɪ"],
        "i": ["ɪ"],
        "æ": ["ɛ", "a"],
        "ʌ": ["a", "ɔ"],
        "ɜ": ["ɛ", "e"],
        "ɜː": ["ɛ", "e"],
        "ə": ["a", "ɛ"],
        "ɚ": ["e", "a"],
        "ŋ": ["n"],
        "h": ["x", "k"],
        "ɹ": ["h", "x", "r"],
        "ɾ": ["t", "d"],
        "v": ["b", "f"],
        "w": ["v", "u"],
        "z": ["s"],
        "ʒ": ["ʃ"],
        "dʒ": ["ʒ"],
        "tʃ": ["ʃ"],
        "l": ["w", "u"],
        "ɔː": ["o"],
        "uː": ["u"],
        "ʊ": ["u"],
    },
    "es": {
        # /r/ vibrante multiplo e o erro classico: o brasileiro faz o /x/ do
        # "rato" ou a batida simples.
        "r": ["ɾ", "x", "h"],
        "ɾ": ["r"],
        "x": ["h", "k"],
        "ʝ": ["ʒ", "j"],
        "ʎ": ["ʝ", "ʒ"],
        "ɲ": ["n"],
        "β": ["b", "v"],
        "ð": ["d"],
        "ɣ": ["g"],
        "s": ["z"],
        "e": ["ɛ"],
        "o": ["ɔ"],
    },
}


def is_vowel(symbol: str) -> bool:
    return bool(symbol) and symbol[0] in VOWEL_STARTS


def negatives_for(lang: str) -> dict[str, list[str]]:
    """Inverte CONFUSIONS: "quem eu sirvo de negativo?".

    A tabela diz alvo -> o que o brasileiro fala no lugar (/θ/ vira /t/). Mas a
    coleta percorre o que o NATIVO falou. Entao, ao encontrar um /t/ nativo, o
    que se aprende e como fica o log-posterior de /θ/ num trecho em que se
    disse /t/ -- que e exatamente a amostra de erro de /θ/.
    """
    inverse: dict[str, list[str]] = {}
    for target, spoken_instead in CONFUSIONS[lang].items():
        for spoken in spoken_instead:
            inverse.setdefault(spoken, []).append(target)
    return inverse


@dataclass
class Utterance:
    audio: Path
    text: str


def read_librispeech(root: Path, limit: int) -> list[Utterance]:
    out: list[Utterance] = []
    for trans in sorted(root.rglob("*.trans.txt")):
        for line in trans.read_text(encoding="utf-8").splitlines():
            uid, _, text = line.partition(" ")
            audio = trans.parent / f"{uid}.flac"
            if audio.exists():
                out.append(Utterance(audio, text))
            if len(out) >= limit:
                return out
    return out


def read_manifest(path: Path, limit: int) -> list[Utterance]:
    """TSV `caminho<TAB>transcricao`, para qualquer corpus."""
    out: list[Utterance] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        audio, _, text = line.partition("\t")
        if text:
            out.append(Utterance(Path(audio), text))
        if len(out) >= limit:
            break
    return out


def fit(native: list[float], wrong: list[float]) -> tuple[dict | None, str]:
    """Resolve center/scale a partir das duas medianas.

    Devolve tambem o motivo da recusa: "sem separacao" e "escala fora da
    faixa" mandam procurar em lugares muito diferentes, e a primeira versao
    reportava as duas como a mesma coisa.
    """
    native_median = statistics.median(native)
    wrong_median = statistics.median(wrong)
    separation = native_median - wrong_median
    if separation <= 0:
        return None, f"sem separacao ({native_median:.2f} <= {wrong_median:.2f})"
    scale = separation / (_LOGIT_NATIVE - _LOGIT_WRONG)
    if not SCALE_RANGE[0] <= scale <= SCALE_RANGE[1]:
        return None, f"escala fora da faixa ({scale:.2f})"
    return {
        "center": round(native_median - _LOGIT_NATIVE * scale, 4),
        "scale": round(scale, 4),
    }, ""


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("lang", choices=["en", "es"])
    ap.add_argument("--corpus", type=Path, help="raiz estilo LibriSpeech")
    ap.add_argument("--manifest", type=Path, help="TSV caminho<TAB>texto")
    ap.add_argument("--limit", type=int, default=300)
    ap.add_argument("--substitutions", type=int, default=6,
                    help="fonemas por fala usados como amostra de erro")
    ap.add_argument("--device", default="cpu")
    ap.add_argument("--seed", type=int, default=7)
    args = ap.parse_args()

    if args.manifest:
        utterances = read_manifest(args.manifest, args.limit)
    elif args.corpus:
        utterances = read_librispeech(args.corpus, args.limit)
    else:
        ap.error("informe --corpus ou --manifest")

    rng = random.Random(args.seed)
    rec = acoustic.PhonemeRecognizer(args.lang, device=args.device)
    specials = rec.special_ids | {rec.blank_id}
    # simbolos do vocabulario que sao fonemas de verdade, para sortear trocas
    pool = [s for s, i in rec.vocab.items() if i not in specials and not s.startswith("<")]
    vowels = [s for s in pool if is_vowel(s)]
    consonants = [s for s in pool if not is_vowel(s)]

    inverse = negatives_for(args.lang)
    native: dict[str, list[float]] = {}
    # erro realista (confusao de brasileiro) e erro generico (fonema sorteado
    # da mesma classe). O generico e um erro grande demais e estica a escala;
    # so entra quando o realista nao junta amostra suficiente.
    wrong_real: dict[str, list[float]] = {}
    wrong_generic: dict[str, list[float]] = {}

    for n, utt in enumerate(utterances, 1):
        try:
            audio = acoustic.load_audio(utt.audio)
            phones, _, dropped = g2p.phonemize(utt.text, args.lang, rec.vocab)
            if dropped or len(phones) < 4:
                continue
            em = rec.emissions(audio)
        except Exception as error:  # corpus real tem arquivo torto
            print(f"[pulou] {utt.audio.name}: {error}", file=sys.stderr)
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
            native.setdefault(m.symbol, []).append(m.lpp)

        # o negativo: o log-posterior de um fonema que NAO foi dito, na
        # janela em que outro foi. Sem realinhar -- realinhar deixaria o
        # Viterbi mover a fronteira para onde a troca fosse plausivel.
        positions = rng.sample(
            range(len(measured)), min(args.substitutions, len(measured))
        )
        for index in positions:
            m = measured[index]
            window = em.log_probs[m.start_frame:m.end_frame].mean(dim=0)

            for target in inverse.get(m.symbol, []):
                if target in rec.vocab:
                    wrong_real.setdefault(target, []).append(
                        float(window[rec.vocab[target]])
                    )

            candidates = vowels if is_vowel(m.symbol) else consonants
            substitute = rng.choice(candidates)
            if substitute != m.symbol:
                wrong_generic.setdefault(substitute, []).append(
                    float(window[rec.vocab[substitute]])
                )

        if n % 25 == 0:
            print(f"  {n}/{len(utterances)} falas", file=sys.stderr)

    # curva global, que substitui o fallback chutado
    all_native = [v for values in native.values() for v in values]
    all_real = [v for values in wrong_real.values() for v in values]
    all_generic = [v for values in wrong_generic.values() for v in values]
    pooled, why = fit(all_native, all_real or all_generic)
    if pooled is None:
        print(f"global rejeitado: {why}", file=sys.stderr)
        return 1

    phones_out: dict[str, dict] = {}
    report: list[tuple] = []
    for symbol in sorted(native):
        good = native[symbol]
        real = wrong_real.get(symbol, [])
        generic = wrong_generic.get(symbol, [])
        bad, source = (real, "real") if len(real) >= MIN_SAMPLES else (generic, "generico")
        if len(good) < MIN_SAMPLES or len(bad) < MIN_SAMPLES:
            report.append((symbol, len(good), len(bad), source, None,
                           "poucas amostras"))
            continue
        curve, why = fit(good, bad)
        if curve is None:
            report.append((symbol, len(good), len(bad), source, None, why))
            continue
        phones_out[symbol] = curve
        report.append((symbol, len(good), len(bad), source, curve, ""))

    print(f"\n{'fonema':>8} {'nativo':>7} {'erro':>6} {'fonte':>9} "
          f"{'center':>8} {'scale':>7}  nota", file=sys.stderr)
    for symbol, n_good, n_bad, source, curve, note in report:
        if curve:
            print(f"{symbol:>8} {n_good:>7} {n_bad:>6} {source:>9} "
                  f"{curve['center']:>8.2f} {curve['scale']:>7.2f}", file=sys.stderr)
        else:
            print(f"{symbol:>8} {n_good:>7} {n_bad:>6} {source:>9} {'-':>8} "
                  f"{'-':>7}  {note}", file=sys.stderr)

    if all_real and all_generic:
        print(f"\nmediana nativa   {statistics.median(all_native):.2f}",
              file=sys.stderr)
        print(f"mediana erro real    {statistics.median(all_real):.2f}"
              "  (confusao de brasileiro)", file=sys.stderr)
        print(f"mediana erro generico {statistics.median(all_generic):.2f}"
              "  (fonema sorteado)", file=sys.stderr)
    print(f"\nglobal: center={pooled['center']} scale={pooled['scale']}",
          file=sys.stderr)
    print(f"curvas proprias: {len(phones_out)} de {len(native)} fonemas",
          file=sys.stderr)

    out = Path(__file__).resolve().parents[1] / "calibration" / f"{args.lang}.json"
    out.write_text(
        json.dumps(
            {
                **pooled,
                "targetNative": TARGET_NATIVE,
                "targetWrong": TARGET_WRONG,
                "phones": phones_out,
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )
    print(f"escrito: {out}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
