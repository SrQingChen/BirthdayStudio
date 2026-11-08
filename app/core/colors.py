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
    else:  # analogous — a 80° span keeps the set warm and cohesive
        offsets = [0, 20, 40, -20, -40]
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


def _shortest_hue_delta(a: float, b: float) -> float:
    """Signed hue distance a→b in (−180, 180], so ramps take the short path."""
    return (b - a + 180.0) % 360.0 - 180.0


def _mirror_u(i: int, n: int) -> float:
    """0 at the middle of the run, 1 at both ends.

    The preset trajectories (heart / circle) start and end at the same point,
    so a mirrored ramp makes the left and right halves of the shape match and
    keeps the start/end colours identical.
    """
    if n <= 1:
        return 0.0
    return abs(2.0 * i / (n - 1) - 1.0)


def symmetric_hsl_ramp(
    anchors: list[tuple[float, float, float]], count: int
) -> list[str]:
    """Walk HSL anchors from the middle of the trajectory to both ends.

    The band mirrors around the shape's vertical axis: anchor 0 at the top
    centre, the last anchor where the two halves meet at the bottom.  Adjacent
    notes still differ by a fraction of a degree, so the band stays seamless,
    but a heart no longer reads as three unrelated colour blocks.
    """
    n = max(1, count)
    m = len(anchors)
    if m == 0:
        return ["#ffb08a"] * n
    if m == 1:
        h, s, l = anchors[0]
        return [hsl_to_hex(h, s, l)] * n
    out: list[str] = []
    for i in range(n):
        p = _mirror_u(i, n) * (m - 1)
        idx = min(int(math.floor(p)), m - 2)
        local = p - idx
        local = local * local * (3.0 - 2.0 * local)  # smoothstep
        a = anchors[idx]
        b = anchors[idx + 1]
        h = a[0] + _shortest_hue_delta(a[0], b[0]) * local
        s = a[1] + (b[1] - a[1]) * local
        l = a[2] + (b[2] - a[2]) * local
        out.append(hsl_to_hex(h, s, l))
    return out


def cyclic_hsl_ramp(
    anchors: list[tuple[float, float, float]], count: int
) -> list[str]:
    """Interpolate HSL anchors around a closed loop.

    Kept for callers that want the colour to keep travelling around the curve;
    the note swarm uses :func:`symmetric_hsl_ramp` so the two halves of a heart
    match instead.
    """
    n = max(1, count)
    m = len(anchors)
    if m == 0:
        return ["#ffb08a"] * n
    if m == 1:
        h, s, l = anchors[0]
        return [hsl_to_hex(h, s, l)] * n
    out: list[str] = []
    for i in range(n):
        p = (i / n) * m
        idx = int(math.floor(p))
        local = p - math.floor(p)
        local = local * local * (3.0 - 2.0 * local)  # smoothstep
        a = anchors[idx % m]
        b = anchors[(idx + 1) % m]
        h = a[0] + _shortest_hue_delta(a[0], b[0]) * local
        s = a[1] + (b[1] - a[1]) * local
        l = a[2] + (b[2] - a[2]) * local
        out.append(hsl_to_hex(h, s, l))
    return out


# --------------------------------------------------------------------------- #
# Candy ribbon — the note swarm's colour mechanism
# --------------------------------------------------------------------------- #
# Colour preference is unusually consistent across cultures: blues/cyans and
# pinks/reds rank at the top, while browns, olives and dark yellows rank at the
# bottom (Hurlbert & Ling 2007; Palmer & Schloss 2010, PNAS).  "Soft / cute"
# reads in the PCCS pale-light tones — high lightness with moderate-to-lively
# chroma — and Ou & Luo's (2006) harmony model likewise favours high lightness
# and small hue/lightness/chroma steps between neighbours.  The swarm therefore
# walks a curated set of candy hue anchors inside a fixed pale tone band:
# nothing can land in the brown (dark orange) or grey (low-chroma) corner that
# made the old base-hue ramp look muddy.
#
# Hues are ordered from the middle of the curve (top centre) to both ends, so
# the mirrored ramp reads as one continuous family instead of split blocks.
_CANDY_FAMILIES: dict[str, list[tuple[float, float, float]]] = {
    "warm": [  # rose -> powder blue, used for warm/pink base hues
        (345.0, 0.86, 0.855),
        (322.0, 0.80, 0.845),
        (292.0, 0.78, 0.835),
        (252.0, 0.80, 0.825),
        (203.0, 0.80, 0.835),
    ],
    "spring": [  # mint -> rose
        (162.0, 0.62, 0.845),
        (186.0, 0.66, 0.840),
        (204.0, 0.76, 0.835),
        (238.0, 0.78, 0.830),
        (288.0, 0.76, 0.835),
        (345.0, 0.84, 0.850),
    ],
    "sky": [  # powder blue -> rose
        (203.0, 0.80, 0.840),
        (226.0, 0.76, 0.835),
        (252.0, 0.78, 0.830),
        (288.0, 0.78, 0.835),
        (322.0, 0.82, 0.845),
        (345.0, 0.84, 0.855),
    ],
    "violet": [  # lilac -> rose -> powder blue
        (290.0, 0.78, 0.840),
        (316.0, 0.78, 0.840),
        (340.0, 0.80, 0.845),
        (356.0, 0.82, 0.850),
        (203.0, 0.80, 0.835),
    ],
}

# Wider party ribbons for the triadic / complementary modes; still restricted
# to candy hues, so "wider" never means harsher.
_CANDY_PARTY: dict[str, list[tuple[float, float, float]]] = {
    "triadic": [
        (345.0, 0.86, 0.855),
        (24.0, 0.82, 0.850),
        (48.0, 0.76, 0.850),
        (168.0, 0.62, 0.840),
        (203.0, 0.80, 0.835),
        (252.0, 0.80, 0.835),
    ],
    "complementary": [
        (345.0, 0.86, 0.855),
        (203.0, 0.80, 0.840),
        (305.0, 0.78, 0.840),
        (168.0, 0.62, 0.840),
        (24.0, 0.82, 0.850),
    ],
}


def _candy_family(base_hue: float) -> str:
    """Pick the ribbon family whose lead hue best matches the theme."""
    h = base_hue % 360.0
    if 75.0 <= h < 165.0:
        return "spring"
    if 165.0 <= h < 255.0:
        return "sky"
    if 255.0 <= h < 315.0:
        return "violet"
    return "warm"


def _revive_pastel(color: str) -> tuple[float, float, float]:
    """Pull an explicit palette colour back into the pale candy band.

    Hue is preserved (the author's intent), but a low-lightness brown is lifted
    and a nearly grey colour is either kept as a deliberate neutral or given a
    chroma floor.  This is what stops a hand-authored dark palette from turning
    the band muddy.
    """
    h, s, l = hex_to_hsl(color)
    if s < 0.12:
        return (h, s, max(l, 0.79))
    return (h, max(0.44, min(0.72, s)), max(0.73, min(0.88, l)))


def swarm_palette(
    base_hue: float,
    mode: str = "analogous",
    count: int = 320,
    palette: list[str] | None = None,
    accent: str = "",
    accent_every: int = 16,
) -> list[str]:
    """Candy-pastel colour band for the note swarm.

    The ribbon is mirrored around the trajectory's vertical axis, so the two
    halves of a heart share the same colours.  ``base_hue`` selects the family
    (warm / spring / sky / violet) and therefore the lead hue; ``harmony``
    selects the span (analogous = one family, triadic = six-hue party ribbon,
    complementary = pink/blue alternation).  Every hue lives in a fixed
    high-lightness, mid-chroma band, so adjacent notes can shimmer without ever
    reading as brown, olive or grey.

    ``palette`` (2+ hex colours) overrides the anchors, but each colour is
    revived into the same pale band.  A single colour is honoured verbatim: it
    is an explicit monochrome choice.  ``accent`` (the theme's tertiary colour)
    is dropped in at most every ``accent_every`` notes — the 60/30/10 accent
    share, not a competing field — and is revived as well.
    """
    n = max(1, count)
    pal: list[str] = []
    for color in palette or []:
        try:
            parse_hex(color)
            pal.append(color)
        except ValueError:
            continue
    if len(pal) == 1:
        return [pal[0]] * n
    if len(pal) >= 2:
        anchors = [_revive_pastel(color) for color in pal]
    elif mode in _CANDY_PARTY:
        anchors = _CANDY_PARTY[mode]
    else:
        anchors = _CANDY_FAMILIES[_candy_family(base_hue)]
    out = symmetric_hsl_ramp(anchors, n)
    if accent and accent_every > 0:
        try:
            h, s, l = hex_to_hsl(accent)
            if s >= 0.12:
                accent = hsl_to_hex(h, max(0.44, min(0.72, s)),
                                    max(0.75, min(0.90, l)))
            else:
                accent = hsl_to_hex(h, s, max(l, 0.83))
            step = max(2, accent_every)
            for i in range(step // 2, n, step):
                out[i] = accent
        except ValueError:
            pass
    return out


def perceived_lightness(color: str) -> float:
    return relative_luminance(color) ** (1 / 2.2)


def distance(a: str, b: str) -> float:
    ar, ag, ab, _ = parse_hex(a)
    br, bg, bb, _ = parse_hex(b)
    return math.sqrt((ar - br) ** 2 + (ag - bg) ** 2 + (ab - bb) ** 2) / 441.67
