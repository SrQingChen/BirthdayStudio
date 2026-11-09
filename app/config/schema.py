"""Pydantic contract shared by the show engine, the editor and the exporter.

The JSON file on disk (``profile.json``) is the single source of truth.
Everything the show renders must be describable by this schema; the editor
only writes through it, and the exporter validates against it.
"""

from __future__ import annotations

import re
from datetime import datetime, timezone
from typing import Any, ClassVar, Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

SCHEMA_VERSION = 1

_HEX_RE = re.compile(r"^#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$")
_ENTER_RE = re.compile(r"^(after-prev|on-tap|auto:\d+|user-advance)$")
_EXIT_RE = re.compile(r"^(after-prev|on-tap(?::[\w-]+)?|auto:\d+|auto:candles|user-advance)$")
_PATH_RE = re.compile(r"^assets/[\w./\-]+$")


def now_iso() -> str:
    return datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")


def _check_color(v: str) -> str:
    if v == "" or v is None:
        return ""
    if not _HEX_RE.match(v):
        raise ValueError(f"颜色必须为 #RRGGBB 或 #AARRGGBB：{v!r}")
    return v


class StrictModel(BaseModel):
    model_config = ConfigDict(
        extra="allow",
        populate_by_name=True,
        validate_assignment=True,
        str_strip_whitespace=False,
    )


# --------------------------------------------------------------------------- #
# Meta / assets
# --------------------------------------------------------------------------- #


class ProfileMeta(StrictModel):
    name: str = Field(default="未命名祝福", min_length=1, max_length=80)
    honoree: str = Field(default="你", min_length=1, max_length=40)
    author: str = Field(default="SrQingChen", max_length=80)
    theme: str = "glass-celebration"
    description: str = Field(default="", max_length=500)
    created_at: str = Field(default_factory=now_iso)
    modified_at: str = Field(default_factory=now_iso)
    cover: str = ""


class AssetRef(StrictModel):
    id: str
    kind: Literal["audio", "image", "video", "font", "other"] = "other"
    filename: str
    sha256: str = ""
    license: str = Field(default="unknown", max_length=80)
    source: str = Field(default="", max_length=300)


# --------------------------------------------------------------------------- #
# Global settings
# --------------------------------------------------------------------------- #


class BgmConfig(StrictModel):
    path: str = "audio/bgm_celebration.wav"
    volume_pct: int = Field(default=50, ge=0, le=100)
    loop: bool = True
    fade_in_ms: int = Field(default=600, ge=0, le=3000)
    fade_out_ms: int = Field(default=800, ge=0, le=3000)


class VoiceConfig(StrictModel):
    """Optional spoken blessing played when the wax seal breaks.

    Empty ``path`` means "no voice" and must never raise a validation error.
    The clip plays once (never loops) and the engine restores BGM ducking on
    EndOfMedia; see ``AudioEngine.play_voice``.
    """

    path: str = ""
    volume_pct: int = Field(default=85, ge=0, le=100)


class AudioConfig(StrictModel):
    master_volume_pct: int = Field(default=50, ge=0, le=100)
    bgm: BgmConfig = Field(default_factory=BgmConfig)
    sfx_volume_pct: int = Field(default=60, ge=0, le=100)
    ducking_enabled: bool = True
    voice: VoiceConfig = Field(default_factory=VoiceConfig)


class MotionConfig(StrictModel):
    reduced_motion: Literal["auto", "on", "off"] = "auto"
    speed_scale: float = Field(default=1.0, ge=0.25, le=2.0)


class EnvironmentConfig(StrictModel):
    mode: Literal["dark", "light", "auto"] = "dark"
    ambient_brightness: float = Field(default=1.0, ge=0.4, le=1.2)


class AccessibilityConfig(StrictModel):
    high_contrast: bool = False
    reduced_transparency: bool = False
    always_show_audio_bar: bool = True


class SkipConfig(StrictModel):
    enabled: bool = True
    show_button: bool = True


class StageConfig(StrictModel):
    aspect: Literal["16:9", "full"] = "16:9"
    background: Literal["theme", "custom"] = "theme"
    background_color: str = "#140c1a"
    vignette: bool = True

    _v_color = field_validator("background_color")(_check_color)


class GlobalConfig(StrictModel):
    audio: AudioConfig = Field(default_factory=AudioConfig)
    motion: MotionConfig = Field(default_factory=MotionConfig)
    environment: EnvironmentConfig = Field(default_factory=EnvironmentConfig)
    accessibility: AccessibilityConfig = Field(default_factory=AccessibilityConfig)
    skip: SkipConfig = Field(default_factory=SkipConfig)
    stage: StageConfig = Field(default_factory=StageConfig)


# --------------------------------------------------------------------------- #
# Acts
# --------------------------------------------------------------------------- #


class ActBase(StrictModel):
    enabled: bool = True
    enter: str = "after-prev"
    exit: str = "on-tap"
    skippable: bool = True

    @field_validator("enter")
    @classmethod
    def _enter_ok(cls, v: str) -> str:
        if not _ENTER_RE.match(v):
            raise ValueError("enter 需为 after-prev / on-tap / auto:<ms> / user-advance")
        return v

    @field_validator("exit")
    @classmethod
    def _exit_ok(cls, v: str) -> str:
        if not _EXIT_RE.match(v):
            raise ValueError("exit 需为 on-tap:<target> / auto:<ms> / after-prev / user-advance")
        return v


class EnvelopeConfig(StrictModel):
    paper_color: str = "#f3e7d6"
    flap_color: str = "#e8d8c3"
    seal_color: str = "#b3393f"
    seal_highlight: str = "#d9575c"
    ribbon_color: str = "#e9c46a"
    thread_color: str = "#7a2a2f"

    _v1 = field_validator("paper_color", "flap_color", "seal_color", "seal_highlight", "ribbon_color", "thread_color")(_check_color)


class IntroAct(ActBase):
    enter: str = "on-tap"
    exit: str = "on-tap:envelope"
    hint: str = "轻触信封，开启祝福"
    hint_color: str = ""
    hint_size: int = Field(default=22, ge=14, le=44)
    envelope: EnvelopeConfig = Field(default_factory=EnvelopeConfig)
    envelope_scale: float = Field(default=1.0, ge=0.6, le=1.4)
    # V1.1.0 fix #6 — opening gate: a dim screen with one button; the
    # envelope and wax seal only appear after the tap (act-1 "on-tap" entry,
    # audio-gesture best practice from the design doc, chapter 4).
    gate: bool = True
    gate_text: str = Field(default="开启这份祝福", max_length=16)
    gate_subtext: str = Field(default="一份心意，正在等你点开", max_length=30)

    _v = field_validator("hint_color")(_check_color)


class LetterConfig(StrictModel):
    paper_color: str = "#f8f0e1"
    ink_color: str = "#3a2e28"
    accent_color: str = "#b0563a"
    font_family: str = "hanSerif"
    font_size_px: int = Field(default=21, ge=12, le=36)
    line_height: float = Field(default=1.75, ge=1.2, le=2.2)
    text: str = (
        "亲爱的{honoree}：\n\n"
        "又到了这一天。\n"
        "愿你把今天的快乐存起来，\n"
        "在需要的时候慢慢取用。\n\n"
        "生日快乐！\n"
        "—— {author}"
    )
    signature: str = ""
    presentation: Literal["static", "typewriter", "lines"] = "typewriter"
    chars_per_second: float = Field(default=24, ge=6, le=60)
    line_stagger_ms: int = Field(default=450, ge=60, le=2000)
    advance: Literal["auto", "click"] = "click"

    _v1 = field_validator("paper_color", "ink_color", "accent_color")(_check_color)


class WaxAct(ActBase):
    letter_mode: Literal["none", "animated"] = "animated"
    letter: LetterConfig = Field(default_factory=LetterConfig)
    press_scale: float = Field(default=0.94, ge=0.88, le=0.99)
    crack_ms: int = Field(default=260, ge=100, le=800)


class TrajectoryConfig(StrictModel):
    preset: Literal["heart", "circle", "wave", "diagonal", "arc", "spiral", "custom"] = "heart"
    custom_points: list[list[float]] = Field(default_factory=list)
    duration_ms: int = Field(default=1600, ge=300, le=6000)
    easing: Literal["linear", "outCubic", "outBack", "inOutCubic"] = "outCubic"
    span: float = Field(default=0.72, ge=0.3, le=0.95)

    @field_validator("custom_points")
    @classmethod
    def _points_ok(cls, v: list[list[float]]) -> list[list[float]]:
        for p in v:
            if len(p) != 2 or not all(0.0 <= float(c) <= 1.0 for c in p):
                raise ValueError("custom_points 需为 0..1 的 [x, y] 数组")
        return v


class PopupSequenceConfig(StrictModel):
    stagger_ms: int = Field(default=60, ge=0, le=600)
    start_delay_ms: int = Field(default=260, ge=0, le=4000)
    total_duration_override_ms: int | None = Field(default=None, ge=100, le=12000)
    max_living: int = Field(default=7, ge=1, le=12)
    lifetime_ms: int = Field(default=8000, ge=1000, le=30000)
    fade_ms: int = Field(default=220, ge=80, le=1000)
    opacity_final: float = Field(default=0.0, ge=0.0, le=1.0)
    appear_from: Literal["letter", "trajectory", "center"] = "letter"
    size_vary_pct: int = Field(default=6, ge=0, le=30)
    hold_after_ms: int = Field(default=3800, ge=400, le=12000)
    float_amplitude: int = Field(default=6, ge=0, le=24)


class HarmonyConfig(StrictModel):
    mode: Literal["harmony", "palette", "single"] = "harmony"
    harmony: Literal["analogous", "triadic", "complementary"] = "analogous"
    base_hue: float = Field(default=14, ge=0, le=360)
    saturation_bucket: list[float] = Field(default_factory=lambda: [0.45, 0.70])
    lightness_bucket: list[float] = Field(default_factory=lambda: [0.62, 0.78])
    palette: list[str] = Field(default_factory=list)
    single_color: str = "#ffb08a"

    _v = field_validator("single_color")(_check_color)

    @field_validator("palette")
    @classmethod
    def _palette_ok(cls, v: list[str]) -> list[str]:
        for c in v:
            _check_color(c)
        return v

    @field_validator("saturation_bucket", "lightness_bucket")
    @classmethod
    def _bucket_ok(cls, v: list[float]) -> list[float]:
        if len(v) != 2 or not (0 <= v[0] <= v[1] <= 1):
            raise ValueError("色桶需为 [下限, 上限] 且 0..1")
        return v


class PopupCard(StrictModel):
    title: str = Field(default="想对你说", max_length=60)
    body: str = Field(default="愿你今天被所有温柔以待。", max_length=280)
    emoji: str = Field(default="✨", max_length=8)
    width: int = Field(default=400, ge=240, le=640)
    height: int = Field(default=236, ge=140, le=480)
    accent: str = ""
    style: Literal["", "glass", "cartoon"] = ""
    image: str = ""

    _v = field_validator("accent")(_check_color)


class SwarmConfig(StrictModel):
    """V1.1.0 fix #5 — the note swarm that traces the trajectory.

    Hundreds of small sticky notes appear in quick succession, overlapping
    ~90%, drawing the preset curve (heart / line / wave …) as one band
    before the readable cards fly in. The maxLivingPopups budget applies to
    readable glass cards only; the swarm is a trajectory-tracing effect on
    par with finale confetti (hard cap: count ≤ 400 static quads).
    """

    enabled: bool = True
    count: int = Field(default=320, ge=40, le=400)
    note_size: int = Field(default=44, ge=20, le=90)
    # V1.1.2 — one aspect ratio for EVERY note in the band, so the swarm never
    # mixes square/portrait/landscape chips. `note_size` is the width; the
    # height is derived from this ratio.
    note_aspect: Literal["1:1", "4:3", "3:4", "16:9"] = "1:1"
    overlap_pct: int = Field(default=90, ge=50, le=98)
    stagger_ms: int = Field(default=14, ge=4, le=60)
    fade_in_ms: int = Field(default=120, ge=40, le=600)
    jitter_px: int = Field(default=6, ge=0, le=30)
    cards_delay_after: bool = True
    # V1.1.1 — text on the notes: one entry per line, cycled along the curve
    text_block: str = Field(default="生日快乐\n愿你快乐\n岁岁平安\n心想事成", max_length=600)
    text_size: int = Field(default=11, ge=6, le=22)
    text_every: int = Field(default=6, ge=1, le=40)


class PopupsAct(ActBase):
    exit: str = "auto:1200"
    trajectory: TrajectoryConfig = Field(default_factory=TrajectoryConfig)
    sequence: PopupSequenceConfig = Field(default_factory=PopupSequenceConfig)
    color_strategy: HarmonyConfig = Field(default_factory=HarmonyConfig)
    swarm: SwarmConfig = Field(default_factory=SwarmConfig)
    style: Literal["glass", "cartoon"] = "glass"
    beat_sync: bool = False
    # V1.1.2 — the readable cards are an independent layer: they can be
    # switched off after the swarm, and capped to the first N cards without
    # deleting the rest of the list (0 = show every card).
    cards_enabled: bool = True
    cards_limit: int = Field(default=0, ge=0, le=24)
    # Auto-advance is independent of the card sequence: when False the act
    # waits for a tap (or the global skip button) before moving to confirm.
    # `sequence.hold_after_ms` is the dwell time when it is True.
    auto_advance: bool = True
    cards: list[PopupCard] = Field(
        default_factory=lambda: [
            PopupCard(title="第一次遇见", body="那天的风很轻，你笑得很亮。", emoji="🌤"),
            PopupCard(title="一起走过的日子", body="谢谢你把普通的日子，过成了值得收藏的片段。", emoji="🎞"),
            PopupCard(title="偷偷许的愿", body="愿你想要的都拥有，得不到的都释怀。", emoji="🌙"),
            PopupCard(title="关于未来", body="还有很多个生日，想陪你一起数。", emoji="🕯"),
            PopupCard(title="今天的你", body="请理直气壮地被爱、被祝福、被蛋糕包围。", emoji="🎂"),
        ]
    )

    @field_validator("cards")
    @classmethod
    def _cards_ok(cls, v: list[PopupCard]) -> list[PopupCard]:
        if not v:
            raise ValueError("至少需要一只弹窗")
        if len(v) > 24:
            raise ValueError("弹窗数量上限 24")
        return v


class ConfirmAct(ActBase):
    text: str = "收下祝福"
    subtext: str = "把我心里的话，轻轻放到你手上"
    style: Literal["glass", "cartoon"] = "glass"
    width: int = Field(default=560, ge=320, le=820)
    height: int = Field(default=280, ge=160, le=480)
    press_scale: float = Field(default=0.96, ge=0.90, le=0.99)


class DissolveAct(ActBase):
    exit: str = "auto:600"
    duration_ms: int = Field(default=560, ge=300, le=900)
    noise_scale: float = Field(default=26.0, ge=4.0, le=80.0)
    edge_glow: float = Field(default=0.35, ge=0.0, le=1.0)


class CameraConfig(StrictModel):
    pitch: float = Field(default=26, ge=-5, le=70)
    yaw: float = Field(default=-16, ge=-60, le=60)
    distance: float = Field(default=980, ge=780, le=1100)


class CakeLayerConfig(StrictModel):
    radius: float = Field(default=190, ge=40, le=320)
    height: float = Field(default=88, ge=20, le=200)
    color: str = "#f6d3c3"
    frosting: str = "#fff4ec"
    roughness: float = Field(default=0.62, ge=0.0, le=1.0)

    _v = field_validator("color", "frosting")(_check_color)


class CakeConfig(StrictModel):
    layers: list[CakeLayerConfig] = Field(
        default_factory=lambda: [
            CakeLayerConfig(radius=200, height=92, color="#f6d3c3"),
            CakeLayerConfig(radius=152, height=80, color="#f3b7a6"),
            CakeLayerConfig(radius=106, height=70, color="#ef9d8c"),
        ]
    )
    plate_color: str = "#e9e2d6"
    roughness: float = Field(default=0.55, ge=0.0, le=1.0)
    metalness: float = Field(default=0.02, ge=0.0, le=1.0)
    decorations: list[Literal["namePlague", "fruit", "piping", "sprinkles"]] = Field(
        default_factory=lambda: ["namePlague", "fruit", "piping", "sprinkles"]
    )

    _v = field_validator("plate_color")(_check_color)

    @field_validator("layers")
    @classmethod
    def _layers_ok(cls, v: list[CakeLayerConfig]) -> list[CakeLayerConfig]:
        if not 1 <= len(v) <= 5:
            raise ValueError("蛋糕层数需在 1..5")
        return v


class CandleConfig(StrictModel):
    count: int = Field(default=5, ge=1, le=12)
    arrangement: Literal["arc", "circle", "line"] = "arc"
    spacing: float = Field(default=36, ge=14, le=90)
    height: float = Field(default=54, ge=24, le=120)
    radius: float = Field(default=6, ge=2, le=14)
    colors: list[str] = Field(
        default_factory=lambda: ["#f2a7b8", "#f7c873", "#9ed0c4", "#b3a6e8", "#f09a7a"]
    )
    flame_intensity: float = Field(default=1.0, ge=0.3, le=2.0)
    mic_enabled: bool = False
    mic_threshold: float = Field(default=0.22, ge=0.02, le=0.95)

    @field_validator("colors")
    @classmethod
    def _colors_ok(cls, v: list[str]) -> list[str]:
        if not v:
            raise ValueError("至少一种蜡烛颜色")
        for c in v:
            _check_color(c)
        return v


class WishConfig(StrictModel):
    darken_ms: int = Field(default=520, ge=150, le=1500)
    silence_ms: int = Field(default=2400, ge=800, le=6000)
    reveal_text: str = "生日快乐"
    reveal_duration_ms: int = Field(default=900, ge=300, le=2500)


class JellyConfig(StrictModel):
    spring: float = Field(default=4.2, ge=1.0, le=6.0)
    damping: float = Field(default=0.42, ge=0.1, le=0.9)


class CakeAct(ActBase):
    exit: str = "auto:candles"
    camera: CameraConfig = Field(default_factory=CameraConfig)
    cake: CakeConfig = Field(default_factory=CakeConfig)
    candles: CandleConfig = Field(default_factory=CandleConfig)
    wish: WishConfig = Field(default_factory=WishConfig)
    jelly: JellyConfig = Field(default_factory=JellyConfig)
    hint: str = "点亮蜡烛后，逐根点击吹灭"
    interaction_hint: str = Field(default="拖动可旋转蛋糕 · 点击蛋糕会弹起来", max_length=40)


class ConfettiConfig(StrictModel):
    bursts: int = Field(default=3, ge=1, le=3)
    particles_per_burst: int = Field(default=110, ge=20, le=180)
    colors: list[str] = Field(
        default_factory=lambda: ["#ff8fab", "#ffd166", "#8ecae6", "#b8e0d2", "#cdb4db"]
    )
    gravity: float = Field(default=900, ge=100, le=2400)
    drag: float = Field(default=0.992, ge=0.95, le=0.999)
    origin_x: float = Field(default=0.5, ge=0.0, le=1.0)
    origin_y: float = Field(default=0.58, ge=0.0, le=1.0)
    spread: float = Field(default=68, ge=10, le=120)
    max_particles: int = Field(default=420, ge=60, le=900)

    @field_validator("colors")
    @classmethod
    def _colors_ok(cls, v: list[str]) -> list[str]:
        if not v:
            raise ValueError("至少一种彩带颜色")
        for c in v:
            _check_color(c)
        return v


class FinaleButtons(StrictModel):
    replay: str = "再看一次"
    close: str = "合上贺卡"


class FinaleAct(ActBase):
    exit: str = "user-advance"
    headline: str = "生日快乐"
    subline: str = "{honoree} · 今天的主角"
    confetti: ConfettiConfig = Field(default_factory=ConfettiConfig)
    buttons: FinaleButtons = Field(default_factory=FinaleButtons)


class ActsConfig(StrictModel):
    intro: IntroAct = Field(default_factory=IntroAct)
    wax: WaxAct = Field(default_factory=WaxAct)
    popups: PopupsAct = Field(default_factory=PopupsAct)
    confirm: ConfirmAct = Field(default_factory=ConfirmAct)
    dissolve: DissolveAct = Field(default_factory=DissolveAct)
    cake: CakeAct = Field(default_factory=CakeAct)
    finale: FinaleAct = Field(default_factory=FinaleAct)

    ORDER: ClassVar[list[str]] = ["intro", "wax", "popups", "confirm", "dissolve", "cake", "finale"]

    def enabled_order(self) -> list[str]:
        return [k for k in self.ORDER if getattr(self, k).enabled]


# --------------------------------------------------------------------------- #
# Profile
# --------------------------------------------------------------------------- #


class Profile(StrictModel):
    schema_version: int = SCHEMA_VERSION
    id: str = Field(min_length=4, max_length=80)
    meta: ProfileMeta = Field(default_factory=ProfileMeta)
    global_: GlobalConfig = Field(default_factory=GlobalConfig, alias="global")
    acts: ActsConfig = Field(default_factory=ActsConfig)
    assets: list[AssetRef] = Field(default_factory=list)
    token_overrides: dict[str, Any] = Field(default_factory=dict)
    plugins: list[str] = Field(default_factory=list)

    @model_validator(mode="after")
    def _keep_modified(self) -> "Profile":
        return self

    def dump(self) -> dict[str, Any]:
        return self.model_dump(by_alias=True, mode="json", exclude_none=False)

    def act_order(self) -> list[str]:
        return self.acts.enabled_order()

    def theme_id(self) -> str:
        return self.meta.theme

    def touch(self) -> None:
        self.meta.modified_at = now_iso()

    def referenced_assets(self) -> list[str]:
        """Every ``assets/...`` string anywhere in the profile."""
        found: list[str] = []

        def walk(node: Any) -> None:
            if isinstance(node, dict):
                for v in node.values():
                    walk(v)
            elif isinstance(node, list):
                for v in node:
                    walk(v)
            elif isinstance(node, str) and node.startswith("assets/"):
                found.append(node)

        walk(self.model_dump(by_alias=True, mode="json"))
        return sorted(set(found))


def replace_placeholders(text: str, profile: "Profile") -> str:
    return (
        text.replace("{honoree}", profile.meta.honoree)
        .replace("{author}", profile.meta.author)
        .replace("{name}", profile.meta.name)
    )
