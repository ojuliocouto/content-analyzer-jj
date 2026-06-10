#!/usr/bin/env bash
# Ingestao de reel/video do Instagram: baixa, extrai grids de frames e transcreve o audio.
# Padrao: parakeet-mlx (rapido, local, MLX). Fallback: whisper se parakeet falhar OU se TRANSCRIBER=whisper.
# Uso: ingest.sh "<URL_DO_REEL>" [dir_saida] [modelo_whisper_fallback]
# Ex:  ingest.sh "https://www.instagram.com/reel/XXXX/" /tmp/ig_reel
# Override: TRANSCRIBER=whisper ingest.sh ...
set -euo pipefail

URL="${1:?Passe a URL do reel/video do Instagram}"
OUT="${2:-/tmp/ig_reel_$(date +%s)}"
WHISPER_MODEL="${3:-small}"
BROWSER="${IG_COOKIES_BROWSER:-edge}"
TRANSCRIBER="${TRANSCRIBER:-parakeet}"

# parakeet-mlx vive em ~/.local/bin (instalado via pip --user). Garante PATH.
export PATH="$HOME/.local/bin:$PATH"

mkdir -p "$OUT/frames"
cd "$OUT"

echo "==> [1/4] Baixando o video (cookies do $BROWSER)"
# yt-dlp instalado como modulo python. Cookies do browser logado dao conta do login wall do IG.
python3 -m yt_dlp --cookies-from-browser "$BROWSER" "$URL" -o "reel.%(ext)s" \
  --write-info-json --no-progress 2>"$OUT/ytdlp.log" || true

VIDEO=""
if [ -f reel.mp4 ]; then
  VIDEO="reel.mp4"
else
  VIDEO="$(ls reel.* 2>/dev/null | grep -Ev '\.(json|log|jsonl|txt)$' | head -1 || true)"
fi

if [ -z "${VIDEO:-}" ] || [ ! -f "${VIDEO:-}" ]; then
  # Sem video: provavel carrossel de imagens. Fallback pra gallery-dl.
  echo "    sem video. Tentando carrossel de imagens via gallery-dl..."
  if ! command -v gallery-dl >/dev/null 2>&1; then
    echo "ERRO: gallery-dl nao instalado. Rode: brew install gallery-dl"
    exit 1
  fi
  mkdir -p "$OUT/carousel"
  gallery-dl --cookies-from-browser "$BROWSER" "$URL" -d "$OUT/carousel" --no-mtime 2>"$OUT/gallery-dl.log" || {
    echo "ERRO no gallery-dl. Veja $OUT/gallery-dl.log"; tail -10 "$OUT/gallery-dl.log"; exit 1;
  }
  # gallery-dl cria estrutura gallery-dl/instagram/<user>/<files>. Coleta tudo.
  IMGS=$(find "$OUT/carousel" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | sort)
  NIMG=$(echo "$IMGS" | grep -c . || true)
  if [ "$NIMG" -eq 0 ]; then
    echo "ERRO: gallery-dl rodou mas nao baixou nenhuma imagem."
    exit 1
  fi
  echo "    carrossel: $NIMG imagens em $OUT/carousel/"
  echo ""
  echo "================ PRONTO (CARROSSEL) ================"
  echo "Dir:       $OUT"
  echo "Imagens:   $OUT/carousel/   <- leia com Read tool, sao os slides do post"
  if [ -f "$OUT"/*.info.json ]; then
    INFO=$(ls "$OUT"/*.info.json | head -1)
    echo "Caption:   $INFO  (campo .description)"
    echo ""
    echo "===== CAPTION ====="
    jq -r '.description // "(sem caption)"' "$INFO"
    echo ""
    echo "===== METADADOS ====="
    jq -r '"conta: \(.uploader // .channel // "?")\nlikes: \(.like_count // "?")\ncomments: \(.comment_count // "?")\nposted: \(.upload_date // "?")\nslides: \(.playlist_count // "?")"' "$INFO"
  fi
  echo "===================================================="
  exit 0
fi
echo "    video: $OUT/$VIDEO"

echo "==> [2/4] Specs"
DUR=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$VIDEO" 2>/dev/null | cut -d. -f1)
echo "    duracao: ${DUR}s"

echo "==> [3/4] Grids de frames (1 frame a cada 3s, grid 5x4)"
ffmpeg -i "$VIDEO" -vf "fps=1/3,scale=216:384,tile=5x4" "grid_%02d.png" -y 2>/dev/null
echo "    grids: $(ls grid_*.png 2>/dev/null | wc -l | tr -d ' ') (cada um ~60s do video)"

TXT="${VIDEO%.*}.txt"

transcribe_parakeet() {
  echo "==> [4/4] Transcrevendo audio (parakeet-mlx, NVIDIA Parakeet TDT 0.6B v3)"
  if ! command -v parakeet-mlx >/dev/null 2>&1; then
    echo "    parakeet-mlx nao encontrado no PATH. Fallback pra whisper."
    return 1
  fi
  parakeet-mlx "$VIDEO" --output-format txt --output-dir "$OUT" >"$OUT/parakeet.log" 2>&1 || {
    echo "    parakeet falhou. Veja $OUT/parakeet.log. Fallback pra whisper."
    return 1
  }
  # Parakeet escreve <base>.txt no output-dir. Confirma que saiu nao-vazio.
  if [ ! -s "$OUT/$TXT" ]; then
    echo "    parakeet retornou vazio (provavelmente video sem fala). Tentando whisper como conferencia."
    return 1
  fi
  return 0
}

transcribe_whisper() {
  echo "==> [4/4] Transcrevendo audio (whisper, modelo $WHISPER_MODEL, pt) [fallback]"
  whisper "$VIDEO" --language pt --model "$WHISPER_MODEL" --output_format txt --output_dir "$OUT" --task transcribe >"$OUT/whisper.log" 2>&1 || {
    echo "ERRO no whisper. Veja $OUT/whisper.log"
    return 1
  }
  return 0
}

if [ "$TRANSCRIBER" = "whisper" ]; then
  transcribe_whisper || exit 1
else
  transcribe_parakeet || transcribe_whisper || { echo "Ambos transcribers falharam."; exit 1; }
fi

echo ""
echo "================ PRONTO ================"
echo "Dir:         $OUT"
echo "Video:       $OUT/$VIDEO (${DUR}s)"
echo "Grids:       $OUT/grid_*.png   <- leia com o Read tool"
echo "Transcricao: $OUT/$TXT"
echo "========================================"
echo ""
echo "===== TRANSCRICAO ====="
cat "$OUT/$TXT" 2>/dev/null || echo "(transcricao vazia)"
