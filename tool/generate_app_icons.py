#!/usr/bin/env python3
"""Generates every app icon from the artwork in assets/Icon.svg.

Run from the project root:

    python3 tool/generate_app_icons.py

Why this redraws the SVG rather than rasterising it
---------------------------------------------------
assets/Icon.svg is a *mockup* of an icon sitting on a home screen, not icon
artwork. It is 338x352 rather than square, its corners are pre-rounded at
rx=9, it carries a baked drop shadow, and everything outside the rounded rect
is transparent. Shipping that gives you double-rounded corners with dark
slivers, a shadow inside the platform's own shadow, and an App Store rejection
for the alpha channel.

The artwork inside it is three shapes with exact coordinates, so this redraws
those full-bleed on a square canvas. The SVG stays the source of truth for the
design; this file is the source of truth for the geometry, and the two are
kept in step by hand. Numbers below are lifted straight out of the SVG.

Everything is drawn once at 4096 and downsampled with LANCZOS, which is what
keeps the star's points clean at 20px.
"""

import json
import pathlib

from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parent.parent

# ── Geometry, straight from assets/Icon.svg ───────────────────────────────
#
# Its artwork box is x 4..334 (w 330), y 0..344 (h 344). The card and the star
# are both exactly centred in it. The square canvas uses the artwork's height
# as its side, so the card keeps its size and the gradient still spans it
# top to bottom; the extra 14 units of width become gradient.
SVG_SIDE = 344.0

TOP_COLOR = (0x3D, 0x51, 0xAD)  # stop-color="#3D51AD"
BOTTOM_COLOR = (0x00, 0x00, 0x00)  # stop with no colour, i.e. black

CARD_W = 184.0 / SVG_SIDE  # rect width="184"
CARD_H = 274.0 / SVG_SIDE  # rect height="274"
CARD_R = 24.0 / SVG_SIDE  # rect rx="24"

# The star path is 8 points about (169,172): tips 50 out on each axis, and
# inner corners 15 out on both axes, i.e. at (+-15, +-15).
STAR_TIP = 50.0 / SVG_SIDE
STAR_INNER = 15.0 / SVG_SIDE

SUPERSAMPLE = 4096


def vertical_gradient(size):
    """The background, as one column stretched sideways."""
    column = Image.new("RGB", (1, size))
    for y in range(size):
        t = y / (size - 1)
        column.putpixel(
            (0, y),
            tuple(
                round(TOP_COLOR[i] + (BOTTOM_COLOR[i] - TOP_COLOR[i]) * t)
                for i in range(3)
            ),
        )
    return column.resize((size, size), Image.BILINEAR)


def draw_card_and_star(draw, size, scale, cx=None, cy=None):
    """Paints the white card with the black star on it.

    [scale] shrinks the pair without moving them, which is what the Android
    adaptive foreground needs — see below.
    """
    cx = size / 2 if cx is None else cx
    cy = size / 2 if cy is None else cy

    w = CARD_W * size * scale
    h = CARD_H * size * scale
    r = CARD_R * size * scale
    draw.rounded_rectangle(
        [cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2],
        radius=r,
        fill=(255, 255, 255),
    )

    tip = STAR_TIP * size * scale
    inner = STAR_INNER * size * scale
    draw.polygon(
        [
            (cx, cy - tip),
            (cx + inner, cy - inner),
            (cx + tip, cy),
            (cx + inner, cy + inner),
            (cx, cy + tip),
            (cx - inner, cy + inner),
            (cx - tip, cy),
            (cx - inner, cy - inner),
        ],
        fill=(0, 0, 0),
    )


def master_icon():
    """The full-bleed square icon: gradient, card, star. Opaque."""
    img = vertical_gradient(SUPERSAMPLE)
    draw_card_and_star(ImageDraw.Draw(img), SUPERSAMPLE, scale=1.0)
    return img


def save(img, path, size, keep_alpha=False):
    path.parent.mkdir(parents=True, exist_ok=True)
    out = img.resize((size, size), Image.LANCZOS)
    # iOS refuses an alpha channel outright, and Android has no use for one on
    # the legacy icon. Only the adaptive foreground needs to be cut out.
    if not keep_alpha and out.mode != "RGB":
        out = out.convert("RGB")
    out.save(path, "PNG")
    return path


def build_ios(master):
    """Every slot the existing Contents.json asks for, at size x scale."""
    appicon = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    contents = json.loads((appicon / "Contents.json").read_text())

    wanted = {}
    for entry in contents["images"]:
        filename = entry.get("filename")
        if not filename:
            continue
        side = float(entry["size"].split("x")[0])
        scale = int(entry["scale"].rstrip("x"))
        wanted[filename] = round(side * scale)

    for filename, px in sorted(wanted.items(), key=lambda kv: kv[1]):
        save(master, appicon / filename, px)
    return len(wanted)


# Android's five buckets, as a multiple of the mdpi baseline.
DENSITIES = {
    "mdpi": 1.0,
    "hdpi": 1.5,
    "xhdpi": 2.0,
    "xxhdpi": 3.0,
    "xxxhdpi": 4.0,
}


def build_android(master):
    res = ROOT / "android/app/src/main/res"

    # Legacy launcher icon, 48dp, for anything before Android 8.
    for bucket, factor in DENSITIES.items():
        save(master, res / f"mipmap-{bucket}/ic_launcher.png", round(48 * factor))

    # Adaptive icon: a 108dp canvas of which only the middle 72dp is
    # guaranteed to survive the launcher's mask. The card is scaled so its
    # *diagonal* fits that circle, which is the strict reading — a launcher
    # using a rounded square will simply show it a little smaller than it
    # could. Clipping the corners off the card would be worse.
    #
    # Card diagonal is exactly 330 units of the 344 canvas, so the card scales
    # by 72/330 of the adaptive canvas, then back up by 344/108 because the
    # fractions above are relative to the artwork side, not the 108dp one.
    safe = (72.0 / 330.0) * (SVG_SIDE / 108.0)

    background = vertical_gradient(SUPERSAMPLE)
    foreground = Image.new("RGBA", (SUPERSAMPLE, SUPERSAMPLE), (0, 0, 0, 0))
    draw_card_and_star(ImageDraw.Draw(foreground), SUPERSAMPLE, scale=safe)

    for bucket, factor in DENSITIES.items():
        px = round(108 * factor)
        save(background, res / f"mipmap-{bucket}/ic_launcher_background.png", px)
        save(
            foreground,
            res / f"mipmap-{bucket}/ic_launcher_foreground.png",
            px,
            keep_alpha=True,
        )

    anydpi = res / "mipmap-anydpi-v26"
    anydpi.mkdir(parents=True, exist_ok=True)
    xml = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@mipmap/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        "</adaptive-icon>\n"
    )
    # Only ic_launcher. android:roundIcon isn't declared in the manifest, and
    # declaring it would mean shipping round PNGs for pre-26 densities as well
    # — an adaptive icon already lets a round launcher mask it into a circle.
    (anydpi / "ic_launcher.xml").write_text(xml)


def main():
    master = master_icon()
    ios_count = build_ios(master)
    build_android(master)
    print(f"iOS:     {ios_count} icons")
    print(f"Android: {len(DENSITIES)} legacy + {len(DENSITIES) * 2} adaptive layers")


if __name__ == "__main__":
    main()
