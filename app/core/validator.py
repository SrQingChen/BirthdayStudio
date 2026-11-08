"""Configuration validation + the three health red lines, linted at edit time.

Severity contract:
    error   -> blocks export (schema violation, WCAG contrast failure, missing asset)
    warning -> export allowed, but the creator should look
    info    -> advice only
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from pydantic import ValidationError

from ..config.schema import Profile, replace_placeholders
from . import colors
from .paths import BUILTIN_AUDIO_DIR, BUILTIN_TEXTURE_DIR, FONTS_DIR


@dataclass
class Issue:
    severity: str
    path: str
    message: str
    code: str = ""
    act: str = ""

    def as_dict(self) -> dict[str, str]:
        return {
            "severity": self.severity,
            "path": self.path,
            "message": self.message,
            "code": self.code,
            "act": self.act,
        }


@dataclass
class ValidationReport:
    profile: Profile | None = None
    issues: list[Issue] = field(default_factory=list)

    @property
    def errors(self) -> list[Issue]:
        return [i for i in self.issues if i.severity == "error"]

    @property
    def warnings(self) -> list[Issue]:
        return [i for i in self.issues if i.severity == "warning"]

    @property
    def ok(self) -> bool:
        return not self.errors

    def as_dicts(self) -> list[dict[str, str]]:
        return [i.as_dict() for i in self.issues]


def _path_of(loc: tuple[Any, ...]) -> str:
    out: list[str] = []
    for part in loc:
        if isinstance(part, int):
            if out:
                out[-1] = f"{out[-1]}[{part}]"
            else:
                out.append(f"[{part}]")
        else:
            out.append(str(part))
    return ".".join(out).replace("global.", "global.")


def parse_profile(data: dict[str, Any]) -> tuple[Profile | None, list[Issue]]:
    try:
        return Profile.model_validate(data), []
    except ValidationError as exc:
        issues: list[Issue] = []
        for err in exc.errors():
            loc = tuple(err.get("loc", ()))
            path = _path_of(loc)
            act = path.split(".")[1] if path.startswith("acts.") and len(path.split(".")) > 1 else ""
            issues.append(
                Issue(
                    severity="error",
                    path=path,
                    message=_friendly(err.get("msg", "无效值")),
                    code=err.get("type", "schema"),
                    act=act,
                )
            )
        return None, issues


def _friendly(msg: str) -> str:
    return (
        msg.replace("Input should be a valid integer", "应为整数")
        .replace("Input should be a valid number", "应为数字")
        .replace("Input should be a valid boolean", "应为布尔值")
        .replace("Input should be a valid string", "应为文本")
        .replace("Input should be greater than or equal to", "不得小于")
        .replace("Input should be less than or equal to", "不得大于")
        .replace("String should have at least", "长度至少为")
        .replace("String should have at most", "长度至多为")
        .replace("Value error, ", "")
        .replace("Field required", "缺少必填字段")
    )


def resolve_asset(path: str, profile_dir: Path | None) -> Path | None:
    """Resolve a config asset path to a real file, or None if missing."""
    if not path:
        return None
    p = Path(path)
    if p.is_absolute():
        return p if p.exists() else None
    if path.startswith("assets/") and profile_dir:
        candidate = profile_dir / path
        return candidate if candidate.exists() else None
    for root in (BUILTIN_AUDIO_DIR.parent, BUILTIN_AUDIO_DIR, BUILTIN_TEXTURE_DIR, FONTS_DIR):
        candidate = root / path
        if candidate.exists():
            return candidate
    return None


def validate_profile(
    data: dict[str, Any],
    *,
    profile_dir: Path | None = None,
    tokens: dict[str, Any] | None = None,
    available_themes: set[str] | None = None,
) -> ValidationReport:
    profile, issues = parse_profile(data)
    report = ValidationReport(profile=profile, issues=issues)
    if profile is None:
        return report

    palette = (tokens or {}).get("color", {}).get("palette", {})

    # ---- schema-adjacent integrity checks ---------------------------------- #
    if available_themes and profile.meta.theme not in available_themes:
        report.issues.append(
            Issue("error", "meta.theme", f"主题 {profile.meta.theme!r} 未安装或已损坏。", "theme.missing")
        )
    if not profile.acts.enabled_order():
        report.issues.append(Issue("error", "acts", "七幕全部关闭，演出没有任何内容。", "acts.all_disabled"))

    # ---- contrast ---------------------------------------------------------- #
    if palette:
        for role, on_role in (
            ("surface", "on-surface"),
            ("primary", "on-primary"),
            ("primary-container", "on-primary-container"),
        ):
            fg, bg = palette.get(on_role), palette.get(role)
            if fg and bg:
                ratio = colors.contrast_ratio(fg, bg)
                if ratio < 4.5:
                    report.issues.append(
                        Issue(
                            "error",
                            f"tokens.color.palette.{role}",
                            f"角色 {on_role} / {role} 对比度 {ratio:.1f}:1，低于 WCAG AA 4.5:1。",
                            "contrast",
                        )
                    )

    letter = profile.acts.wax.letter
    if profile.acts.wax.enabled and profile.acts.wax.letter_mode != "none":
        ratio = colors.contrast_ratio(letter.ink_color, letter.paper_color)
        if ratio < 4.5:
            report.issues.append(
                Issue(
                    "error",
                    "acts.wax.letter.ink_color",
                    f"信纸文字对比度 {ratio:.1f}:1，低于 4.5:1，请加深墨色或加亮纸张。",
                    "contrast",
                    "wax",
                )
            )
        if len(replace_placeholders(letter.text, profile)) > 900:
            report.issues.append(
                Issue(
                    "warning",
                    "acts.wax.letter.text",
                    "信件超过 900 字，阅读时长会超过 3 分钟，建议拆短。",
                    "letter.length",
                    "wax",
                )
            )

    # Popup card contrast: text sits on a tinted glass surface.
    popups = profile.acts.popups
    # Only cards that actually reach the stage are audited: the card layer can
    # be switched off and `cards_limit` caps the visible prefix of the list.
    visible_cards = popups.cards if popups.cards_enabled else []
    if popups.cards_limit > 0:
        visible_cards = visible_cards[: popups.cards_limit]
    if popups.enabled and not visible_cards and not popups.swarm.enabled:
        report.issues.append(
            Issue(
                "warning",
                "acts.popups",
                "祝福幕没有可显示内容（卡片与蜂群都已关闭），播放时会被直接跳过。",
                "content",
                "popups",
            )
        )
    if popups.enabled and palette:
        on_surface = palette.get("on-surface", "#ffffff")
        surface = palette.get("surface", "#1b1220")
        card_alpha = (tokens or {}).get("glass", {}).get("cardTintAlpha", 0.16)
        for idx, card in enumerate(visible_cards):
            base = card.accent or palette.get("primary", "#ffb08a")
            card_bg = colors.blend(base, surface, min(0.55, card_alpha + 0.16))
            ratio = colors.contrast_ratio(on_surface, card_bg)
            if ratio < 4.5:
                report.issues.append(
                    Issue(
                        "warning",
                        f"acts.popups.cards[{idx}].accent",
                        f"第 {idx + 1} 只弹窗的强调色会让正文对比降到 {ratio:.1f}:1，建议换更浅/更深的强调色。",
                        "contrast",
                        "popups",
                    )
                )
            # Rough overflow estimate: CJK glyphs are ~1em square.
            body = replace_placeholders(card.body, profile)
            usable_w = max(60, card.width - 48)
            usable_h = max(40, card.height - 84)
            line_len = max(1, int(usable_w / 16))
            lines = sum(max(1, (len(seg) + line_len - 1) // line_len) for seg in body.split("\n"))
            if lines * 16 * 1.6 > usable_h:
                report.issues.append(
                    Issue(
                        "warning",
                        f"acts.popups.cards[{idx}].body",
                        f"第 {idx + 1} 只弹窗正文可能溢出（约 {lines} 行），建议加大尺寸或缩短文字。",
                        "popup.overflow",
                        "popups",
                    )
                )

    # ---- audio ------------------------------------------------------------- #
    audio = profile.global_.audio
    if audio.master_volume_pct > 50:
        report.issues.append(
            Issue(
                "warning",
                "global.audio.master_volume_pct",
                "主音量高于 50%，不符合默认音量红线（WHO 安全聆听 / WCAG 1.4.2 最佳实践）。",
                "audio.volume",
            )
        )
    if audio.bgm.volume_pct > 50:
        report.issues.append(
            Issue(
                "warning",
                "global.audio.bgm.volume_pct",
                "BGM 音量高于 50%，建议降低。",
                "audio.volume",
            )
        )
    if audio.bgm.path and resolve_asset(audio.bgm.path, profile_dir) is None:
        report.issues.append(
            Issue("error", "global.audio.bgm.path", f"背景音乐文件不存在：{audio.bgm.path}", "asset.missing")
        )

    # ---- assets ------------------------------------------------------------ #
    for asset in profile.assets:
        if not (profile_dir and (profile_dir / "assets" / asset.filename).exists()):
            report.issues.append(
                Issue("error", f"assets.{asset.id}", f"资源缺失：{asset.filename}", "asset.missing")
            )
    for path in profile.referenced_assets():
        if resolve_asset(path, profile_dir) is None:
            report.issues.append(Issue("error", "assets", f"引用的资源不存在：{path}", "asset.missing"))
    for idx, card in enumerate(visible_cards):
        if card.image and resolve_asset(card.image, profile_dir) is None:
            report.issues.append(
                Issue(
                    "error",
                    f"acts.popups.cards[{idx}].image",
                    f"弹窗图片不存在：{card.image}",
                    "asset.missing",
                    "popups",
                )
            )

    # ---- motion / photosensitivity ---------------------------------------- #
    if profile.global_.motion.reduced_motion == "off" and profile.acts.finale.enabled:
        report.issues.append(
            Issue(
                "info",
                "global.motion.reduced_motion",
                "低动效模式已关闭；播放器启动时仍会检测系统“减弱动态效果”设置。",
                "motion",
            )
        )
    confetti = profile.acts.finale.confetti
    if confetti.bursts > 3:
        report.issues.append(Issue("error", "acts.finale.confetti.bursts", "彩带爆发不得超过 3 次。", "flash", "finale"))

    # ---- targets ----------------------------------------------------------- #
    if profile.acts.confirm.width < 44 or profile.acts.confirm.height < 44:
        report.issues.append(
            Issue("error", "acts.confirm", "确认按钮小于 44×44px 主目标尺寸。", "target", "confirm")
        )
    for idx, card in enumerate(visible_cards):
        if card.width < 24 or card.height < 24:
            report.issues.append(
                Issue("error", f"acts.popups.cards[{idx}]", "弹窗尺寸小于 24×24px。", "target", "popups")
            )

    # ---- timing sanity ----------------------------------------------------- #
    seq = popups.sequence
    swarm = popups.swarm
    # NOTE: the QML runtime raises the stagger to >=30ms under reduced motion,
    # roughly doubling the swarm time; the lint reports the configured value.
    swarm_ms = swarm.count * swarm.stagger_ms + swarm.fade_in_ms if swarm.enabled else 0
    cards_delay_ms = swarm_ms if (swarm.enabled and swarm.cards_delay_after) else 0
    total_ms = seq.start_delay_ms + cards_delay_ms + max(0, len(visible_cards) - 1) * seq.stagger_ms
    if total_ms > 12000:
        report.issues.append(
            Issue(
                "warning",
                "acts.popups.sequence",
                f"弹窗序列总入场时长约 {total_ms / 1000:.1f}s，超过 10s 注意力窗口，建议缩短间隔。",
                "timing",
                "popups",
            )
        )
    if visible_cards and seq.max_living > 7:
        report.issues.append(
            Issue(
                "warning",
                "acts.popups.sequence.max_living",
                "同屏存活弹窗超过 7 只，超出工作记忆舒适区（Cowan 4±1 / Miller 7±2）。",
                "density",
                "popups",
            )
        )

    return report
