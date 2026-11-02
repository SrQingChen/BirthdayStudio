"""Services used by the show stage: asset URLs, audio transport, mic, slot components."""

from __future__ import annotations

import hashlib
from pathlib import Path
from typing import Any

from PySide6.QtCore import QObject, Property, Signal, Slot

from ..core.audio import AudioEngine
from ..core.paths import BUILTIN_AUDIO_DIR, BUILTIN_TEXTURE_DIR, HOME_DIR, RESOURCES_DIR
from ..core.plugin_manager import PluginManager
from .mic import MicMonitor


class ShowBridge(QObject):
    quitRequested = Signal()
    replayRequested = Signal()
    toast = Signal(str)
    micChanged = Signal()
    pluginIdsChanged = Signal()
    pluginRevisionChanged = Signal()
    profileDirChanged = Signal()

    def __init__(self, audio: AudioEngine, plugins: PluginManager, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self.audio = audio
        self.plugins = plugins
        self._profile_dir = ""
        self._plugin_ids: list[str] = []
        self._plugin_revision = 0
        self.mic = MicMonitor(self)
        self.mic.levelChanged.connect(lambda _v: self.micChanged.emit())
        self.mic.availabilityChanged.connect(lambda _a, _m: self.micChanged.emit())

    # ------------------------------------------------------------------ #
    @Property(str, notify=profileDirChanged)
    def profileDir(self) -> str:
        return self._profile_dir

    @Slot(str)
    def setProfileDir(self, path: str) -> None:
        self._profile_dir = path
        self.profileDirChanged.emit()

    @Slot("QVariantList")
    def setPluginIds(self, ids: list[Any]) -> None:
        new_ids = [str(i) for i in ids]
        if new_ids == self._plugin_ids:
            return
        self._plugin_ids = new_ids
        self._plugin_revision += 1
        self.pluginIdsChanged.emit()
        self.pluginRevisionChanged.emit()

    @Property(int, notify=pluginRevisionChanged)
    def pluginRevision(self) -> int:
        return self._plugin_revision

    @Property("QVariantList", notify=pluginIdsChanged)
    def pluginIds(self) -> list[str]:
        return self._plugin_ids

    @Slot(str, result=str)
    def assetUrl(self, path: str) -> str:
        if not path:
            return ""
        p = Path(path)
        if p.is_absolute():
            return p.as_uri() if p.exists() else ""
        if path.startswith("assets/") and self._profile_dir:
            candidate = Path(self._profile_dir) / path
            return candidate.as_uri() if candidate.exists() else ""
        for root in (RESOURCES_DIR, BUILTIN_AUDIO_DIR, BUILTIN_TEXTURE_DIR):
            candidate = root / path
            if candidate.exists():
                return candidate.as_uri()
        candidate = BUILTIN_AUDIO_DIR / Path(path).name
        if candidate.exists():
            return candidate.as_uri()
        candidate = BUILTIN_TEXTURE_DIR / Path(path).name
        return candidate.as_uri() if candidate.exists() else ""

    @Slot(str, result=str)
    def textureUrl(self, name: str) -> str:
        candidate = BUILTIN_TEXTURE_DIR / name
        return candidate.as_uri() if candidate.exists() else ""

    @Slot(str, float)
    def playSfx(self, kind: str, scale: float = 1.0) -> None:
        self.audio.play_sfx(kind, scale, self._profile_dir)

    @Slot(str, int, float)
    def playSfxAfter(self, kind: str, delay_ms: int, scale: float = 1.0) -> None:
        self.audio.play_sfx_after(kind, delay_ms, scale, self._profile_dir)

    @Slot(str, bool, int, int)
    def playBgm(self, path: str, loop: bool, volume_pct: int, fade_ms: int) -> None:
        self.audio.play_bgm(path, loop, volume_pct, fade_ms, self._profile_dir)

    @Slot(str, bool, int, int)
    def crossfadeBgm(self, path: str, loop: bool, volume_pct: int, fade_ms: int) -> None:
        self.audio.crossfade_to(path, loop, volume_pct, fade_ms, self._profile_dir)

    @Slot(int)
    def stopBgm(self, fade_ms: int = 700) -> None:
        self.audio.stop_bgm(fade_ms)

    @Slot(bool)
    def duck(self, active: bool) -> None:
        self.audio.set_ducked(active)

    @Slot(int)
    def setMasterVolume(self, pct: int) -> None:
        self.audio.set_master_volume(pct)

    @Slot(int)
    def setSfxVolume(self, pct: int) -> None:
        self.audio.set_sfx_volume(pct)

    @Slot(bool)
    def setDucking(self, enabled: bool) -> None:
        self.audio.set_ducking_enabled(enabled)

    # ------------------------------------------------------------------ #
    @Property(float, notify=micChanged)
    def micLevel(self) -> float:
        return self.mic.level

    @Property(bool, notify=micChanged)
    def micAvailable(self) -> bool:
        return self.mic.available

    @Property(str, notify=micChanged)
    def micMessage(self) -> str:
        return self.mic.message

    @Slot()
    def micStart(self) -> None:
        self.mic.start()

    @Slot()
    def micStop(self) -> None:
        self.mic.stop()

    # ------------------------------------------------------------------ #
    @Slot(str, result=str)
    def slotComponent(self, slot: str) -> str:
        return self.plugins.slot_component(slot, self._plugin_ids or None)

    @Slot()
    def quitShow(self) -> None:
        self.quitRequested.emit()

    @Slot()
    def replayShow(self) -> None:
        self.replayRequested.emit()

    @Slot(str)
    def openExternal(self, url: str) -> None:
        from PySide6.QtCore import QUrl
        from PySide6.QtGui import QDesktopServices

        QDesktopServices.openUrl(QUrl(url))

    # ------------------------------------------------------------------ #
    @Slot(str, str, result=str)
    def plaqueUrl(self, text: str, subtitle: str = "") -> str:
        """Render a small cake plaque texture on demand (cached)."""
        from PySide6.QtCore import Qt
        from PySide6.QtGui import QColor, QFont, QImage, QLinearGradient, QPainter

        key = hashlib.sha1(f"v2|{text}|{subtitle}".encode("utf-8")).hexdigest()[:12]
        cache = HOME_DIR / "cache"
        cache.mkdir(parents=True, exist_ok=True)
        path = cache / f"plaque_{key}.png"
        if path.exists():
            return path.as_uri()
        w, h = 640, 180
        img = QImage(w, h, QImage.Format_ARGB32)
        img.fill(QColor(0, 0, 0, 0))
        painter = QPainter(img)
        painter.setRenderHint(QPainter.Antialiasing, True)
        painter.setRenderHint(QPainter.TextAntialiasing, True)
        grad = QLinearGradient(0, 0, 0, h)
        grad.setColorAt(0.0, QColor("#fff6e8"))
        grad.setColorAt(1.0, QColor("#f0ddc2"))
        painter.setBrush(grad)
        painter.setPen(QColor("#8c4a3a"))
        painter.drawRoundedRect(14, 14, w - 28, h - 28, 36, 36)
        painter.setPen(QColor("#8c4a3a"))
        from PySide6.QtGui import QFontDatabase

        families = set(QFontDatabase.families())
        family = next(
            (f for f in ("Noto Sans SC", "Source Han Sans SC", "Microsoft YaHei UI", "Microsoft YaHei", "SimHei") if f in families),
            "Sans Serif",
        )
        font = QFont(family, 54)
        font.setWeight(QFont.DemiBold)
        painter.setFont(font)
        painter.drawText(0, 20, w, h - 40, Qt.AlignCenter, text)
        painter.end()
        img.save(str(path), "PNG")
        return path.as_uri()
