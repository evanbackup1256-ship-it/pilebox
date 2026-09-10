"""Renders the Pilebox app mark to PNG + multi-resolution ICO.

Draws at 8x then downsamples (LANCZOS), which gives clean antialiased edges
without needing an SVG rasterizer.

Mark concept: two overlapping index cards (the physical "slips" a
Zettelkasten is named for) joined by a short connecting line - a literal,
concrete image of what the app does (linked atomic notes), rather than a
generic document/notebook glyph. Deliberately flat and geometric: no gloss,
no drop-shadow-heavy skeuomorphism, no gradient-mesh "AI app icon" look.

Usage:  python tools/make_icon.py
"""

from __future__ import annotations

import os
from PIL import Image, ImageDraw

S = 256          # nominal size
SS = 8           # supersample factor
W = S * SS

GROUND = (18, 17, 23, 255)      # near-black, faint violet cast
LIFT = (40, 38, 50, 255)
CARD_BACK = (58, 56, 70, 255)   # the rear card: muted, recedes
CARD_FRONT = (247, 244, 238, 255)  # the front card: warm paper white
INK = (30, 28, 34, 255)          # ruled lines / text marks on the card
AMBER = (232, 163, 61, 255)      # the connecting thread + accent dot


def rounded_rect(draw, box, radius, fill=None, outline=None, width=1):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def build() -> Image.Image:
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Ground tile with a soft top-left lift so it isn't a flat slab.
    rounded_rect(d, [0, 0, W - 1, W - 1], radius=56 * SS, fill=GROUND)

    lift = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    ld = ImageDraw.Draw(lift)
    span = int(W * 0.55)
    for y in range(span):
        t = y / span
        ld.line([(0, y), (W, y)], fill=LIFT[:3] + (int(55 * (1 - t)),))
    img.alpha_composite(lift)

    clip = Image.new("L", (W, W), 0)
    ImageDraw.Draw(clip).rounded_rectangle([0, 0, W - 1, W - 1], radius=56 * SS, fill=255)
    img.putalpha(Image.composite(clip, Image.new("L", (W, W), 0), clip))

    # --- Rear card: rotated slightly behind, in shadow -----------------
    rear = Image.new("RGBA", (150 * SS, 108 * SS), (0, 0, 0, 0))
    rd = ImageDraw.Draw(rear)
    rounded_rect(rd, [0, 0, 150 * SS - 1, 108 * SS - 1], radius=10 * SS, fill=CARD_BACK)
    rear = rear.rotate(-9, expand=True, resample=Image.BICUBIC)
    img.alpha_composite(rear, (int(48 * SS), int(58 * SS)))

    # --- Front card: the "open" slip, slightly rotated the other way ---
    front = Image.new("RGBA", (156 * SS, 114 * SS), (0, 0, 0, 0))
    fd = ImageDraw.Draw(front)
    rounded_rect(fd, [0, 0, 156 * SS - 1, 114 * SS - 1], radius=10 * SS, fill=CARD_FRONT)

    # Ruled lines on the card, offset like real index-card ruling.
    for i, frac in enumerate((0.38, 0.56, 0.74)):
        y = int(114 * SS * frac)
        x1 = int(18 * SS)
        x2 = int((156 - 18 - (18 if i == 2 else 0)) * SS)
        fd.line([(x1, y), (x2, y)], fill=INK, width=int(4.5 * SS))

    front = front.rotate(7, expand=True, resample=Image.BICUBIC)
    img.alpha_composite(front, (int(50 * SS), int(64 * SS)))

    # --- Connecting thread: the wikilink between two slips --------------
    # Drawn last, on top, as the one warm accent - this is the "aha" detail
    # that reads instantly as "linked notes" rather than "notepad app".
    p1 = (int(96 * SS), int(70 * SS))
    p2 = (int(168 * SS), int(158 * SS))
    d.line([p1, p2], fill=AMBER, width=int(3.2 * SS))
    for p in (p1, p2):
        r = int(6 * SS)
        d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=AMBER)
        r2 = int(2.6 * SS)
        d.ellipse([p[0] - r2, p[1] - r2, p[0] + r2, p[1] + r2], fill=GROUND)

    return img.resize((S, S), Image.LANCZOS)


def main() -> None:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    brand = os.path.join(root, "flutter_app", "assets", "brand")
    os.makedirs(brand, exist_ok=True)

    icon = build()

    png = os.path.join(brand, "logo.png")
    icon.save(png)
    print("wrote", png)

    ico_path = os.path.join(root, "flutter_app", "windows", "runner",
                            "resources", "app_icon.ico")
    if os.path.isdir(os.path.dirname(ico_path)):
        icon.save(
            ico_path,
            sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64),
                   (128, 128), (256, 256)],
        )
        print("wrote", ico_path)
    else:
        print("skipped ICO (runner resources dir missing)")

    # Drop the leftover RPC-era Discord-specific asset; Pilebox has no use
    # for a 512px non-transparent Discord Rich Presence image.
    stale = os.path.join(brand, "discord_logo_512.png")
    if os.path.exists(stale):
        os.remove(stale)
        print("removed stale", stale)


if __name__ == "__main__":
    main()
