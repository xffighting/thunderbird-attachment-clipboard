#!/usr/bin/env python3
"""Generate AttachClip for Thunderbird icons.

Produces three square PNGs (48, 96, 128) from a 1024x1024 master rendered
programmatically. No external image dependencies besides PIL.

Design concept:
- Background: rounded-square teal fill (#1A8C8C).
- Foreground: a white clipboard + a paperclip "C" symbol.
- Subtle inner highlight gradient so the icon looks crisp at 48px.

Output:
- extension/icons/icon-48.png
- extension/icons/icon-96.png
- extension/icons/icon-128.png
- extension/icons/icon-128.png also serves as the AMO store icon.

Re-running is safe (overwrites).
"""

from __future__ import annotations

import math
import os
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ICON_DIR = ROOT / "extension" / "icons"
ICON_DIR.mkdir(parents=True, exist_ok=True)

PRIMARY = (26, 140, 140, 255)        # teal #1A8C8C
PRIMARY_DARK = (15, 92, 92, 255)     # #0F5C5C
HIGHLIGHT = (255, 255, 255, 64)      # subtle white sheen
WHITE = (255, 255, 255, 255)
ACCENT = (255, 196, 64, 255)         # warm accent on clip


def rounded_square(draw: ImageDraw.ImageDraw, size: int, fill, radius_ratio: float = 0.22):
    pad = int(size * 0.02)
    r = int(size * radius_ratio)
    draw.rounded_rectangle(
        [(pad, pad), (size - pad, size - pad)],
        radius=r,
        fill=fill,
    )


def draw_gradient_overlay(img: Image.Image, size: int):
    """Top-left white sheen to add depth."""
    overlay = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    for y in range(size):
        for x in range(size):
            # Distance from top-left normalized 0..1
            d = math.hypot(x, y) / math.hypot(size, size)
            alpha = int(max(0.0, 0.18 - d * 0.35) * 255)
            if alpha > 0:
                od.point((x, y), fill=(255, 255, 255, alpha))
    img.alpha_composite(overlay)


def draw_clipboard(draw: ImageDraw.ImageDraw, size: int):
    """White clipboard body occupying the central rectangle."""
    # Outer clipboard
    cw = int(size * 0.62)
    ch = int(size * 0.78)
    cx = (size - cw) // 2
    cy = (size - ch) // 2 + int(size * 0.04)
    r = int(size * 0.05)
    draw.rounded_rectangle([(cx, cy), (cx + cw, cy + ch)], radius=r, fill=WHITE)

    # Inner card line (subtle)
    pad = int(cw * 0.10)
    draw.rounded_rectangle(
        [(cx + pad, cy + pad + int(ch * 0.05)),
         (cx + cw - pad, cy + ch - pad)],
        radius=int(r * 0.5),
        outline=(180, 220, 220, 255),
        width=max(1, size // 128),
    )

    # Clip "tab" at top
    tab_w = int(cw * 0.36)
    tab_h = int(ch * 0.12)
    tx = cx + (cw - tab_w) // 2
    ty = cy - int(tab_h * 0.45)
    draw.rounded_rectangle([(tx, ty), (tx + tab_w, ty + tab_h)], radius=int(tab_h * 0.4), fill=PRIMARY_DARK)
    # Top tiny accent dot
    dot_r = max(2, int(tab_w * 0.07))
    draw.ellipse(
        [(tx + tab_w // 2 - dot_r, ty + tab_h // 2 - dot_r),
         (tx + tab_w // 2 + dot_r, ty + tab_h // 2 + dot_r)],
        fill=ACCENT,
    )

    return (cx, cy, cw, ch)


def draw_paperclip(draw: ImageDraw.ImageDraw, size: int, bbox):
    """Draw a paperclip 'C' shape on the clipboard inside the bbox."""
    cx, cy, cw, ch = bbox
    # Paperclip stylized as thick stroked arc + bar = "C + bar" reading
    clip_color = ACCENT
    stroke = max(2, size // 22)

    # Center of the arc in the upper-right area
    arc_cx = cx + int(cw * 0.62)
    arc_cy = cy + int(ch * 0.42)
    arc_r = int(min(cw, ch) * 0.22)
    # Arc going from 200° to 540° (= from upper-left around to lower)
    draw.arc(
        [(arc_cx - arc_r, arc_cy - arc_r),
         (arc_cx + arc_r, arc_cy + arc_r)],
        start=200, end=540,
        fill=clip_color,
        width=stroke,
    )
    # Vertical bar at the inner end
    bx0 = arc_cx - arc_r + int(arc_r * 0.12)
    by0 = arc_cy - int(arc_r * 0.55)
    bx1 = bx0
    by1 = arc_cy + int(arc_r * 0.55)
    draw.line([(bx0, by0), (bx1, by1)], fill=clip_color, width=stroke)


def render(size: int) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    rounded_square(draw, size, PRIMARY)
    draw_gradient_overlay(img, size)
    bbox = draw_clipboard(draw, size)
    draw_paperclip(draw, size, bbox)
    # Subtle 1px darker edge for crispness at 48px
    return img.convert("RGBA")


def main():
    sizes = [48, 96, 128]
    master = render(256)  # internal crisp render
    for s in sizes:
        # Always downscale from a 256 master -> sharp small icons
        out = master.resize((s, s), Image.LANCZOS)
        path = ICON_DIR / f"icon-{s}.png"
        out.save(path, format="PNG", optimize=True)
        print(f"wrote {path} ({s}x{s})")
    # Also store a 128 master copy as icon-128.png explicitly (overwrites if needed)
    master_128 = master.resize((128, 128), Image.LANCZOS)
    master_128.save(ICON_DIR / "icon-128.png", format="PNG", optimize=True)
    print("done.")


if __name__ == "__main__":
    main()
