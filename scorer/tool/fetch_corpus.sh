#!/usr/bin/env bash
# Baixa o corpus nativo que ancora a calibracao.
#
#     ./tool/fetch_corpus.sh en     # LibriSpeech test-clean, 330 MB, CC BY 4.0
#     ./tool/fetch_corpus.sh es     # espanhol chileno, 586 MB, CC BY-SA 4.0
#     ./tool/fetch_corpus.sh ko     # Zeroth test split, 60 MB, CC BY 4.0
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
  ko)
    # Zeroth-Korean, so o split de TESTE (457 falas, 10 falantes, CC BY 4.0),
    # pelo mesmo motivo do LibriSpeech: medir a mediana nativa em dado que o
    # modelo viu no treino infla a confianca e afrouxa a curva.
    #
    # Fonte: o espelho Bingsu/zeroth-korean no Hugging Face, em parquet
    # (60 MB), com a revisao fixada. O tarball canonico do OpenSLR 40 tem os
    # mesmos 457 arquivos mas pesa 10 GB (treino + lexico + LM junto) e o
    # openslr.org limita a ~1 MB/s por conexao -- 2,5 h contra segundos.
    REV=bd173fe2c8ed0dccd47acb4eda77542593651622
    PARQUET="corpus/ko_hf/test.parquet"
    if [ ! -f "$DEST/ko/manifest.tsv" ]; then
      mkdir -p "$DEST/ko" "$(dirname "$PARQUET")"
      if [ ! -f "$PARQUET" ]; then
        echo "baixando o split de teste do Zeroth (parquet, 60 MB)..."
        curl -sS -L --fail -o "$PARQUET" \
          "https://huggingface.co/datasets/Bingsu/zeroth-korean/resolve/$REV/data/test-00000-of-00001-a41b955a631e582e.parquet"
      fi
      # O parquet embute o FLAC de cada fala. Extrai um arquivo por fala e
      # monta o manifest caminho<TAB>transcricao que o calibrate.py quer.
      uv run --with pyarrow python - "$PARQUET" "$DEST/ko" <<'PY'
import pathlib, sys
import pyarrow.parquet as pq
t = pq.read_table(sys.argv[1])
out = pathlib.Path(sys.argv[2]).resolve()
(out / "audio").mkdir(parents=True, exist_ok=True)
rows = []
for i in range(t.num_rows):
    blob = t.column("audio")[i].as_py()["bytes"]
    f = out / "audio" / f"{i:04d}.flac"
    f.write_bytes(blob)
    rows.append(f"{f}\t{t.column('text')[i].as_py()}")
(out / "manifest.tsv").write_text("\n".join(rows) + "\n", encoding="utf-8")
print(f"extraidas {len(rows)} falas -> {out / 'manifest.tsv'}", file=sys.stderr)
PY
    fi
    echo "pronto: use --manifest $DEST/ko/manifest.tsv"
    wc -l < "$DEST/ko/manifest.tsv" | xargs echo "falas:"
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
