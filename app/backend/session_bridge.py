"""Editing session: draft, undo/redo, debounced atomic autosave, validation."""

from __future__ import annotations

import copy
import json
import re
import time
from datetime import datetime
from pathlib import Path
from typing import Any

from PySide6.QtCore import QObject, Property, QTimer, QUrl, Signal, Slot

from ..config import defaults
from ..config.io import atomic_write_json
from ..config.schema import Profile, now_iso
from ..core import colors
from ..core.profile_store import ProfileStore
from ..core.settings import Settings
from ..core.tokens import TokenResolver
from ..core.validator import validate_profile
from .theme_bridge import ThemeBridge

AUTOSAVE_DEBOUNCE_MS = 800
_MISSING = object()


def parse_path(path: str) -> list[Any]:
    tokens: list[Any] = []
    for part in path.split("."):
        if not part:
            continue
        m = re.match(r"^([^\[]+)((?:\[\d+\])*)$", part)
        if not m:
            tokens.append(part)
            continue
        tokens.append(m.group(1))
        for idx in re.findall(r"\[(\d+)\]", m.group(2)):
            tokens.append(int(idx))
    return tokens


def get_path(data: Any, path: str) -> Any:
    cur = data
    for token in parse_path(path):
        if isinstance(token, int):
            if not isinstance(cur, list) or token >= len(cur):
                return _MISSING
            cur = cur[token]
        else:
            if not isinstance(cur, dict) or token not in cur:
                return _MISSING
            cur = cur[token]
    return cur


def set_path(data: Any, path: str, value: Any) -> None:
    tokens = parse_path(path)
    if not tokens:
        return
    cur = data
    for i, token in enumerate(tokens[:-1]):
        nxt = tokens[i + 1]
        if isinstance(token, int):
            while len(cur) <= token:
                cur.append({} if not isinstance(nxt, int) else [])
            cur = cur[token]
        else:
            if not isinstance(cur, dict):
                return
            if token not in cur or cur[token] is None:
                cur[token] = [] if isinstance(nxt, int) else {}
            cur = cur[token]
    last = tokens[-1]
    if isinstance(last, int):
        while len(cur) <= last:
            cur.append(None)
        cur[last] = value
    elif isinstance(cur, dict):
        cur[last] = value


def remove_path(data: Any, path: str) -> None:
    tokens = parse_path(path)
    if not tokens:
        return
    cur = data
    for token in tokens[:-1]:
        try:
            cur = cur[token]
        except (KeyError, IndexError, TypeError):
            return
    last = tokens[-1]
    try:
        if isinstance(last, int):
            del cur[last]
        else:
            cur.pop(last, None)
    except (KeyError, IndexError, TypeError):
        pass


def _local_path(value: str) -> Path:
    if value.startswith("file:"):
        return Path(QUrl(value).toLocalFile())
    return Path(value)


def _jsonish(value: Any) -> Any:
    """Normalise QML values (QVariant, map, list) into plain Python data."""
    if isinstance(value, dict):
        return {str(k): _jsonish(v) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [_jsonish(v) for v in value]
    if isinstance(value, (str, int, float, bool)) or value is None:
        return value
    try:
        return json.loads(json.dumps(value))
    except (TypeError, ValueError):
        return str(value)


class SessionBridge(QObject):
    opened = Signal(str)
    closed = Signal()
    draftChanged = Signal()
    previewChanged = Signal()
    issuesChanged = Signal()
    saveStateChanged = Signal()
    profileIdChanged = Signal()
    canUndoChanged = Signal()
    canRedoChanged = Signal()
    themeChanged = Signal(str)
    assetImported = Signal(str)
    toast = Signal(str)

    def __init__(
        self,
        store: ProfileStore,
        settings: Settings,
        theme: ThemeBridge,
        resolver: TokenResolver,
        plugins,
        parent: QObject | None = None,
    ) -> None:
        super().__init__(parent)
        self.store = store
        self.settings = settings
        self.theme = theme
        self.resolver = resolver
        self.plugins = plugins
        self._draft: dict[str, Any] | None = None
        self._preview: dict[str, Any] = {}
        self._last_valid: dict[str, Any] = {}
        self._issues: list[dict[str, Any]] = []
        self._field_issues: dict[str, dict[str, str]] = {}
        self._undo: list[dict[str, Any]] = []
        self._redo: list[dict[str, Any]] = []
        self._dirty = False
        self._save_state = "saved"
        self._save_text = "尚未打开配置档"
        self._context: dict[str, Any] = {}
        self._last_undo_path = ""
        self._last_undo_time = 0.0
        self._last_preview_render = 0.0
        self._timer = QTimer(self)
        self._timer.setSingleShot(True)
        self._timer.setInterval(AUTOSAVE_DEBOUNCE_MS)
        self._timer.timeout.connect(self.flush)
        self._context_timer = QTimer(self)
        self._context_timer.setSingleShot(True)
        self._context_timer.setInterval(1200)
        self._context_timer.timeout.connect(self._persist_context)
        self._available_themes = {t["id"] for t in defaults.list_themes()}

    # ------------------------------------------------------------------ #
    # Properties
    # ------------------------------------------------------------------ #
    def _read_draft(self) -> dict[str, Any]:
        return self._draft or {}

    draft = Property("QVariantMap", _read_draft, notify=draftChanged)

    def _read_preview(self) -> dict[str, Any]:
        return self._preview

    preview = Property("QVariantMap", _read_preview, notify=previewChanged)

    def _read_issues(self) -> list[dict[str, Any]]:
        return self._issues

    issues = Property("QVariantList", _read_issues, notify=issuesChanged)

    def _read_field_issues(self) -> dict[str, Any]:
        return self._field_issues

    fieldIssues = Property("QVariantMap", _read_field_issues, notify=issuesChanged)

    def _read_profile_id(self) -> str:
        return str((self._draft or {}).get("id", ""))

    profileId = Property(str, _read_profile_id, notify=profileIdChanged)

    def _read_dirty(self) -> bool:
        return self._dirty

    dirty = Property(bool, _read_dirty, notify=saveStateChanged)

    def _read_save_state(self) -> str:
        return self._save_state

    saveState = Property(str, _read_save_state, notify=saveStateChanged)

    def _read_save_text(self) -> str:
        return self._save_text

    saveText = Property(str, _read_save_text, notify=saveStateChanged)

    @Property(int, notify=issuesChanged)
    def errorCount(self) -> int:
        return sum(1 for i in self._issues if i["severity"] == "error")

    @Property(int, notify=issuesChanged)
    def warningCount(self) -> int:
        return sum(1 for i in self._issues if i["severity"] == "warning")

    @Property(bool, notify=issuesChanged)
    def canExport(self) -> bool:
        return bool(self._draft) and self.errorCount == 0

    @Property(bool, notify=canUndoChanged)
    def canUndo(self) -> bool:
        return bool(self._undo)

    @Property(bool, notify=canRedoChanged)
    def canRedo(self) -> bool:
        return bool(self._redo)

    def _read_context(self) -> dict[str, Any]:
        return self._context

    context = Property("QVariantMap", _read_context, notify=draftChanged)

    @Property(str, notify=draftChanged)
    def profileDir(self) -> str:
        if not self._draft:
            return ""
        return str(self.store.dir_of(self._draft.get("id", "")))

    # ------------------------------------------------------------------ #
    # Open / close
    # ------------------------------------------------------------------ #
    @Slot(str)
    def openProfile(self, profile_id: str) -> bool:
        try:
            self._flush_now()
            profile, _raw = self.store.load(profile_id)
        except Exception as exc:
            self.toast.emit(f"打开失败：{exc}")
            return False
        self._draft = profile.dump()
        for pid in self._draft.get("plugins", []):
            self.plugins.set_enabled(pid, True)
        self._last_valid = copy.deepcopy(self._draft)
        self._undo.clear()
        self._redo.clear()
        self._dirty = False
        self._save_state = "saved"
        self._save_text = "已从磁盘加载"
        self._context = self.settings.context_for(profile_id)
        self.settings.remember_profile(profile_id)
        self._refresh_theme()
        self._validate()
        self.profileIdChanged.emit()
        self.draftChanged.emit()
        self.previewChanged.emit()
        self.saveStateChanged.emit()
        self.canUndoChanged.emit()
        self.canRedoChanged.emit()
        self.opened.emit(profile_id)
        return True

    @Slot()
    def closeSession(self) -> None:
        if not self._draft:
            return
        self._flush_now()
        self._persist_context()
        pid = self._draft.get("id", "")
        try:
            self.store.journal(pid, "close", "editor-close")
        except Exception:
            pass
        self._draft = None
        self._preview = {}
        self._issues = []
        self._field_issues = {}
        self._save_text = "尚未打开配置档"
        self._save_state = "saved"
        self._dirty = False
        self.draftChanged.emit()
        self.previewChanged.emit()
        self.issuesChanged.emit()
        self.saveStateChanged.emit()
        self.profileIdChanged.emit()
        self.closed.emit()

    @Slot(str, str, str, str, result=bool)
    def newProfile(self, theme_id: str, name: str, honoree: str, author: str) -> bool:
        try:
            profile = self.store.create(
                theme_id=theme_id or "glass-celebration",
                name=name,
                honoree=honoree or "你",
                author=author or "SrQingChen",
            )
        except Exception as exc:
            self.toast.emit(f"新建失败：{exc}")
            return False
        return self.openProfile(profile.id)

    # ------------------------------------------------------------------ #
    # Editing
    # ------------------------------------------------------------------ #
    @Slot(str, "QVariant")
    def setField(self, path: str, value: Any) -> None:
        if not self._draft or not path:
            return
        value = _jsonish(value)
        current = get_path(self._draft, path)
        if current is not _MISSING and current == value:
            return
        self._push_undo(path)
        set_path(self._draft, path, value)
        if path.startswith("meta.") or path == "acts" or path.startswith("acts."):
            self._draft.setdefault("meta", {})["modified_at"] = now_iso()
        self._mark_dirty()
        self._validate()
        if path.startswith("meta.theme") or path.startswith("global.accessibility"):
            self._refresh_theme()
        self.draftChanged.emit()
        self.previewChanged.emit()
        self.issuesChanged.emit()

    @Slot(str, int)
    def setIntField(self, path: str, value: int) -> None:
        """Combo selections arrive as JS numbers (doubles); keep int fields int."""
        self.setField(path, int(value))

    @Slot("QVariantMap")
    def setFields(self, fields: dict[str, Any]) -> None:
        if not self._draft:
            return
        self._push_undo("__batch__")
        for path, value in fields.items():
            set_path(self._draft, str(path), _jsonish(value))
        self._draft.setdefault("meta", {})["modified_at"] = now_iso()
        self._mark_dirty()
        self._validate()
        self.draftChanged.emit()
        self.previewChanged.emit()
        self.issuesChanged.emit()

    @Slot(str)
    def resetField(self, path: str) -> None:
        if not self._draft:
            return
        default = defaults.default_profile_dict(self._draft.get("id", "default"))
        fallback = get_path(default, path)
        if fallback is _MISSING:
            remove_path(self._draft, path)
        else:
            set_path(self._draft, path, copy.deepcopy(fallback))
        self._mark_dirty()
        self._validate()
        self.draftChanged.emit()
        self.previewChanged.emit()
        self.issuesChanged.emit()

    @Slot(str)
    def resetAct(self, act_id: str) -> None:
        if not self._draft:
            return
        default = defaults.default_profile_dict(self._draft.get("id", "default"))
        act = get_path(default, f"acts.{act_id}")
        if act is _MISSING:
            return
        self._push_undo(f"acts.{act_id}")
        set_path(self._draft, f"acts.{act_id}", copy.deepcopy(act))
        self._mark_dirty()
        self._validate()
        self.draftChanged.emit()
        self.previewChanged.emit()
        self.issuesChanged.emit()

    @Slot(int, str, "QVariant")
    def setCardField(self, index: int, field: str, value: Any) -> None:
        self.setField(f"acts.popups.cards[{index}].{field}", value)

    @Slot()
    def addCard(self) -> None:
        if not self._draft:
            return
        from ..config.schema import PopupCard

        cards = get_path(self._draft, "acts.popups.cards")
        if not isinstance(cards, list) or len(cards) >= 24:
            return
        self._push_undo("acts.popups.cards")
        card = PopupCard().model_dump(by_alias=True)
        cards.append(card)
        self._mark_dirty()
        self._validate()
        self.draftChanged.emit()
        self.previewChanged.emit()
        self.issuesChanged.emit()

    @Slot(int)
    def removeCard(self, index: int) -> None:
        cards = get_path(self._draft, "acts.popups.cards") if self._draft else _MISSING
        if not isinstance(cards, list) or not (0 <= index < len(cards)) or len(cards) <= 1:
            return
        self._push_undo("acts.popups.cards")
        cards.pop(index)
        self._mark_dirty()
        self._validate()
        self.draftChanged.emit()
        self.previewChanged.emit()
        self.issuesChanged.emit()

    @Slot(int, int)
    def moveCard(self, source: int, target: int) -> None:
        cards = get_path(self._draft, "acts.popups.cards") if self._draft else _MISSING
        if not isinstance(cards, list) or not (0 <= source < len(cards)):
            return
        target = max(0, min(len(cards) - 1, target))
        self._push_undo("acts.popups.cards")
        cards.insert(target, cards.pop(source))
        self._mark_dirty()
        self._validate()
        self.draftChanged.emit()
        self.previewChanged.emit()
        self.issuesChanged.emit()

    @Slot()
    def addCakeLayer(self) -> None:
        layers = get_path(self._draft, "acts.cake.cake.layers") if self._draft else _MISSING
        if not isinstance(layers, list) or len(layers) >= 5:
            return
        from ..config.schema import CakeLayerConfig

        top = layers[-1]
        layer = CakeLayerConfig(
            radius=max(50, float(top.get("radius", 120)) - 46),
            height=float(top.get("height", 78)) - 8,
            color=top.get("color", "#f6d3c3"),
            frosting=top.get("frosting", "#fff4ec"),
        ).model_dump(by_alias=True)
        self._push_undo("acts.cake.cake.layers")
        layers.append(layer)
        self._mark_dirty()
        self._validate()
        self.draftChanged.emit()
        self.previewChanged.emit()
        self.issuesChanged.emit()

    @Slot(int)
    def removeCakeLayer(self, index: int) -> None:
        layers = get_path(self._draft, "acts.cake.cake.layers") if self._draft else _MISSING
        if not isinstance(layers, list) or not (0 <= index < len(layers)) or len(layers) <= 1:
            return
        self._push_undo("acts.cake.cake.layers")
        layers.pop(index)
        self._mark_dirty()
        self._validate()
        self.draftChanged.emit()
        self.previewChanged.emit()
        self.issuesChanged.emit()

    @Slot(str, bool)
    def applyTheme(self, theme_id: str, apply_styling: bool = True) -> None:
        if not self._draft:
            return
        self._push_undo("meta.theme")
        self._draft.setdefault("meta", {})["theme"] = theme_id
        self._draft["token_overrides"] = {}
        if apply_styling:
            template = defaults.load_theme_template(theme_id)
            acts = copy.deepcopy(template.get("acts", {}))
            allowed = ("intro", "wax", "popups", "confirm", "cake", "finale")
            for act_id in allowed:
                if act_id in acts and isinstance(acts[act_id], dict):
                    self._deep_override(self._draft["acts"].setdefault(act_id, {}), acts[act_id])
        self._draft.setdefault("meta", {})["modified_at"] = now_iso()
        self._refresh_theme()
        self.themeChanged.emit(theme_id)
        self._mark_dirty()
        self._validate()
        self.draftChanged.emit()
        self.previewChanged.emit()
        self.issuesChanged.emit()

    @staticmethod
    def _deep_override(target: dict[str, Any], overlay: dict[str, Any]) -> None:
        for key, value in overlay.items():
            if isinstance(value, dict) and isinstance(target.get(key), dict):
                SessionBridge._deep_override(target[key], value)
            else:
                target[key] = copy.deepcopy(value)

    # ------------------------------------------------------------------ #
    # Undo / redo
    # ------------------------------------------------------------------ #
    def _push_undo(self, path: str) -> None:
        if not self._draft:
            return
        now = time.monotonic()
        if path == self._last_undo_path and now - self._last_undo_time < 0.8:
            self._last_undo_time = now
            return
        self._undo.append(copy.deepcopy(self._draft))
        if len(self._undo) > 100:
            self._undo.pop(0)
        self._redo.clear()
        self._last_undo_path = path
        self._last_undo_time = now
        self.canUndoChanged.emit()
        self.canRedoChanged.emit()

    @Slot()
    def undo(self) -> None:
        if not self._undo or not self._draft:
            return
        self._redo.append(copy.deepcopy(self._draft))
        self._draft = self._undo.pop()
        self._last_undo_path = ""
        self._mark_dirty()
        self._validate()
        self.draftChanged.emit()
        self.previewChanged.emit()
        self.issuesChanged.emit()
        self.canUndoChanged.emit()
        self.canRedoChanged.emit()

    @Slot()
    def redo(self) -> None:
        if not self._redo or not self._draft:
            return
        self._undo.append(copy.deepcopy(self._draft))
        self._draft = self._redo.pop()
        self._last_undo_path = ""
        self._mark_dirty()
        self._validate()
        self.draftChanged.emit()
        self.previewChanged.emit()
        self.issuesChanged.emit()
        self.canUndoChanged.emit()
        self.canRedoChanged.emit()

    # ------------------------------------------------------------------ #
    # Save
    # ------------------------------------------------------------------ #
    def _mark_dirty(self) -> None:
        self._dirty = True
        self._save_state = "dirty"
        self._save_text = "未保存的更改"
        self._timer.start()
        self.saveStateChanged.emit()

    @Slot()
    def flush(self) -> None:
        self._flush_now()

    def _flush_now(self) -> None:
        if not self._draft or not self._dirty:
            return
        self._timer.stop()
        self._save_state = "saving"
        self._save_text = "保存中…"
        self.saveStateChanged.emit()
        pid = self._draft.get("id", "")
        try:
            profile: Profile | None = None
            try:
                profile = Profile.model_validate(self._draft)
            except Exception:
                profile = None
            if profile is not None:
                self.store.save(profile, reason="autosave")
                now = time.monotonic()
                if now - self._last_preview_render > 20:
                    self.store.render_preview(profile)
                    self._last_preview_render = now
            else:
                self.store.save_raw(pid, self._draft, reason="autosave-invalid")
            self._dirty = False
            self._save_state = "saved"
            self._save_text = f"已自动保存 {datetime.now().strftime('%H:%M')}"
        except Exception as exc:
            self._save_state = "failed"
            self._save_text = f"保存失败：{exc}"
            self.toast.emit(self._save_text)
        self.saveStateChanged.emit()

    @Slot(result=bool)
    def forceSave(self) -> bool:
        self._flush_now()
        return self._save_state != "failed"

    # ------------------------------------------------------------------ #
    # Validation
    # ------------------------------------------------------------------ #
    def _tokens_for(self, draft: dict[str, Any]) -> dict[str, Any]:
        theme_id = draft.get("meta", {}).get("theme", "glass-celebration")
        plugin_ids = draft.get("plugins", [])
        deltas = self.plugins.token_deltas(plugin_ids) if plugin_ids else []
        return self.resolver.resolve(theme_id, deltas, draft.get("token_overrides", {}))

    def _validate(self) -> None:
        if not self._draft:
            self._issues = []
            self._field_issues = {}
            self._preview = {}
            return
        tokens = self._tokens_for(self._draft)
        report = validate_profile(
            self._draft,
            profile_dir=self.store.dir_of(self._draft.get("id", "")),
            tokens=tokens,
            available_themes=self._available_themes or None,
        )
        self._issues = report.as_dicts()
        self._issues.sort(key=lambda i: (0 if i["severity"] == "error" else 1, i["path"]))
        field_map: dict[str, dict[str, str]] = {}
        for issue in self._issues:
            path = issue["path"]
            prev = field_map.get(path)
            if prev is None or (prev["severity"] != "error" and issue["severity"] == "error"):
                field_map[path] = {"severity": issue["severity"], "message": issue["message"]}
        self._field_issues = field_map
        if report.profile is not None:
            self._last_valid = copy.deepcopy(self._draft)
            self._preview = copy.deepcopy(self._draft)
        else:
            safe = copy.deepcopy(self._draft)
            for issue in report.errors:
                fallback = get_path(self._last_valid, issue.path)
                if fallback is not _MISSING:
                    set_path(safe, issue.path, copy.deepcopy(fallback))
                else:
                    remove_path(safe, issue.path)
            report2 = validate_profile(
                safe,
                profile_dir=self.store.dir_of(self._draft.get("id", "")),
                tokens=tokens,
                available_themes=self._available_themes or None,
            )
            self._preview = report2.profile.dump() if report2.profile else copy.deepcopy(self._last_valid)

    @Slot(str, result="QVariantMap")
    def issueFor(self, path: str) -> dict[str, Any]:
        key = path.strip("[]")
        return self._field_issues.get(path) or self._field_issues.get(key) or {}

    @Slot(str, result=str)
    def severityFor(self, path: str) -> str:
        if path in self._field_issues:
            return self._field_issues[path]["severity"]
        prefix = path + "."
        worst = ""
        for key, issue in self._field_issues.items():
            if key.startswith(prefix):
                if issue["severity"] == "error":
                    return "error"
                worst = "warning"
        return worst

    # ------------------------------------------------------------------ #
    # Theme / assets / context
    # ------------------------------------------------------------------ #
    def _refresh_theme(self) -> None:
        if not self._draft:
            return
        theme_id = self._draft.get("meta", {}).get("theme", "glass-celebration")
        access = self._draft.get("global", {}).get("accessibility", {})
        plugin_ids = self._draft.get("plugins", [])
        self.theme.refresh(
            theme_id,
            self._draft.get("token_overrides", {}),
            bool(access.get("high_contrast", False)),
            bool(access.get("reduced_transparency", False)),
            plugin_ids,
        )

    @Slot(str, str, str, result=str)
    def importAsset(self, path: str, kind: str, license_type: str) -> str:
        if not self._draft:
            return ""
        try:
            asset = self.store.import_asset(
                self._draft["id"], _local_path(path), kind=kind, license_type=license_type
            )
        except Exception as exc:
            self.toast.emit(f"导入资源失败：{exc}")
            return ""
        assets = self._draft.setdefault("assets", [])
        if not any(a.get("sha256") == asset["sha256"] for a in assets):
            assets.append(asset)
        rel = f"assets/{asset['filename']}"
        self._make_dirty_only()
        self._validate()
        self.draftChanged.emit()
        self.previewChanged.emit()
        self.issuesChanged.emit()
        self.assetImported.emit(rel)
        return rel

    def _make_dirty_only(self) -> None:
        self._dirty = True
        self._save_state = "dirty"
        self._save_text = "未保存的更改"
        self._timer.start()
        self.saveStateChanged.emit()

    @Slot(str, str, result=str)
    def assetUrl(self, path: str) -> str:
        if not path or not self._draft:
            return ""
        p = Path(path)
        if p.is_absolute():
            return p.as_uri() if p.exists() else ""
        if path.startswith("assets/"):
            candidate = self.store.dir_of(self._draft["id"]) / path
            return candidate.as_uri() if candidate.exists() else ""
        from ..core.paths import RESOURCES_DIR

        candidate = RESOURCES_DIR / path
        if candidate.exists():
            return candidate.as_uri()
        from ..core.paths import BUILTIN_AUDIO_DIR

        candidate = BUILTIN_AUDIO_DIR / Path(path).name
        return candidate.as_uri() if candidate.exists() else ""

    @Slot("QVariantMap")
    def setContext(self, context: dict[str, Any]) -> None:
        self._context = _jsonish(context)
        self._context_timer.start()

    def _persist_context(self) -> None:
        if self._draft:
            self.settings.set_context(self._draft.get("id", ""), self._context)
            self.settings.save()

    @Slot(result="QVariantList")
    def snapshots(self) -> list[dict[str, Any]]:
        if not self._draft:
            return []
        return self.store.snapshots(self._draft["id"])

    @Slot(str, result=bool)
    def restoreSnapshot(self, snapshot_file: str) -> bool:
        if not self._draft:
            return False
        try:
            profile = self.store.restore_snapshot(self._draft["id"], snapshot_file)
        except Exception as exc:
            self.toast.emit(f"恢复快照失败：{exc}")
            return False
        self._draft = profile.dump()
        self._last_valid = copy.deepcopy(self._draft)
        self._undo.clear()
        self._redo.clear()
        self._dirty = False
        self._save_text = "已从快照恢复"
        self._save_state = "saved"
        self._refresh_theme()
        self._validate()
        self.draftChanged.emit()
        self.previewChanged.emit()
        self.issuesChanged.emit()
        self.saveStateChanged.emit()
        self.canUndoChanged.emit()
        self.canRedoChanged.emit()
        return True

    @Slot(str, result=bool)
    def replaceDraft(self, text: str) -> bool:
        if not self._draft:
            return False
        try:
            data = json.loads(text)
            if not isinstance(data, dict):
                raise ValueError("根节点必须是对象")
        except (json.JSONDecodeError, ValueError) as exc:
            self.toast.emit(f"JSON 解析失败：{exc}")
            return False
        self._push_undo("__json__")
        data["id"] = self._draft.get("id", data.get("id", ""))
        self._draft = _jsonish(data)
        self._mark_dirty()
        self._validate()
        self._refresh_theme()
        self.draftChanged.emit()
        self.previewChanged.emit()
        self.issuesChanged.emit()
        self.toast.emit("已应用 JSON")
        return True

    @Slot()
    def refreshTheme(self) -> None:
        self._refresh_theme()

    @Slot(str, result=str)
    def exportBbp(self, destination: str) -> str:
        if not self._draft:
            return ""
        try:
            path = self.store.export_bbp(self._draft["id"], _local_path(destination))
            self.toast.emit(f"已导出配置包：{path.name}")
            return str(path)
        except Exception as exc:
            self.toast.emit(f"导出失败：{exc}")
            return ""

    @Slot(str, str, result=float)
    def contrast(self, a: str, b: str) -> float:
        try:
            return colors.contrast_ratio(a, b)
        except ValueError:
            return 1.0
