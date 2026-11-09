"""Application shell: mode, player bootstrap, settings, crash plan, lifecycle."""

from __future__ import annotations

import json
import os
import tempfile
import zipfile
from pathlib import Path
from typing import Any

from PySide6.QtCore import QObject, Property, QUrl, Signal, Slot

from ..config.defaults import list_themes
from ..config.schema import Profile
from ..core.audio import AudioEngine
from ..core.paths import HOME_DIR, PLUGINS_DIR, PROJECT_ROOT
from ..core.plugin_manager import PluginManager
from ..core.profile_store import ProfileStore
from ..core.settings import Settings
from ..core.tokens import TokenResolver
from .bridges import LibraryBridge
from .session_bridge import SessionBridge
from .show_bridge import ShowBridge
from .theme_bridge import ThemeBridge

APP_VERSION = "1.1.3"


class AppBridge(QObject):
    modeChanged = Signal()
    playerChanged = Signal()
    crashPlanChanged = Signal()
    settingsChanged = Signal()
    toast = Signal(str)
    requestClose = Signal()

    def __init__(
        self,
        *,
        mode: str,
        play_arg: str,
        store: ProfileStore,
        settings: Settings,
        theme: ThemeBridge,
        session: SessionBridge,
        library: LibraryBridge,
        show: ShowBridge,
        audio: AudioEngine,
        plugins: PluginManager,
        windowed: bool = False,
        dev_dialog: str = "",
        dev_autoplay: bool = False,
        parent: QObject | None = None,
    ) -> None:
        super().__init__(parent)
        self._mode = "player" if mode == "player" else "editor"
        self.play_arg = play_arg
        self.store = store
        self.settings = settings
        self.theme = theme
        self.session = session
        self.library = library
        self.show = show
        self.audio = audio
        self.plugins = plugins
        self._windowed = bool(windowed)
        self._dev_dialog = dev_dialog
        self._dev_autoplay = bool(dev_autoplay)
        self._force2d = os.environ.get("BIRTHDAY_STUDIO_FORCE_2D", "") == "1"
        self._player_profile: dict[str, Any] = {}
        self._player_dir = ""
        self._player_error = ""
        self._crash_candidates: list[dict[str, Any]] = []

        if mode == "player":
            self._load_player(play_arg)
        else:
            self._crash_candidates = store.unclean_profiles()

    # ------------------------------------------------------------------ #
    @Property(str, constant=True)
    def mode(self) -> str:
        return self._mode

    @Property(bool, notify=modeChanged)
    def isPlayer(self) -> bool:
        return self._mode == "player"

    @Property(str, constant=True)
    def version(self) -> str:
        return APP_VERSION

    @Property(str, constant=True)
    def homeDir(self) -> str:
        return str(HOME_DIR)

    @Property(str, constant=True)
    def projectRoot(self) -> str:
        return str(PROJECT_ROOT)

    @Property("QVariantMap", notify=playerChanged)
    def playerProfile(self) -> dict[str, Any]:
        return self._player_profile

    @Property(str, notify=playerChanged)
    def playerProfileDir(self) -> str:
        return self._player_dir

    @Property(str, notify=playerChanged)
    def playerError(self) -> str:
        return self._player_error

    @Property(bool, notify=playerChanged)
    def playerReady(self) -> bool:
        return bool(self._player_profile) and not self._player_error

    @Property("QVariantList", notify=crashPlanChanged)
    def crashCandidates(self) -> list[dict[str, Any]]:
        return self._crash_candidates

    def _get_editor_mode(self) -> str:
        return str(self.settings.get("editor_mode", "wizard"))

    def _set_editor_mode(self, value: str) -> None:
        self.settings.set("editor_mode", "expert" if value == "expert" else "wizard")
        self.settings.save()
        self.settingsChanged.emit()

    editorMode = Property(str, _get_editor_mode, _set_editor_mode, notify=settingsChanged)

    def _get_startup_restore(self) -> bool:
        return bool(self.settings.get("startup_restore", True))

    def _set_startup_restore(self, value: bool) -> None:
        self.settings.set("startup_restore", bool(value))
        self.settings.save()
        self.settingsChanged.emit()

    startupRestore = Property(bool, _get_startup_restore, _set_startup_restore, notify=settingsChanged)

    @Property(str, notify=settingsChanged)
    def lastProfileId(self) -> str:
        return str(self.settings.get("last_profile_id", ""))

    @Property("QVariantMap", notify=settingsChanged)
    def windowGeometry(self) -> dict[str, Any]:
        return self.settings.get("window", {})

    @Property("QVariantMap", notify=settingsChanged)
    def layout(self) -> dict[str, Any]:
        return self.settings.get("layout", {})

    @Property("QVariantMap", notify=settingsChanged)
    def previewSettings(self) -> dict[str, Any]:
        return self.settings.get("preview", {})

    @Property(str, notify=settingsChanged)
    def lastExportDir(self) -> str:
        return str(self.settings.get("last_export_dir", ""))

    @Property("QVariantMap", notify=crashPlanChanged)
    def startupPlan(self) -> dict[str, Any]:
        if self._crash_candidates:
            return {"action": "recovery", "candidates": self._crash_candidates}
        last = self.lastProfileId
        if last and self.store.exists(last) and self.startupRestore:
            return {"action": "open", "profileId": last}
        return {"action": "wizard"}

    @Property("QVariantList", notify=settingsChanged)
    def themes(self) -> list[dict[str, Any]]:
        return list_themes()

    @Property(bool, constant=True)
    def systemReducedMotion(self) -> bool:
        """Approximate the Windows "animation effects" preference.

        Qt exposes no cross-platform reduced-motion API; VisualFXSetting=2
        (best performance) disables animations in Windows itself and is a
        strong signal.  The profile switch always wins in the show engine.
        """
        try:
            from PySide6.QtCore import QSettings

            s = QSettings(
                r"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects",
                QSettings.NativeFormat,
            )
            value = s.value("VisualFXSetting")
            if str(value) == "2":
                return True
            s2 = QSettings(
                r"HKEY_CURRENT_USER\Control Panel\Desktop",
                QSettings.NativeFormat,
            )
            return str(s2.value("MinAnimate", "1")) == "0"
        except Exception:
            return False

    @Property(bool, constant=True)
    def windowedPlayer(self) -> bool:
        return bool(getattr(self, "_windowed", False))

    @Property(str, constant=True)
    def devDialog(self) -> str:
        return self._dev_dialog

    @Property(bool, constant=True)
    def devAutoplay(self) -> bool:
        return self._dev_autoplay

    @Property(bool, constant=True)
    def force2d(self) -> bool:
        return self._force2d

    # ------------------------------------------------------------------ #
    # Player bootstrap
    # ------------------------------------------------------------------ #
    def _load_player(self, arg: str) -> None:
        try:
            directory, profile = self._resolve_player_profile(arg)
        except Exception as exc:
            self._player_error = str(exc)
            self.playerChanged.emit()
            return
        self._player_dir = str(directory)
        self._player_profile = profile.dump()
        # The exported package carries its plugins; enable them for this run
        # even on a machine whose global settings have never seen them.
        for pid in profile.plugins:
            self.plugins.set_enabled(pid, True)
        self.show.setProfileDir(str(directory))
        self.show.setPluginIds(profile.plugins)
        access = self._player_profile.get("global", {}).get("accessibility", {})
        self.theme.refresh(
            profile.meta.theme,
            profile.token_overrides,
            bool(access.get("high_contrast", False)),
            bool(access.get("reduced_transparency", False)),
            profile.plugins,
        )
        self.playerChanged.emit()

    def _resolve_player_profile(self, arg: str) -> tuple[Path, Profile]:
        if not arg:
            raise ValueError("缺少演出配置档参数（--play <profile>）")
        if arg == "last":
            # Convenience for double-click launchers: resolve to the profile
            # most recently opened in the editor.
            arg = str(self.settings.get("last_profile_id", "") or "")
            if not arg:
                raise ValueError("没有最近打开的配置档：请先在编辑器中打开一个，或指定 --play <profile>")
        raw = arg
        if raw.startswith("file:"):
            raw = QUrl(raw).toLocalFile()
        p = Path(raw)
        if p.is_dir():
            profile_json = p / "profile.json"
            if not profile_json.exists():
                raise ValueError(f"目录中没有 profile.json：{p}")
            profile, _ = self.store.load_path(profile_json)
            return p, profile
        if p.suffix.lower() == ".bbp" and p.exists():
            tmp = Path(tempfile.mkdtemp(prefix="birthday-player-"))
            with zipfile.ZipFile(p, "r") as zf:
                for member in zf.infolist():
                    target = (tmp / member.filename).resolve()
                    if not str(target).startswith(str(tmp.resolve())):
                        continue
                    if not member.is_dir():
                        target.parent.mkdir(parents=True, exist_ok=True)
                        with zf.open(member) as src, open(target, "wb") as dst:
                            dst.write(src.read())
            profile, _ = self.store.load_path(tmp / "profile.json")
            return tmp, profile
        if p.name == "profile.json" and p.exists():
            profile, _ = self.store.load_path(p)
            return p.parent, profile
        # Fallback: profile id in the local library
        if self.store.exists(raw):
            profile, _ = self.store.load_path(self.store.dir_of(raw) / "profile.json")
            return self.store.dir_of(raw), profile
        raise ValueError(f"找不到配置档：{arg}")

    # ------------------------------------------------------------------ #
    # Lifecycle / settings
    # ------------------------------------------------------------------ #
    @Slot()
    def finish(self) -> None:
        try:
            if self._mode == "editor":
                self.session.closeSession()
                self.settings.save()
        except Exception:
            pass
        try:
            self.audio.shutdown()
            self.show.mic.stop()
        except Exception:
            pass

    @Slot()
    def quitApp(self) -> None:
        from PySide6.QtWidgets import QApplication

        self.finish()
        QApplication.instance().quit()

    @Slot()
    def closePlayer(self) -> None:
        self.quitApp()

    @Slot(str, result="QVariant")
    def getSetting(self, key: str) -> Any:
        return self.settings.get(key)

    @Slot(str, "QVariant", result=bool)
    def setSetting(self, key: str, value: Any) -> bool:
        try:
            self.settings.set(key, value)
            self.settings.save()
        except Exception:
            return False
        self.settingsChanged.emit()
        return True

    @Slot(int, int, int, int, bool)
    def saveWindowGeometry(self, x: int, y: int, w: int, h: int, maximized: bool) -> None:
        self.settings.set("window", {"x": x, "y": y, "width": w, "height": h, "maximized": maximized})
        self.settings.save()

    @Slot(int, int, int)
    def saveLayout(self, left: int, right: int, timeline: int) -> None:
        self.settings.set("layout", {"left_width": left, "right_width": right, "timeline_height": timeline})
        self.settings.save()

    @Slot(str, int, str, bool, bool, bool, bool)
    def savePreviewSettings(
        self,
        resolution: str,
        zoom: int,
        environment: str,
        slowmo: bool,
        muted: bool,
        audit: bool,
        reduced_motion: bool,
    ) -> None:
        self.settings.set(
            "preview",
            {
                "resolution": resolution,
                "zoom": zoom,
                "environment": environment,
                "slowmo": slowmo,
                "muted": muted,
                "audit_overlay": audit,
                "reduced_motion": reduced_motion,
            },
        )
        self.settings.save()

    @Slot(str)
    def setLastExportDir(self, path: str) -> None:
        self.settings.set("last_export_dir", path)
        self.settings.save()

    @Slot(str)
    def openPath(self, path: str) -> None:
        from PySide6.QtGui import QDesktopServices

        p = Path(QUrl(path).toLocalFile()) if path.startswith("file:") else Path(path)
        if p.is_file():
            p = p.parent
        if p.exists():
            QDesktopServices.openUrl(QUrl.fromLocalFile(str(p)))

    @Slot(str)
    def openUrl(self, url: str) -> None:
        from PySide6.QtGui import QDesktopServices

        QDesktopServices.openUrl(QUrl(url))

    @Slot(str)
    def copyText(self, text: str) -> None:
        from PySide6.QtGui import QGuiApplication

        QGuiApplication.clipboard().setText(text)

    @Slot(str)
    def clearCrashCandidate(self, profile_id: str) -> None:
        self._crash_candidates = [c for c in self._crash_candidates if c.get("id") != profile_id]
        self.crashPlanChanged.emit()

    @Slot()
    def pluginsFolder(self) -> str:
        PLUGINS_DIR.mkdir(parents=True, exist_ok=True)
        return str(PLUGINS_DIR)
