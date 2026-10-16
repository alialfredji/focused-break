#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# Frame-preserving cartoon upscale. HQ3x smooths flat-color outlines before
# resampling to the app's 1024px texture limit. No frame interpolation/redrawing.
ffmpeg -hide_banner -loglevel error -y \
  -i "$PROJECT_DIR/assets/HaveABreak-original.gif" \
  -filter_complex '[0:v]format=rgba,split[color][mask];[mask]alphaextract,scale=1024:742:flags=lanczos[alpha];[color]hqx=n=3,scale=1024:742:flags=lanczos[up];[up][alpha]alphamerge,split[a][b];[a]palettegen=reserve_transparent=1:transparency_color=000000:stats_mode=full[p];[b][p]paletteuse=dither=none:alpha_threshold=160[out]' \
  -map '[out]' -fps_mode passthrough -loop 0 \
  "$PROJECT_DIR/Sources/EventHorizon/HaveABreak.gif"
