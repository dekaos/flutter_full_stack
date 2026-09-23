"""Grafema -> fonema via espeak-ng, preservando fronteiras de palavra."""
from __future__ import annotations

import re
import subprocess
from dataclasses import dataclass

# Vozes do espeak-ng. es-419 (latino) e o default por causa do seseo:
# em "es" (castelhano) 'cerveza' vira /θ/ e alunos latinos seriam punidos injustamente.
ESPEAK_VOICE = {"en": "en-us", "es": "es-419"}

STRESS_MARKS = "ˈˌ'"
_WORD_RE = re.compile(r"[^\W\d_]+(?:['’][^\W\d_]+)*", re.UNICODE)


@dataclass
class Phone:
    symbol: str          # simbolo IPA canonico
    word_idx: int        # indice da palavra de origem
    token_ids: list[int] # ids no vocabulario do modelo (>1 se precisou decompor)


def split_words(text: str) -> list[str]:
    return _WORD_RE.findall(text)


def espeak_ipa(word: str, voice: str) -> list[str]:
    """Roda espeak-ng com separador de fonemas e devolve os simbolos IPA."""
    out = subprocess.run(
        ["espeak-ng", "-q", "--ipa", "--sep=_", "-v", voice, "--", word],
        capture_output=True, text=True, check=True,
    ).stdout.strip()
    phones = []
    for raw in out.replace("\n", " ").split("_"):
        p = raw.strip().strip(STRESS_MARKS).replace(" ", "")
        # tira marcas de tonicidade e o ZWJ que o espeak usa em ligaduras
        for ch in ("ˈ", "ˌ", "\u200d", "\u0361"):
            p = p.replace(ch, "")
        if p:
            phones.append(p)
    return phones


def map_to_vocab(symbol: str, vocab: dict[str, int]) -> list[int] | None:
    """Casa um simbolo IPA do espeak com o vocabulario do modelo.

    Tenta, em ordem: match exato -> sem marca de comprimento (ː) ->
    segmentacao gulosa em simbolos conhecidos (ditongos viram 2 tokens).
    """
    for cand in (symbol, symbol.replace("ː", ""), symbol.replace("ʰ", "")):
        if cand in vocab:
            return [vocab[cand]]
    ids, i = [], 0
    while i < len(symbol):
        for size in (3, 2, 1):
            chunk = symbol[i:i + size]
            if chunk in vocab:
                ids.append(vocab[chunk])
                i += size
                break
        else:
            return None
    return ids or None


def phonemize(text: str, lang: str, vocab: dict[str, int]) -> tuple[list[Phone], list[str], list[str]]:
    """Devolve (fonemas mapeados, palavras, simbolos descartados)."""
    voice = ESPEAK_VOICE[lang]
    words = split_words(text)
    phones: list[Phone] = []
    dropped: list[str] = []
    for idx, word in enumerate(words):
        for sym in espeak_ipa(word, voice):
            ids = map_to_vocab(sym, vocab)
            if ids is None:
                dropped.append(sym)
                continue
            phones.append(Phone(symbol=sym, word_idx=idx, token_ids=ids))
    return phones, words, dropped
