#!/usr/bin/env python3
"""Generate the "What to Do" desktop app icon.

Design: rounded-rectangle icon whose background is a classic rainbow (seven
concentric bands, red outermost) with its center offset beyond the lower-right
corner so the arcs sweep across the whole canvas, plus a custom rounded white
"DO!" wordmark on top.

Outputs (SVG source + PNGs + Windows .ico) into this directory.
"""

from __future__ import annotations

import subprocess
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent

WHITE = "#FFFFFF"
SHADOW_COLOR = "#3B1F0B"
RAINBOW = [  # inner -> outer
    "#AF52DE",  # violet
    "#5E5CE6",  # indigo
    "#0A84FF",  # blue
    "#34C759",  # green
    "#FFCC00",  # yellow
    "#FF9500",  # orange
    "#FF3B30",  # red
]

NODE = Path(
    r"C:\Users\DianRan\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe"
)
SHARP = Path(
    r"C:\Users\DianRan\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\node_modules"
)

CANVAS = 1024
CORNER = 232  # rounded-rectangle corner radius (~22.7% of size)

# Rainbow center, offset beyond the lower-right corner of the canvas.
RAINBOW_CX = 1250.0
RAINBOW_CY = 1250.0
RAINBOW_INNER = 300.0
RAINBOW_W = 216.0

# --- Wordmark geometry (custom rounded letters) -----------------------------
W = 80.0    # letter stroke width
YT = 330.0  # cap top
YB = 650.0  # baseline

D_X0 = 110.0     # D left stem centerline
D_T = 75.0       # D top bar length
D_R = 165.0      # D bowl radius

O_CX = 517.0     # capital "O" center
O_CY = 490.0
O_RX = 115.0     # capital "O" centerline horizontal radius
O_RY = 170.0     # capital "O" centerline vertical radius

WORDMARK_SCALE = 0.95

EX_X = 738.5     # "!" bar centerline
EX_W = 85.0
EX_TOP = 332.0
EX_BOT = 536.5
DOT_R = 48.0
DOT_Y = 642.0

def rainbow_group(
    cx: float = RAINBOW_CX,
    cy: float = RAINBOW_CY,
    inner: float = RAINBOW_INNER,
    width: float = RAINBOW_W,
    canvas_w: int = CANVAS,
    canvas_h: int = CANVAS,
) -> str:
    n = len(RAINBOW)
    bands = [
        f'<circle cx="{cx}" cy="{cy}" '
        f'r="{inner + i * width + width / 2:.2f}" '
        f'fill="none" stroke="{color}" stroke-width="{width}"/>'
        for i, color in enumerate(RAINBOW)
    ]
    # Fill inside the innermost band with the innermost (violet) color.
    bg = f'<rect x="0" y="0" width="{canvas_w}" height="{canvas_h}" fill="{RAINBOW[0]}"/>'
    return bg + "\n    " + "\n    ".join(bands)


def wordmark_group(center_x: float, center_y: float, scale: float) -> str:
    d_path = (
        f"M {D_X0} {YB} "
        f"L {D_X0} {YT} "
        f"L {D_X0 + D_T} {YT} "
        f"A {D_R} {D_R} 0 0 1 {D_X0 + D_T} {YB} "
        f"Z"
    )
    cap_o = f'cx="{O_CX}" cy="{O_CY}" rx="{O_RX}" ry="{O_RY}"'
    ex_bar = f"M {EX_X} {EX_BOT} L {EX_X} {EX_TOP}"

    min_x = D_X0 - W / 2
    max_x = EX_X + DOT_R
    min_y = min(YT - W / 2, O_CY - O_RY - W / 2)
    max_y = max(YB + W / 2, O_CY + O_RY + W / 2, DOT_Y + DOT_R)
    dx = center_x - (min_x + max_x) / 2
    dy = center_y - (min_y + max_y) / 2

    stroke = (
        f'fill="none" stroke="{WHITE}" stroke-width="{W}" '
        f'stroke-linejoin="round" stroke-linecap="round"'
    )
    shadow_stroke = (
        f'fill="none" stroke="{SHADOW_COLOR}" stroke-width="{W}" '
        f'stroke-linejoin="round" stroke-linecap="round"'
    )

    return f"""<g transform="translate({center_x} {center_y}) scale({scale}) translate({-center_x} {-center_y})">
    <g transform="translate({dx:.2f} {dy:.2f})">
      <g filter="url(#soft)" opacity="0.38">
        <g transform="translate(0 14)">
          <path d="{d_path}" {shadow_stroke}/>
          <ellipse {cap_o} {shadow_stroke}/>
          <path d="{ex_bar}" fill="none" stroke="{SHADOW_COLOR}" stroke-width="{EX_W}" stroke-linecap="round"/>
          <circle cx="{EX_X}" cy="{DOT_Y}" r="{DOT_R}" fill="{SHADOW_COLOR}"/>
        </g>
      </g>
      <g>
        <path d="{d_path}" {stroke}/>
        <ellipse {cap_o} {stroke}/>
        <path d="{ex_bar}" fill="none" stroke="{WHITE}" stroke-width="{EX_W}" stroke-linecap="round"/>
        <circle cx="{EX_X}" cy="{DOT_Y}" r="{DOT_R}" fill="{WHITE}"/>
      </g>
    </g>
  </g>"""


def build_svg() -> str:
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{CANVAS}" height="{CANVAS}" viewBox="0 0 {CANVAS} {CANVAS}">
  <defs>
    <filter id="soft" x="-30%" y="-30%" width="160%" height="160%">
      <feGaussianBlur stdDeviation="10"/>
    </filter>
    <clipPath id="icon">
      <rect x="0" y="0" width="{CANVAS}" height="{CANVAS}" rx="{CORNER}"/>
    </clipPath>
  </defs>
  <g clip-path="url(#icon)">
    {rainbow_group()}
    {wordmark_group(CANVAS / 2, CANVAS / 2, WORDMARK_SCALE)}
  </g>
</svg>
"""


def build_cover_svg() -> str:
    """800x400 banner reusing the icon's rainbow + wordmark language."""
    cover_w, cover_h = 800, 400
    # Rainbow center beyond the lower-right corner; bands cover every corner.
    rainbow = rainbow_group(
        cx=980.0, cy=980.0, inner=540.0, width=130.0,
        canvas_w=cover_w, canvas_h=cover_h,
    )
    wordmark = wordmark_group(cover_w / 2, cover_h / 2, 0.68)
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{cover_w}" height="{cover_h}" viewBox="0 0 {cover_w} {cover_h}">
  <defs>
    <filter id="soft" x="-30%" y="-30%" width="160%" height="160%">
      <feGaussianBlur stdDeviation="8"/>
    </filter>
  </defs>
  <g>
    {rainbow}
    {wordmark}
  </g>
</svg>
"""


def render_pngs(svg_path: Path, png1024: Path) -> None:
    code = (
        "const sharp = require('" + SHARP.as_posix() + "/sharp');"
        "sharp(process.argv[1]).resize(1024, 1024).png().toFile(process.argv[2])"
        ".then(()=>console.log('ok')).catch(e=>{console.error(e);process.exit(1)})"
    )
    subprocess.run(
        [str(NODE), "-e", code, str(svg_path), str(png1024)],
        check=True,
        capture_output=True,
        text=True,
    )


def render_cover(svg_path: Path, png_path: Path) -> None:
    code = (
        "const sharp = require('" + SHARP.as_posix() + "/sharp');"
        "sharp(process.argv[1]).resize(800, 400).png().toFile(process.argv[2])"
        ".then(()=>console.log('ok')).catch(e=>{console.error(e);process.exit(1)})"
    )
    subprocess.run(
        [str(NODE), "-e", code, str(svg_path), str(png_path)],
        check=True,
        capture_output=True,
        text=True,
    )


def main() -> None:
    svg_path = ROOT / "app-icon.svg"
    png1024 = ROOT / "app-icon-1024.png"
    png512 = ROOT / "app-icon-512.png"
    png256 = ROOT / "app-icon-256.png"
    ico_path = ROOT / "app-icon.ico"
    cover_svg = ROOT / "app-cover-800x400.svg"
    cover_png = ROOT / "app-cover-800x400.png"

    svg_path.write_text(build_svg(), encoding="utf-8")
    render_pngs(svg_path, png1024)

    img1024 = Image.open(png1024).convert("RGBA")
    img1024.resize((512, 512), Image.LANCZOS).save(png512)
    img256 = img1024.resize((256, 256), Image.LANCZOS)
    img256.save(png256)
    img256.save(
        ico_path,
        format="ICO",
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )

    cover_svg.write_text(build_cover_svg(), encoding="utf-8")
    render_cover(cover_svg, cover_png)

    print("SVG :", svg_path)
    print("PNG :", png1024, png512, png256)
    print("ICO :", ico_path)
    print("COVER:", cover_svg, cover_png)


if __name__ == "__main__":
    main()
