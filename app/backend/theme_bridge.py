"""QML-facing theme/tokens bridge and colour helpers."""

from __future__ import annotations

from typing import Any

from PySide6.QtCore import QObject, Property, Signal, Slot

from ..core import colors
from ..core.tokens import TokenResolver


class ThemeBridge(QObject):
    tokensChanged = Signal()
    themeChanged = Signal()

    def __init__(self, resolver: TokenResolver, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._resolver = resolver
        self._theme_id = "glass-celebration"
        self._overrides: dict[str, Any] = {}
        self._plugin_ids: list[str] = []
        self._high_contrast = False
        self._reduced_transparency = False
        self._tokens: dict[str, Any] = resolver.resolve(self._theme_id)

    def _read_tokens(self) -> dict[str, Any]:
        return self._tokens

    tokens = Property("QVariantMap", _read_tokens, notify=tokensChanged)

    @Property(str, notify=themeChanged)
    def themeId(self) -> str:
        return self._theme_id

    @Property(str, notify=tokensChanged)
    def style(self) -> str:
        return str(self._tokens.get("theme", {}).get("style", "glass"))

    @Property("QVariantMap", notify=tokensChanged)
    def palette(self) -> dict[str, Any]:
        return dict(self._tokens.get("color", {}).get("palette", {}))

    @Property("QVariantMap", notify=tokensChanged)
    def fonts(self) -> dict[str, Any]:
        return dict(self._tokens.get("type", {}).get("stack", {}))

    def _first_available(self, key: str) -> str:
        stack = self._tokens.get("type", {}).get("stack", {}).get(key, [])
        try:
            from PySide6.QtGui import QFontDatabase

            families = set(QFontDatabase.families())
            for name in stack:
                if name in families:
                    return name
        except Exception:
            pass
        return stack[0] if stack else "Microsoft YaHei UI"

    @Property(str, notify=tokensChanged)
    def hanFamily(self) -> str:
        return self._first_available("han")

    @Property(str, notify=tokensChanged)
    def serifFamily(self) -> str:
        return self._first_available("hanSerif")

    @Property(bool, notify=tokensChanged)
    def dark(self) -> bool:
        return self._tokens.get("ui", {}).get("mode", "dark") == "dark"

    @Slot(str, "QVariantMap", bool, bool, "QVariantList")
    def refresh(
        self,
        theme_id: str,
        overrides: dict[str, Any] | None = None,
        high_contrast: bool = False,
        reduced_transparency: bool = False,
        plugin_ids: list[str] | None = None,
    ) -> None:
        deltas = []
        if plugin_ids:
            deltas = self._plugin_deltas(plugin_ids)
        self._theme_id = theme_id or "glass-celebration"
        self._overrides = overrides or {}
        self._high_contrast = bool(high_contrast)
        self._reduced_transparency = bool(reduced_transparency)
        self._tokens = self._resolver.resolve(
            self._theme_id,
            deltas,
            self._overrides,
            high_contrast=self._high_contrast,
            reduced_transparency=self._reduced_transparency,
        )
        self.tokensChanged.emit()
        self.themeChanged.emit()

    def _plugin_deltas(self, ids: list[str]) -> list[dict[str, Any]]:
        provider = getattr(self, "plugin_provider", None)
        if provider is None:
            return []
        return provider(ids)

    @Slot(str, result=str)
    def fontFamily(self, key: str) -> str:
        return self._first_available(key)

    @Slot(result=str)
    def fontStack(self) -> str:
        stack = self._tokens.get("type", {}).get("stack", {}).get("han", [])
        return ", ".join(stack) if stack else "Microsoft YaHei UI"


class ColorTools(QObject):
    @Slot(str, str, result=float)
    def contrast(self, a: str, b: str) -> float:
        try:
            return colors.contrast_ratio(a, b)
        except ValueError:
            return 1.0

    @Slot(str, str, float, result=str)
    def blend(self, fg: str, bg: str, alpha: float) -> str:
        try:
            return colors.blend(fg, bg, alpha)
        except ValueError:
            return bg

    @Slot(float, result=str)
    def hueHex(self, hue: float) -> str:
        return colors.hsl_to_hex(hue, 0.6, 0.7)

    @Slot(float, str, float, float, float, float, int, result="QVariantList")
    def harmony(
        self,
        base_hue: float,
        mode: str,
        s0: float,
        s1: float,
        l0: float,
        l1: float,
        count: int,
    ) -> list[str]:
        return colors.harmony_palette(base_hue, mode, (s0, s1), (l0, l1), count)

    @Slot(float, str, int, "QVariantList", str, result="QVariantList")
    def swarmRamp(
        self,
        base_hue: float,
        mode: str,
        count: int,
        palette: list,
        accent: str,
    ) -> list[str]:
        """Candy-pastel colour ribbon for the note swarm."""
        pal = [str(c) for c in palette if c] if palette else []
        try:
            return colors.swarm_palette(base_hue, mode, count, pal, accent, 24)
        except (ValueError, TypeError):
            return colors.harmony_palette(base_hue, mode, (0.52, 0.68), (0.74, 0.84), count)

    @Slot(str, result=float)
    def luminance(self, color: str) -> float:
        try:
            return colors.relative_luminance(color)
        except ValueError:
            return 0.0
