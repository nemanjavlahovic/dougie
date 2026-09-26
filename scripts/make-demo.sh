#!/bin/bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
command -v ffmpeg >/dev/null || { printf 'ffmpeg is required to make the README demo.\n' >&2; exit 1; }

scratch="$(mktemp -d "${TMPDIR:-/tmp}/dougie-demo.XXXXXX")"
trap 'rm -rf "$scratch"' EXIT
"$project_dir/scripts/preview.sh" "$scratch/frames" --demo
ffmpeg -loglevel error -y -framerate 12 -i "$scratch/frames/frame-%03d.png" \
    -vf 'scale=360:-1:flags=lanczos,palettegen=stats_mode=diff' \
    -frames:v 1 "$scratch/palette.png"
ffmpeg -loglevel error -y -framerate 12 -i "$scratch/frames/frame-%03d.png" \
    -i "$scratch/palette.png" \
    -filter_complex '[0:v]scale=360:-1:flags=lanczos[v];[v][1:v]paletteuse=dither=bayer:bayer_scale=4' \
    -loop 0 Resources/demo.gif
printf 'Created %s/Resources/demo.gif\n' "$project_dir"
