"""Colour science helpers shared by the show, editor and health linter."""

from __future__ import annotations

import colorsys
import math


def parse_hex(value: str) -> tuple[int, int, int, int]:
    """#RRGGBB or #AARRGGBB -> (r, g, b, a).  Raises ValueError on bad input."""
    if not value or not value.startswith("#"):
        raise ValueError(f"not a hex colour: {value!r}")
    h = value[1:]
    if len(h) == 6:
        r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
        return r, g, b, 255
    if len(h) == 8:
        # Qt's #AARRGGBB convention, matching QML colour literals.
        a = int(h[0:2], 16)
        r = int(h[2:4], 16)
        g = int(h[4:6], 16)
        b = int(h[6:8], 16)
        return r, g, b, a
    raise ValueError(f"bad hex colour: {value!r}")


def to_hex(r: float, g: float, b: float) -> str:
    def q(x: float) -> int:
        return max(0, min(255, round(x * 255)))

    return f"#{q(r):02x}{q(g):02x}{q(b):02x}"


def blend(fg: str, bg: str, alpha: float) -> str:
    fr, fg_, fb, _ = parse_hex(fg)
    br, bg_, bb, _ = parse_hex(bg)
    alpha = max(0.0, min(1.0, alpha))
    return to_hex(
        (fr * alpha + br * (1 - alpha)) / 255,
        (fg_ * alpha + bg_ * (1 - alpha)) / 255,
        (fb * alpha + bb * (1 - alpha)) / 255,
    )


def _linear(channel: int) -> float:
    c = channel / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def relative_luminance(color: str) -> float:
    r, g, b, _ = parse_hex(color)
    return 0.2126 * _linear(r) + 0.7152 * _linear(g) + 0.0722 * _linear(b)


def contrast_ratio(a: str, b: str) -> float:
    la = relative_luminance(a)
    lb = relative_luminance(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def hex_to_hsl(color: str) -> tuple[float, float, float]:
    r, g, b, _ = parse_hex(color)
    h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
    return h * 360.0, s, l


def hsl_to_hex(h: float, s: float, l: float) -> str:
    r, g, b = colorsys.hls_to_rgb((h % 360) / 360.0, max(0, min(1, l)), max(0, min(1, s)))
    return to_hex(r, g, b)


def harmony_palette(
    base_hue: float,
    mode: str = "analogous",
    saturation_range: tuple[float, float] = (0.46, 0.68),
    lightness_range: tuple[float, float] = (0.64, 0.78),
    count: int = 6,
) -> list[str]:
    """Deterministic HSL-bucket palette: hue varies, L/S stay in a narrow band.

    This is the F-33 replacement for naked random colour: brightness and
    saturation are constrained, only hue walks the wheel.
    """
    offsets: list[float]
    if mode == "triadic":
        offsets = [0, 120, 240]
    elif mode == "complementary":
        offsets = [0, 180]
    else:  # analogous
        offsets = [0, 28, 56, -28, -56]
    s0, s1 = saturation_range
    l0, l1 = lightness_range
    out: list[str] = []
    for i in range(max(1, count)):
        h = base_hue + offsets[i % len(offsets)]
        # Deterministic variation inside the buckets, avoids a flat look.
        t = (i * 0.61803398875) % 1.0
        s = s0 + (s1 - s0) * t
        l = l0 + (l1 - l0) * ((i * 0.38196601125) % 1.0)
        out.append(hsl_to_hex(h, s, l))
    return out


def perceived_lightness(color: str) -> float:
    return relative_luminance(color) ** (1 / 2.2)


def distance(a: str, b: str) -> float:
    ar, ag, ab, _ = parse_hex(a)
    br, bg, bb, _ = parse_hex(b)
    return math.sqrt((ar - br) ** 2 + (ag - bg) ** 2 + (ab - bb) ** 2) / 441.67
