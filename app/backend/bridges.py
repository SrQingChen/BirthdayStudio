"""QML bridges for the profile library, audio transport, plugins and export."""

from __future__ import annotations

from pathlib import Path
from typing import Any

from PySide6.QtCore import QObject, Property, QUrl, Signal, Slot

from ..config import defaults
from ..core.audio import AudioEngine
from ..core.exporter import ExportOptions, Exporter
from ..core.plugin_manager import PluginManager
from ..core.profile_store import ProfileStore
from ..core.settings import Settings


def local_path(value: str) -> Path:
    if value.startswith("file:"):
        return Path(QUrl(value).toLocalFile())
    return Path(value)


class LibraryBridge(QObject):
    profilesChanged = Signal()
    themesChanged = Signal()
    trashChanged = Signal()
    uncleanChanged = Signal()
    toast = Signal(str)
    profileCreated = Signal(str)
    dataChanged = Signal()

    def __init__(self, store: ProfileStore, settings: Settings, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self.store = store
        self.settings = settings
        self._profiles: list[dict[str, Any]] = []
        self._themes: list[dict[str, Any]] = []
        self._trash: list[dict[str, Any]] = []
        self._unclean: list[dict[str, Any]] = []
        self.refresh()

    @Property("QVariantList", notify=profilesChanged)
    def profiles(self) -> list[dict[str, Any]]:
        return self._profiles

    @Property("QVariantList", notify=themesChanged)
    def themes(self) -> list[dict[str, Any]]:
        return self._themes

    @Property("QVariantList", notify=trashChanged)
    def trash(self) -> list[dict[str, Any]]:
        return self._trash

    @Property("QVariantList", notify=uncleanChanged)
    def unclean(self) -> list[dict[str, Any]]:
        return self._unclean

    @Slot()
    def refresh(self) -> None:
        self._profiles = self.store.list()
        self._themes = defaults.list_themes()
        self._trash = self.store.trashed()
        self._unclean = self.store.unclean_profiles()
        self.profilesChanged.emit()
        self.themesChanged.emit()
        self.trashChanged.emit()
        self.uncleanChanged.emit()
        self.dataChanged.emit()

    @Slot(str, str, str, str, result=str)
    def createProfile(self, theme_id: str, name: str, honoree: str, author: str) -> str:
        try:
            profile = self.store.create(
                theme_id=theme_id or "glass-celebration",
                name=name,
                honoree=honoree or "你",
                author=author or "SrQingChen",
            )
        except Exception as exc:
            self.toast.emit(f"新建失败：{exc}")
            return ""
        self.refresh()
        self.profileCreated.emit(profile.id)
        return profile.id

    @Slot(str, result=str)
    def duplicateProfile(self, profile_id: str) -> str:
        try:
            profile = self.store.duplicate(profile_id)
        except Exception as exc:
            self.toast.emit(f"复制失败：{exc}")
            return ""
        self.refresh()
        self.toast.emit(f"已复制为「{profile.meta.name}」")
        return profile.id

    @Slot(str, result=bool)
    def deleteProfile(self, profile_id: str) -> bool:
        try:
            self.store.delete(profile_id)
        except Exception as exc:
            self.toast.emit(f"删除失败：{exc}")
            return False
        self.settings.forget_profile(profile_id)
        self.refresh()
        self.toast.emit("已移入回收站，保留 30 天可恢复")
        return True

    @Slot(str, result=str)
    def restoreTrash(self, trash_dir: str) -> str:
        try:
            profile = self.store.restore_trash(trash_dir)
        except Exception as exc:
            self.toast.emit(f"恢复失败：{exc}")
            return ""
        self.refresh()
        self.toast.emit(f"已恢复「{profile.meta.name}」")
        return profile.id

    @Slot()
    def emptyTrash(self) -> None:
        for item in self._trash:
            try:
                import shutil

                shutil.rmtree(item["trashDir"], ignore_errors=True)
            except Exception:
                continue
        self.refresh()

    @Slot(str, result=str)
    def importBbp(self, url: str) -> str:
        try:
            profile = self.store.import_bbp(local_path(url))
        except Exception as exc:
            self.toast.emit(f"导入失败：{exc}")
            return ""
        self.refresh()
        self.toast.emit(f"已导入「{profile.meta.name}」")
        return profile.id

    @Slot(str, str, result=bool)
    def exportBbp(self, profile_id: str, url: str) -> bool:
        try:
            self.store.export_bbp(profile_id, local_path(url))
        except Exception as exc:
            self.toast.emit(f"导出失败：{exc}")
            return False
        self.toast.emit("配置包已导出")
        return True

    @Slot(str, result="QVariantList")
    def snapshots(self, profile_id: str) -> list[dict[str, Any]]:
        return self.store.snapshots(profile_id)

    @Slot(str, str, str, result=str)
    def resolveCrash(self, profile_id: str, action: str, snapshot_file: str = "") -> str:
        try:
            self.store.resolve_crash(profile_id, action, snapshot_file)
        except Exception as exc:
            self.toast.emit(f"恢复失败：{exc}")
            return ""
        self.refresh()
        return profile_id

    @Slot(str, result=str)
    def themeName(self, theme_id: str) -> str:
        for t in self._themes:
            if t["id"] == theme_id:
                return t["name"]
        return theme_id


class AudioBridge(QObject):
    stateChanged = Signal()
    toast = Signal(str)

    def __init__(self, engine: AudioEngine, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self.engine = engine
        engine.volumeChanged.connect(self.stateChanged)
        engine.mutedChanged.connect(self.stateChanged)
        engine.playingChanged.connect(self.stateChanged)
        engine.errorOccurred.connect(lambda msg: self.toast.emit(msg))

    @Property(int, notify=stateChanged)
    def masterVolume(self) -> int:
        return self.engine.master_pct

    @Property(int, notify=stateChanged)
    def sfxVolume(self) -> int:
        return self.engine.sfx_pct

    @Property(bool, notify=stateChanged)
    def muted(self) -> bool:
        return self.engine.muted

    @Property(bool, notify=stateChanged)
    def playing(self) -> bool:
        return self.engine.bgm_playing

    @Slot(int)
    def setMasterVolume(self, value: int) -> None:
        self.engine.set_master_volume(value)

    @Slot(int)
    def setSfxVolume(self, value: int) -> None:
        self.engine.set_sfx_volume(value)

    @Slot(bool)
    def setMuted(self, value: bool) -> None:
        self.engine.set_muted(value)

    @Slot()
    def toggleMute(self) -> None:
        self.engine.toggle_mute()

    @Slot()
    def togglePause(self) -> None:
        self.engine.toggle_pause()

    @Slot(str, float)
    def playSfx(self, kind: str, scale: float = 1.0) -> None:
        self.engine.play_sfx(kind, scale)

    @Slot(bool)
    def duck(self, active: bool) -> None:
        self.engine.set_ducked(active)


class PluginBridge(QObject):
    pluginsChanged = Signal()
    toast = Signal(str)

    def __init__(self, manager: PluginManager, settings: Settings, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self.manager = manager
        self.settings = settings
        self._plugins = manager.scan()

    @Property("QVariantList", notify=pluginsChanged)
    def plugins(self) -> list[dict[str, Any]]:
        return self._plugins

    @Slot()
    def refresh(self) -> None:
        self._plugins = self.manager.scan()
        self.pluginsChanged.emit()

    def _persist(self) -> None:
        self.settings.set("plugins.enabled", sorted(self.manager.enabled_ids))
        self.settings.save()

    @Slot(str, bool)
    def setEnabled(self, plugin_id: str, enabled: bool) -> None:
        self.manager.set_enabled(plugin_id, enabled)
        self._persist()
        self.refresh()

    @Slot(str, result=bool)
    def uninstall(self, plugin_id: str) -> bool:
        try:
            self.manager.uninstall(plugin_id)
        except Exception as exc:
            self.toast.emit(f"卸载失败：{exc}")
            return False
        self._persist()
        self.refresh()
        self.toast.emit("插件已卸载")
        return True

    @Slot(str, result=str)
    def install(self, url: str) -> str:
        try:
            pid = self.manager.install(local_path(url))
        except Exception as exc:
            self.toast.emit(f"安装失败：{exc}")
            return ""
        self.manager.set_enabled(pid, True)
        self._persist()
        self.refresh()
        self.toast.emit("插件已安装并启用")
        return pid

    @Slot(result=str)
    def pluginFolder(self) -> str:
        from ..core.paths import PLUGINS_DIR

        PLUGINS_DIR.mkdir(parents=True, exist_ok=True)
        return str(PLUGINS_DIR)

    @Slot(result="QVariantList")
    def tokenProviders(self) -> list[dict[str, Any]]:
        return self._plugins


class ExportBridge(QObject):
    finished = Signal("QVariantMap")
    toast = Signal(str)
    stateChanged = Signal()

    def __init__(self, exporter: Exporter, store: ProfileStore, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self.exporter = exporter
        self.store = store
        self._last: dict[str, Any] = {}

    @Property(bool, notify=stateChanged)
    def playerAvailable(self) -> bool:
        return self.exporter.find_player() is not None

    @Property(str, notify=stateChanged)
    def playerPath(self) -> str:
        p = self.exporter.find_player()
        return str(p) if p else ""

    @Property("QVariantMap", notify=stateChanged)
    def lastResult(self) -> dict[str, Any]:
        return self._last

    @Slot(str, str, "QVariantMap", result="QVariantMap")
    def exportPackage(self, profile_id: str, destination: str, options: dict[str, Any]) -> dict[str, Any]:
        try:
            profile, _ = self.store.load(profile_id)
        except Exception as exc:
            self.toast.emit(f"导出前加载失败：{exc}")
            return {"ok": False, "error": str(exc)}
        opts = ExportOptions(
            form=str(options.get("form", "folder")),
            exe_name=str(options.get("exe_name", "")),
            icon_path=str(options.get("icon_path", "")),
            include_profile_bbp=bool(options.get("include_profile_bbp", True)),
            license_confirmations=dict(options.get("license_confirmations", {}) or {}),
            copyright_confirmed=bool(options.get("copyright_confirmed", False)),
            destination=destination,
        )
        try:
            result = self.exporter.export(profile, local_path(destination), opts)
        except Exception as exc:
            self.toast.emit(f"导出失败：{exc}")
            return {"ok": False, "error": str(exc)}
        self._last = result
        self.stateChanged.emit()
        self.finished.emit(result)
        self.toast.emit("导出完成")
        return result

    @Slot(str)
    def openFolder(self, path: str) -> None:
        from PySide6.QtCore import QUrl
        from PySide6.QtGui import QDesktopServices

        p = Path(path)
        if p.is_file():
            p = p.parent
        if p.exists():
            QDesktopServices.openUrl(QUrl.fromLocalFile(str(p)))
