"""Modelo acustico CTC de fonemas + alinhamento forcado."""
from __future__ import annotations

import json
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path

import numpy as np
import soundfile as sf
import torch
import torchaudio.functional as AF
from huggingface_hub import hf_hub_download
from transformers import AutoFeatureExtractor, AutoModelForCTC

SAMPLE_RATE = 16_000

# Um modelo por idioma: lv-60 e melhor em ingles (pre-treino LibriVox),
# xlsr-53 e melhor em espanhol (pre-treino multilingue). Ambos emitem IPA.
# Revisao do pacote exportado. Entra no nome do arquivo porque o app guarda o
# modelo por nome e nunca rebaixa um download existente: corrigir o modelo tem
# que produzir um arquivo novo, ou o aparelho que ja baixou fica com o antigo.
MODEL_REVISION = "r2"

MODELS = {
    "en": "facebook/wav2vec2-lv-60-espeak-cv-ft",
    "es": "facebook/wav2vec2-xlsr-53-espeak-cv-ft",
}

# Commit de cada modelo no Hugging Face, fixado. Sem ele o from_pretrained pega
# o `main` do dia, e um export refeito meses depois poderia sair de pesos
# diferentes sem ninguem notar -- enquanto as curvas de calibration/<lang>.json
# e o vocabulario do lexico foram medidos contra estes. Trocar um destes e
# trocar o modelo: sobe MODEL_REVISION e refaz export, lexico e calibracao
# (docs/pronunciation-models.md).
UPSTREAM_REVISIONS = {
    "en": "ae45363bf3413b374fecd9dc8bc1df0e24c3b7f4",
    "es": "2c733782da5604684829819a5eb744c193fe9398",
}


def revision_for(model_id: str) -> str | None:
    """O commit fixado, para um dos modelos acima; None para qualquer outro."""
    for lang, known in MODELS.items():
        if known == model_id:
            return UPSTREAM_REVISIONS[lang]
    return None


def vocab_file(model_id: str) -> str:
    """Caminho local do vocab.json do modelo, na revisao fixada."""
    return hf_hub_download(model_id, "vocab.json", revision=revision_for(model_id))


def load_audio(path: str | Path) -> np.ndarray:
    """Converte qualquer formato para PCM float32 16 kHz mono via ffmpeg."""
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        wav = tmp.name
    subprocess.run(
        ["ffmpeg", "-y", "-i", str(path), "-ar", str(SAMPLE_RATE), "-ac", "1",
         "-c:a", "pcm_s16le", wav],
        capture_output=True, check=True,
    )
    audio, sr = sf.read(wav, dtype="float32")
    Path(wav).unlink(missing_ok=True)
    assert sr == SAMPLE_RATE
    return audio


@dataclass
class Emissions:
    log_probs: torch.Tensor  # (T, V) log-softmax
    frame_sec: float         # duracao de cada frame em segundos
    audio_sec: float


class PhonemeRecognizer:
    def __init__(self, lang: str, model_id: str | None = None, device: str = "cpu"):
        self.lang = lang
        self.model_id = model_id or MODELS[lang]
        self.device = device
        # Carrega o vocab.json direto: o Wav2Vec2PhonemeCTCTokenizer exigiria a
        # lib phonemizer, que nao existe no device. Fazemos o G2P em g2p.py.
        revision = revision_for(self.model_id)
        self.features = AutoFeatureExtractor.from_pretrained(self.model_id, revision=revision)
        self.model = (
            AutoModelForCTC.from_pretrained(self.model_id, revision=revision).to(device).eval()
        )
        with open(vocab_file(self.model_id), encoding="utf-8") as f:
            self.vocab: dict[str, int] = json.load(f)
        self.id_to_sym = {i: s for s, i in self.vocab.items()}
        self.blank_id = self.model.config.pad_token_id or 0
        self.special_ids = {self.vocab[t] for t in ("<pad>", "<unk>", "<s>", "</s>", "|")
                            if t in self.vocab}

    @torch.inference_mode()
    def emissions(self, audio: np.ndarray) -> Emissions:
        inputs = self.features(audio, sampling_rate=SAMPLE_RATE, return_tensors="pt")
        values = inputs.input_values.to(self.device)
        logits = self.model(values).logits[0]           # (T, V)
        # sempre em CPU: o forced_align do torchaudio nao roda em MPS, e o
        # ganho do acelerador esta no passe acustico, nao no Viterbi.
        log_probs = torch.log_softmax(logits.float(), dim=-1).cpu()
        audio_sec = len(audio) / SAMPLE_RATE
        return Emissions(log_probs, audio_sec / log_probs.shape[0], audio_sec)


@dataclass
class Span:
    token_id: int
    start: int   # frame inicial (inclusivo)
    end: int     # frame final (exclusivo)


def align(emissions: Emissions, target_ids: list[int], blank_id: int) -> list[Span]:
    """Alinhamento forcado CTC (Viterbi) do audio contra a sequencia canonica."""
    lp = emissions.log_probs.unsqueeze(0)
    targets = torch.tensor([target_ids], dtype=torch.int32, device=lp.device)
    aligned, scores = AF.forced_align(lp, targets, blank=blank_id)
    spans = AF.merge_tokens(aligned[0], scores[0], blank=blank_id)
    return [Span(int(s.token), int(s.start), int(s.end)) for s in spans]
