#!/usr/bin/env python3
"""Writes a placeholder icon PNG per made-up app for lab/preview.sh: the app's
initials in white on a clear background, the shape of a wordmark. Needs Pillow when
available; without it, no icons are written and the tiles show their names."""
import os
import re
import sys

OUT = sys.argv[1]
APPS = {
    "app.streamly": "Streamly", "app.tubeway": "Tubeway", "app.primetime": "Primetime", "app.orchard": "Orchard TV",
    "app.mouseplus": "Mouse+", "app.peafowl": "Peafowl", "app.topnotch": "Topnotch", "app.cloudgames": "Cloud Games",
    "app.radiola": "Radiola", "app.pictures": "Pictures", "app.browser": "Web Browser", "app.livetv": "Live TV",
    "app.weatherly": "Weatherly", "app.homebrew": "Homebrew Channel", "app.media": "Media Player",
    "app.sports": "Sports Zone", "app.kids": "Kids Corner", "app.music": "Music Hall", "app.news": "Daily News",
    "app.fitness": "Fit & Flex", "app.podcasts": "Podcasts", "app.screensaver": "Screensaver",
}
try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("Pillow not installed; no icons")
    sys.exit(0)
os.makedirs(OUT, exist_ok=True)
font = None
for path in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",):
    if os.path.exists(path):
        font = ImageFont.truetype(path, 64)
for app_id, title in APPS.items():
    img = Image.new("RGBA", (400, 160), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    word = re.sub(r"[^A-Za-z+&]", "", title).upper()[:9]
    box = d.textbbox((0, 0), word, font=font)
    w, h = box[2] - box[0], box[3] - box[1]
    d.text(((400 - w) / 2 - box[0], (160 - h) / 2 - box[1]), word, fill=(255, 255, 255, 235), font=font)
    img.save(os.path.join(OUT, app_id + ".png"))
print("icons:", len(APPS))
