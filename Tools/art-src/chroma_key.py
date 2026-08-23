#!/usr/bin/env python3
"""Chroma-key magenta-background renders into transparent PNGs.

Usage: chroma_key.py input.png output.png

Soft-keys the #FF00FF backdrop: pixels are unmixed against the backdrop so
anti-aliased edges keep their color instead of going pink.
"""
import sys

from PIL import Image


def key(path_in, path_out):
    img = Image.open(path_in).convert("RGB")
    px = img.load()
    w, h = img.size
    out = Image.new("RGBA", (w, h))
    opx = out.load()
    br, bg_, bb = 255, 0, 255
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            # "magenta-ness": how far min(r,b) sits above g
            s = min(r, b) - g
            if s <= 8:
                alpha = 255
                fr, fg, fb = r, g, b
            elif s >= 140:
                alpha = 0
                fr, fg, fb = 0, 0, 0
            else:
                a = 1.0 - (s - 8) / 132.0
                alpha = round(a * 255)
                # unmix: pixel = a*fg + (1-a)*backdrop
                fr = round((r - (1 - a) * br) / a)
                fg = round((g - (1 - a) * bg_) / a)
                fb = round((b - (1 - a) * bb) / a)
                fr, fg, fb = max(0, min(255, fr)), max(0, min(255, fg)), max(0, min(255, fb))
            opx[x, y] = (fr, fg, fb, alpha)
    out.save(path_out)


if __name__ == "__main__":
    key(sys.argv[1], sys.argv[2])
