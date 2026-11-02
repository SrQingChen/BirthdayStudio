"""Generate the README hero banner and glass badges (repo branding assets)."""

from __future__ import annotations

import math
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "images"
BADGES = OUT / "badges"
S = 2
W, H = 1600, 460
FONT_DIR = Path("C:/Windows/Fonts")


def font(name: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONT_DIR / name), size)


def gradient_bg() -> Image.Image:
    w, h = W * S, H * S
    yy, xx = np.mgrid[0:h, 0:w]
    t = np.clip((xx / w) * 0.35 + (yy / h) * 0.65, 0, 1)
    stops = [(0.0, (49, 26, 56)), (0.55, (26, 15, 34)), (1.0, (11, 7, 16))]
    rgb = np.zeros((h, w, 3), dtype=np.float64)
    for i in range(len(stops) - 1):
        a, ca = stops[i]
        b, cb = stops[i + 1]
        m = (t >= a) & (t <= b)
        f = ((t[m] - a) / (b - a))[:, None]
        rgb[m] = np.array(ca) * (1 - f) + np.array(cb) * f
    img = Image.fromarray(rgb.astype(np.uint8), "RGB").convert("RGBA")

    def glow(cx, cy, radius, color, alpha):
        gy, gx = np.mgrid[0:h, 0:w]
        d = np.sqrt(((gx - cx * w) / (radius * w)) ** 2 + ((gy - cy * h) / (radius * w)) ** 2)
        a = np.clip(1 - d, 0, 1) ** 2.2 * alpha
        layer = np.zeros((h, w, 4), dtype=np.uint8)
        layer[..., 0] = color[0]
        layer[..., 1] = color[1]
        layer[..., 2] = color[2]
        layer[..., 3] = (a * 255).astype(np.uint8)
        return Image.fromarray(layer, "RGBA")

    img = Image.alpha_composite(img, glow(0.72, 0.48, 0.55, (255, 158, 122), 0.22))
    img = Image.alpha_composite(img, glow(0.88, 0.22, 0.32, (143, 214, 198), 0.16))
    img = Image.alpha_composite(img, glow(0.58, 0.92, 0.40, (201, 167, 232), 0.12))

    # bokeh
    bok = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    bd = ImageDraw.Draw(bok)
    rng = random.Random(7)
    for color, alpha, count in [
        ((255, 158, 122), 46, 5),
        ((255, 214, 165), 36, 4),
        ((143, 214, 198), 30, 3),
        ((201, 167, 232), 26, 3),
    ]:
        for _ in range(count):
            x = rng.uniform(0.45, 1.05) * w
            y = rng.uniform(-0.05, 1.05) * h
            r = rng.uniform(0.03, 0.10) * w
            bd.ellipse([x - r, y - r, x + r, y + r], fill=color + (alpha,))
    bok = bok.filter(ImageFilter.GaussianBlur(36 * S))
    img = Image.alpha_composite(img, bok)

    # stars
    stars = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sd = ImageDraw.Draw(stars)
    rng = random.Random(21)
    for _ in range(120):
        x = rng.random() * w
        y = rng.random() * h * 0.92
        r = rng.uniform(0.4, 1.3) * S
        a = int(rng.uniform(18, 110))
        sd.ellipse([x - r, y - r, x + r, y + r], fill=(255, 245, 235, a))
    img = Image.alpha_composite(img, stars)

    # grain
    grain = Image.open(ROOT / "resources" / "textures" / "grain.png").convert("RGBA")
    tile = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for y in range(0, h, grain.height):
        for x in range(0, w, grain.width):
            tile.alpha_composite(grain, (x, y))
    tile.putalpha(tile.getchannel("A").point(lambda v: int(v * 0.55)))
    img = Image.alpha_composite(img, tile)
    return img


def envelope_layer() -> Image.Image:
    w, h = 560, 360
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # contact shadow
    sh = Image.new("RGBA", (w + 80, h + 80), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle([40, 50, w + 20, h + 30], radius=26, fill=(0, 0, 0, 120))
    sh = sh.filter(ImageFilter.GaussianBlur(24))
    img.alpha_composite(sh, (0, 0))

    # body
    body = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    bd = ImageDraw.Draw(body)
    bd.rounded_rectangle([10, 18, w - 10, h - 12], radius=26, fill=(250, 238, 220, 255))
    # vertical cream gradient
    grad = np.linspace(1.03, 0.96, h)
    arr = np.array(body)
    for y in range(h):
        mask = (arr[y, :, :3] > 0).any(axis=1)
        arr[y, mask, :3] = np.clip(arr[y, mask, :3].astype(np.float64) * grad[y], 0, 255).astype(np.uint8)
    body = Image.fromarray(arr, "RGBA")
    bd = ImageDraw.Draw(body)
    # flap
    bd.polygon([(12, 20), (w // 2, int(h * 0.53)), (w - 12, 20)], fill=(243, 226, 201, 255))
    bd.line([(12, 20), (w // 2, int(h * 0.53)), (w - 12, 20)], fill=(120, 88, 64, 90), width=2)
    # bottom folds
    bd.line([(12, h - 14), (w // 2, int(h * 0.55)), (w - 12, h - 14)], fill=(120, 88, 64, 55), width=2)
    # ribbon
    bd.rounded_rectangle([w // 2 - 22, 24, w // 2 + 22, h - 14], radius=8, fill=(233, 196, 106, 235))
    bd.rounded_rectangle([w // 2 - 22, 24, w // 2 + 22, h - 14], radius=8, outline=(120, 80, 30, 80), width=2)
    # border
    bd.rounded_rectangle([10, 18, w - 10, h - 12], radius=26, outline=(120, 88, 64, 70), width=2)
    img.alpha_composite(body, (0, 0))

    # wax seal
    seal = Image.new("RGBA", (220, 220), (0, 0, 0, 0))
    sd = ImageDraw.Draw(seal)
    cx = cy = 110
    pts = []
    for i in range(96):
        a = i / 96 * math.tau
        r = 86 + math.sin(a * 5 + 1.1) * 3.2 + math.sin(a * 9) * 1.6
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r * 0.98))
    sd.polygon(pts, fill=(158, 48, 58, 255))
    # soft specular highlight composited separately (ImageDraw on RGBA replaces alpha)
    hi = Image.new("RGBA", (220, 220), (0, 0, 0, 0))
    hd = ImageDraw.Draw(hi)
    hd.ellipse([cx - 58, cy - 62, cx + 22, cy + 12], fill=(255, 214, 190, 58))
    hd.ellipse([cx - 44, cy - 50, cx - 10, cy - 20], fill=(255, 240, 225, 70))
    hi = hi.filter(ImageFilter.GaussianBlur(12))
    seal = Image.alpha_composite(seal, hi)
    sd = ImageDraw.Draw(seal)
    sd.ellipse([cx - 62, cy - 62, cx + 62, cy + 62], outline=(255, 220, 210, 55), width=3)
    shield_font = font("NotoSerifSC-VF.ttf", 62)
    sd.text((cx, cy + 2), "寿", font=shield_font, fill=(238, 196, 180, 235), anchor="mm")
    seal = seal.filter(ImageFilter.GaussianBlur(0.5))
    img.alpha_composite(seal, (w // 2 - 110, int(h * 0.55) - 110))

    # tiny sparkle near seal
    sp = Image.new("RGBA", (300, 300), (0, 0, 0, 0))
    sdd = ImageDraw.Draw(sp)
    for r, a in [(50, 25), (30, 40), (12, 90)]:
        sdd.ellipse([150 - r, 150 - r, 150 + r, 150 + r], fill=(255, 220, 190, a))
    sp = sp.filter(ImageFilter.GaussianBlur(20))
    img.alpha_composite(sp, (w // 2 - 150, int(h * 0.55) - 150))
    return img


def add_confetti(base: Image.Image) -> None:
    rng = random.Random(33)
    palette = [(255, 143, 171), (255, 209, 102), (142, 202, 230), (184, 224, 210), (205, 180, 219)]
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for _ in range(26):
        x = rng.uniform(930, 1540) * S
        y = rng.uniform(50, 420) * S
        w = rng.uniform(5, 11) * S
        h = rng.uniform(9, 17) * S
        a = rng.uniform(0, math.tau)
        dx, dy = math.cos(a) * w / 2, math.sin(a) * h / 2
        c = palette[rng.randrange(len(palette))] + (rng.randint(110, 220),)
        d.rounded_rectangle([x - w / 2, y - h / 2, x + w / 2, y + h / 2], radius=2 * S, fill=c)
    base.alpha_composite(layer)


def text_layer() -> Image.Image:
    layer = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    x = 110 * S

    def tracked(text, xy, fnt, fill, tracking):
        cx, cy = xy
        for ch in text:
            d.text((cx, cy), ch, font=fnt, fill=fill)
            cx += d.textlength(ch, font=fnt) + tracking

    tracked("BIRTHDAY STUDIO  ·  V1.0", (x, 70 * S), font("georgia.ttf", 20 * S), (255, 176, 138, 230), 3.2 * S)
    title_font = font("georgiab.ttf", 92 * S)
    d.text((x + 2 * S, 115 * S), "BirthdayStudio", font=title_font, fill=(0, 0, 0, 45))
    d.text((x, 112 * S), "BirthdayStudio", font=title_font, fill=(255, 248, 238, 255))

    d.rounded_rectangle([x, 245 * S, x + 78 * S, 249 * S], radius=2 * S, fill=(255, 176, 138, 235))

    serif = font("NotoSerifSC-VF.ttf", 36 * S)
    d.text((x, 268 * S), "把一句「生日快乐」，", font=serif, fill=(255, 233, 223, 238))
    d.text((x, 324 * S), "做成一场会自己展开的七幕仪式。", font=serif, fill=(255, 233, 223, 238))

    sans = font("NotoSansSC-VF.ttf", 20 * S)
    tracked("七幕仪式  /  配置驱动  /  实时预览  /  一键导出", (x, 400 * S), sans, (232, 210, 202, 225), 1.6 * S)
    return layer


def make_hero() -> None:
    img = gradient_bg()
    env = envelope_layer()
    env = env.resize((int(env.width * 1.15), int(env.height * 1.15)), Image.LANCZOS)
    env = env.rotate(-6, expand=True, resample=Image.BICUBIC)
    # glass card behind
    card = Image.new("RGBA", (440 * S, 260 * S), (0, 0, 0, 0))
    cd = ImageDraw.Draw(card)
    cd.rounded_rectangle([2 * S, 2 * S, 438 * S, 258 * S], radius=30 * S,
                         fill=(255, 255, 255, 22), outline=(255, 255, 255, 62), width=2 * S)
    cd.rounded_rectangle([2 * S, 2 * S, 438 * S, 90 * S], radius=30 * S, fill=(255, 255, 255, 10))
    for i, c in enumerate([(255, 176, 138), (143, 214, 198), (255, 213, 166)]):
        cd.ellipse([(34 + i * 22) * S, 32 * S, (40 + i * 22) * S, 38 * S], fill=c + (190,))
    card = card.rotate(7, expand=True, resample=Image.BICUBIC)
    img.alpha_composite(card, (870 * S, 44 * S))
    add_confetti(img)
    img.alpha_composite(env, (1010 * S, 90 * S))
    img.alpha_composite(text_layer())

    # vignette
    w, h = img.size
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.sqrt(((xx - w / 2) / (w / 2)) ** 2 + ((yy - h / 2) / (h / 2)) ** 2)
    a = np.clip((d - 0.55) / 0.75, 0, 1) ** 1.4 * 0.55
    vig = np.zeros((h, w, 4), dtype=np.uint8)
    vig[..., 0] = 5; vig[..., 1] = 3; vig[..., 2] = 8
    vig[..., 3] = (a * 255).astype(np.uint8)
    img = Image.alpha_composite(img, Image.fromarray(vig, "RGBA"))

    # rounded mask + border
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w - 1, h - 1], radius=26 * S, fill=255)
    img.putalpha(mask)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([1, 1, w - 2, h - 2], radius=26 * S, outline=(255, 255, 255, 28), width=2 * S)
    img = img.resize((W, H), Image.LANCZOS)
    OUT.mkdir(parents=True, exist_ok=True)
    img.save(OUT / "readme-hero.png", "PNG")
    print("hero", OUT / "readme-hero.png", img.size)


def make_badge(filename: str, label: str, value: str, accent: str) -> None:
    # rough text metrics for a tight pill
    label_w = len(label) * 6.4 + len(label) * 1.2
    value_w = len(value) * 7.0
    width = int(32 + label_w + 12 + value_w + 24)
    height = 36
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}" role="img">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#2c1a34"/>
      <stop offset="1" stop-color="#150d1e"/>
    </linearGradient>
    <linearGradient id="sheen" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#ffffff" stop-opacity="0.20"/>
      <stop offset="1" stop-color="#ffffff" stop-opacity="0"/>
    </linearGradient>
    <clipPath id="pill"><rect x="0.5" y="0.5" width="{width - 1}" height="{height - 1}" rx="{height / 2}"/></clipPath>
  </defs>
  <g clip-path="url(#pill)">
    <rect x="0.5" y="0.5" width="{width - 1}" height="{height - 1}" rx="{height / 2}" fill="url(#bg)"/>
    <rect x="0.5" y="0.5" width="{width - 1}" height="17" fill="url(#sheen)"/>
    <rect x="0.5" y="0.5" width="{width - 1}" height="{height - 1}" rx="{height / 2}" fill="none" stroke="{accent}" stroke-opacity="0.42"/>
  </g>
  <circle cx="17" cy="{height / 2}" r="3" fill="{accent}"/>
  <text x="28" y="23" font-family="Segoe UI, Noto Sans SC, sans-serif" font-size="9" letter-spacing="1.4" fill="{accent}" fill-opacity="0.9">{label}</text>
  <text x="{28 + label_w + 10}" y="23.6" font-family="Segoe UI, Noto Sans SC, sans-serif" font-size="12.5" font-weight="600" fill="#fff8ee">{value}</text>
</svg>
'''
    BADGES.mkdir(parents=True, exist_ok=True)
    (BADGES / filename).write_text(svg, encoding="utf-8")
    print("badge", filename, width)


def make_badges() -> None:
    make_badge("release.svg", "RELEASE", "v1.0.0", "#ffb08a")
    make_badge("license.svg", "LICENSE", "GPL-3.0", "#7ee0d0")
    make_badge("stack.svg", "STACK", "PySide6 · QML · Qt 3D", "#b3a6e8")
    make_badge("platform.svg", "PLATFORM", "Windows 10 / 11", "#ffd166")
    make_badge("tests.svg", "TESTS", "9 / 9 passing", "#7ee0d0")


if __name__ == "__main__":
    make_hero()
    make_badges()
