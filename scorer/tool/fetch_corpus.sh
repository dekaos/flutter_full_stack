#!/usr/bin/env bash
# Baixa o corpus nativo que ancora a calibracao.
#
#     ./tool/fetch_corpus.sh en     # LibriSpeech test-clean, 330 MB, CC BY 4.0
#     ./tool/fetch_corpus.sh es     # espanhol chileno, 586 MB, CC BY-SA 4.0
#
# Em ingles, deliberadamente o split de TESTE: o modelo acustico foi fine-tunado
# em Common Voice, e medir a mediana nativa em dado que ele viu no treino infla
# a confianca e afrouxa a curva.
#
# Em espanhol, um conjunto latino-americano -- nao castelhano -- pela mesma
# razao que o G2P usa es-419: com seseo, medir /s/ contra falante que faz /θ/
# calibra o fonema errado.
set -euo pipefail
LANG_CODE="${1:-en}"
DEST="${DEST:-corpus}"
mkdir -p "$DEST"

case "$LANG_CODE" in
  en)
    if [ ! -d "$DEST/LibriSpeech/test-clean" ]; then
      echo "baixando LibriSpeech test-clean (330 MB)..."
      curl -sS -L --fail -o "$DEST/test-clean.tar.gz" \
        https://www.openslr.org/resources/12/test-clean.tar.gz
      tar -xzf "$DEST/test-clean.tar.gz" -C "$DEST"
      rm -f "$DEST/test-clean.tar.gz"
    fi
    echo "pronto: use --corpus $DEST/LibriSpeech/test-clean"
    find "$DEST/LibriSpeech/test-clean" -name '*.flac' | wc -l | xargs echo "falas:"
    ;;
  es)
    if [ ! -d "$DEST/es" ]; then
      echo "baixando espanhol chileno (586 MB)..."
      curl -sS -L --fail -o "$DEST/es.zip" \
        https://www.openslr.org/resources/71/es_cl_female.zip
      mkdir -p "$DEST/es"
      unzip -q "$DEST/es.zip" -d "$DEST/es"
      rm -f "$DEST/es.zip"
    fi
    # line_index.tsv traz so o nome do arquivo; o calibrate.py quer caminho.
    INDEX="$(find "$DEST/es" -name 'line_index.tsv' | head -1)"
    WAVS="$(dirname "$INDEX")"
    awk -F'\t' -v dir="$WAVS" '{print dir "/" $1 ".wav\t" $2}' "$INDEX" \
      > "$DEST/es/manifest.tsv"
    echo "pronto: use --manifest $DEST/es/manifest.tsv"
    wc -l < "$DEST/es/manifest.tsv" | xargs echo "falas:"
    ;;
  speechocean762)
    # O unico corpus publico com nota de pronuncia dada por especialista
    # humano: 5000 falas, 250 falantes nao nativos, 5 avaliadores, nota por
    # fonema, palavra e frase. CC BY 4.0, uso comercial liberado. E contra
    # ele que da para saber se o nosso numero concorda com o de um professor.
    if [ ! -d "$DEST/speechocean762" ]; then
      echo "baixando speechocean762 (521 MB)..."
      curl -sS -L --fail -o "$DEST/so762.tar.gz" \
        https://www.openslr.org/resources/101/speechocean762.tar.gz
      mkdir -p "$DEST/speechocean762"
      tar -xzf "$DEST/so762.tar.gz" -C "$DEST/speechocean762" --strip-components=1
      rm -f "$DEST/so762.tar.gz"
    fi
    echo "pronto: $DEST/speechocean762"
    ;;
  *)
    echo "idioma desconhecido: $LANG_CODE" >&2
    exit 1
    ;;
esac
