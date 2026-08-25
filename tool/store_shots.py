#!/usr/bin/env python3
"""Turns the raw captures in screenshots/ into the framed images the store wants.

The raw set comes from integration_test/screenshots_test.dart and is a plain
picture of the app. This adds the headline and the ground behind it, at exactly
the pixel sizes App Store Connect already accepts, so a release is two commands
rather than an afternoon in an image editor:

    SHOT_DIR=screenshots/iphone-6.5 flutter drive \
      --driver test_driver/integration_test.dart \
      --target integration_test/screenshots_test.dart -d <simulator id>
    python3 tool/store_shots.py

Edit CAPTIONS to change the words. Nothing else in here needs touching.

Rendering is headless Chrome because it is already on the machine. No image
library, no new dependency.
"""

import pathlib
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
RAW = ROOT / "screenshots"
OUT = RAW / "store"

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

# Order is the order they appear in the listing, and only the first three show
# on the install sheet. The board first, then the thing the search results are
# short of, then the reason to come back.
CAPTIONS = [
    ("01-game", "FEWEST STARS WINS", "Fill a row and you take every star on it"),
    ("02-local-play", "THREE TO FIVE PLAYERS", "One phone hosts, the rest join with a code"),
    ("04-how-to-play", "LEARN IT IN A MINUTE", "Four rows, ten cards, one rule"),
    ("05-profile", "KEEP YOUR RECORD", "Every game counted, by difficulty"),
    ("06-menu", "PLAY ANYWHERE", "No account, no signal, no ads"),
]

# 03-difficulty is captured but not listed. The dialog opens centred while the
# menu's buttons sit on the right, so PLAY pokes out from behind it and the
# slide reads as a rendering glitch rather than a feature. Add the tuple back
# here if you would rather have it than one of the five above.

# The game is landscape-locked, so both the frame and the capture inside it are
# landscape. That inverts the arithmetic from a portrait listing: height is the
# scarce dimension, so the headline band is short and the screen underneath is
# limited by what is left rather than by the frame's width.
#
# 2688 x 1242 is the landscape 6.5" size App Store Connect lists as accepted.
# crop_x and crop_w take a slice out of the capture before framing, in the
# capture's own pixels; nothing needs cropping here, so the slice is the whole
# width and they exist only to keep the size check honest.
DEVICES = {
    "iphone-6.5": dict(
        w=2688, h=1242,
        head_top=60, head_bottom=250,
        headline=72, sub=36,
        # 1880 wide against a 2688 frame: 404 either side, 81 underneath.
        shot_w=1880, shot_top=292, radius=28,
        crop_x=0, crop_w=2688,
    ),
}

# The app's own colours: the backdrop navy it draws behind everything, the
# yellow it uses for "act here", and the periwinkle its secondary text takes.
# The frame and the screen inside it should read as one thing.
PAGE = """<!doctype html>
<meta charset="utf-8">
<style>
  * {{ margin: 0; padding: 0; box-sizing: border-box; }}
  html, body {{ width: {w}px; height: {h}px; overflow: hidden; }}
  body {{
    background:
      radial-gradient(circle at 22% 28%, rgba(255,210,51,0.10) 0, transparent 42%),
      radial-gradient(circle, rgba(194,202,240,0.20) 1.5px, transparent 1.6px)
        0 0 / 54px 54px,
      linear-gradient(160deg, #0A1150 0%, #00053D 58%, #000230 100%);
    font-family: -apple-system, "SF Pro Display", "Helvetica Neue", Arial, sans-serif;
    position: relative;
  }}
  /* Bottom-aligned so a one-line headline and a two-line one both sit the same
     distance above the screen below them. */
  .head {{
    position: absolute;
    top: {head_top}px; left: 0; right: 0; height: {head_h}px;
    display: flex; flex-direction: column; justify-content: flex-end;
    align-items: center; text-align: center;
    padding: 0 {gutter}px;
  }}
  h1 {{
    font-size: {headline}px;
    font-weight: 800;
    letter-spacing: 0.04em;
    line-height: 1.06;
    color: #FFFFFF;
  }}
  p {{
    margin-top: {sub_gap}px;
    font-size: {sub}px;
    font-weight: 600;
    line-height: 1.3;
    color: #C2CAF0;
  }}
  .shot {{
    position: absolute;
    top: {shot_top}px; left: 50%;
    transform: translateX(-50%);
    width: {shot_w}px;
    height: {shot_h}px;
    border-radius: {radius}px;
    overflow: hidden;
    box-shadow: 0 {shadow_y}px {shadow_blur}px rgba(0, 2, 30, 0.55);
    /* The app is nearly the same navy as the ground behind it, so without an
       edge the screen has no boundary at all. Yellow at low alpha reads as a
       rim light rather than a border. */
    outline: 2px solid rgba(255, 210, 51, 0.22);
    outline-offset: -2px;
  }}
  /* Sized and slid so the crop window lands on the app. */
  .shot img {{ display: block; width: {img_w}px; margin-left: {img_x}px; }}
</style>
<div class="head">
  <h1>{headline_text}</h1>
  <p>{sub_text}</p>
</div>
<div class="shot"><img src="{img}"></div>
"""


# A PNG says how big it is in the IHDR chunk, which is always the first one:
# eight bytes of signature, eight of chunk header, then width and height as
# big-endian 32-bit. Cheaper than taking on an image library to read two numbers.
def png_size(path):
    with open(path, "rb") as f:
        head = f.read(24)
    return int.from_bytes(head[16:20], "big"), int.from_bytes(head[20:24], "big")


def render(device, spec, index, name, headline_text, sub_text, workdir):
    raw = RAW / device / f"{name}.png"
    if not raw.exists():
        return f"missing raw capture: {raw.relative_to(ROOT)}"

    raw_w, raw_h = png_size(raw)
    if raw_w != spec["crop_x"] * 2 + spec["crop_w"]:
        # The crop is measured against a capture of a known width. A different
        # one means the wrong simulator, or one left in portrait, and silently
        # framing it would put the slice somewhere arbitrary.
        return (
            f"{device}/{name}.png is {raw_w}px wide, expected "
            f"{spec['crop_x'] * 2 + spec['crop_w']} — wrong simulator, or not rotated to landscape"
        )

    # The capture keeps its own proportions; the crop only decides how much of
    # its width is kept, and the height follows from that.
    scale = spec["shot_w"] / spec["crop_w"]
    shot_h = round(raw_h * scale)
    if spec["shot_top"] + shot_h > spec["h"]:
        return f"{device}/{name}.png would run {spec['shot_top'] + shot_h - spec['h']}px off the bottom"

    html = PAGE.format(
        w=spec["w"], h=spec["h"],
        head_top=spec["head_top"],
        head_h=spec["head_bottom"] - spec["head_top"],
        gutter=round(spec["w"] * 0.09),
        headline=spec["headline"],
        sub=spec["sub"],
        sub_gap=round(spec["headline"] * 0.26),
        shot_w=spec["shot_w"],
        shot_h=shot_h,
        img_w=round(raw_w * scale),
        img_x=-round(spec["crop_x"] * scale),
        shot_top=spec["shot_top"],
        radius=spec["radius"],
        shadow_y=round(spec["h"] * 0.030),
        shadow_blur=round(spec["h"] * 0.070),
        headline_text=headline_text,
        sub_text=sub_text,
        img=raw.as_uri(),
    )
    page = workdir / f"{device}-{name}.html"
    page.write_text(html)

    out_dir = OUT / device
    out_dir.mkdir(parents=True, exist_ok=True)
    out = out_dir / f"{index:02d}-{name.split('-', 1)[1]}.png"

    subprocess.run(
        [
            CHROME,
            "--headless=new",
            "--disable-gpu",
            "--hide-scrollbars",
            "--force-device-scale-factor=1",
            f"--window-size={spec['w']},{spec['h']}",
            # Without a budget Chrome shoots before the image has decoded and
            # writes an empty ground with a headline on it.
            "--virtual-time-budget=4000",
            f"--screenshot={out}",
            page.as_uri(),
        ],
        check=True,
        capture_output=True,
    )
    return None


def main():
    if not pathlib.Path(CHROME).exists():
        sys.exit(f"Chrome not found at {CHROME}")

    problems = []
    made = 0
    with tempfile.TemporaryDirectory() as tmp:
        workdir = pathlib.Path(tmp)
        for device, spec in DEVICES.items():
            if not (RAW / device).is_dir():
                problems.append(f"no raw captures for {device}, skipped")
                continue
            # Wipe first. The output names carry their position in the
            # listing, so reordering or renaming CAPTIONS leaves the previous
            # run's files behind under their old numbers, and a stale slide
            # sitting next to the current ones is how the wrong image gets
            # uploaded.
            out_dir = OUT / device
            if out_dir.is_dir():
                for old_file in out_dir.glob("*.png"):
                    old_file.unlink()

            for index, (name, headline, sub) in enumerate(CAPTIONS, start=1):
                problem = render(device, spec, index, name, headline, sub, workdir)
                if problem:
                    problems.append(problem)
                else:
                    made += 1

    for p in problems:
        print(f"  ! {p}")
    print(f"{made} written to {OUT.relative_to(ROOT)}/")
    # A missing capture means a short listing, which is worth failing over
    # rather than discovering in App Store Connect.
    if problems:
        sys.exit(1)


if __name__ == "__main__":
    main()
