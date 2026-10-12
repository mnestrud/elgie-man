#!/usr/bin/env bash
# Usage: set-background.sh <image>
# Makes backgrounds/bg.jpg (1920x1080, cropped to fill) and backgrounds/bg-blur.jpg
# (the same, blurred and slightly darkened, sampled by the glass tiles). Then run
# scripts/deploy.sh to send them to the TV. Uses ffmpeg.
set -euo pipefail
cd "$(dirname "$0")/.."
IN="$1"
mkdir -p backgrounds
FIT="scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080"
ffmpeg -loglevel error -y -i "$IN" -vf "$FIT" -q:v 3 backgrounds/bg.jpg
ffmpeg -loglevel error -y -i "$IN" -vf "$FIT,gblur=sigma=36:steps=3,eq=brightness=-0.06:saturation=1.15" -q:v 4 backgrounds/bg-blur.jpg
ls -la backgrounds/
