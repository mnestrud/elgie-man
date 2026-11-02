#!/usr/bin/env bash
# Usage: set-background.sh <image>
# Makes backgrounds/bg.jpg (1920x1080, cropped to fill). Then run scripts/deploy.sh
# to send it to the TV. Uses ffmpeg.
set -euo pipefail
cd "$(dirname "$0")/.."
IN="$1"
mkdir -p backgrounds
FIT="scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080"
ffmpeg -loglevel error -y -i "$IN" -vf "$FIT" -q:v 3 backgrounds/bg.jpg
rm -f backgrounds/bg-blur.jpg    # made by older versions; no longer used
ls -la backgrounds/
