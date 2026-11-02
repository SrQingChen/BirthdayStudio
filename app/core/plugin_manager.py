"""Theme plugin registry: manifest validation, semver gate, token deltas, slots.

Security boundary (V1.0 §3.4): a plugin is QML/JS + shaders + assets only.
There is no Python execution surface.  The manager only reads manifest.json
and tokens.json; it never imports plugin code.
"""

from __future__ import annotations

import json
import re
import shutil
from pathlib import Path
from typing import Any

from .paths import PLUGINS_DIR, PROJECT_ROOT, packaged_plugins_dir

HOST_VERSION = (1, 0, 0)
SLOTS = [
    "PopupCard",
    "WaxSeal",
    "LetterPaper",
    "ConfirmButton",
    "DissolveEffect",
    "Background",
    "CakeDecor",
    "FinaleFX",
]
_SEMVER_RE = re.compile(r"^(\d+)\.(\d+)\.(\d+)(?:[-+].*)?$")


def parse_version(value: str) -> tuple[int, int, int] | None:
    m = _SEMVER_RE.match(str(value).strip())
    if not m:
        return None
    return int(m.group(1)), int(m.group(2)), int(m.group(3))


def version_in_range(version: tuple[int, int, int], spec: str) -> bool:
    """Tiny semver range parser: supports >=, <=, >, <, =, ^, ~ and space-AND / ||-OR."""
    if not spec.strip():
        return True
    for alt in spec.split("||"):
        if all(_version_in_range_single(version, token) for token in alt.split()):
            return True
    return False


def _version_in_range_single(version: tuple[int, int, int], token: str) -> bool:
    token = token.strip()
    if not token:
        return True
    for op in (">=", "<=", ">", "<", "=", "^", "~"):
        if token.startswith(op):
            target = parse_version(token[len(op):])
            if target is None:
                return False
            if op == ">=":
                return version >= target
            if op == "<=":
                return version <= target
            if op == ">":
                return version > target
            if op == "<":
                return version < target
            if op == "=":
                return version == target
            if op == "^":
                return version >= target and version[0] == target[0]
            if op == "~":
                return version >= target and version[:2] == target[:2]
    target = parse_version(token)
    return target == version if target else False


class PluginManager:
    def __init__(self, enabled_ids: list[str] | None = None) -> None:
        self.enabled_ids: set[str] = set(enabled_ids or [])
        self._plugins: dict[str, dict[str, Any]] = {}

    # ------------------------------------------------------------------ #
    # Discovery
    # ------------------------------------------------------------------ #
    def scan(self) -> list[dict[str, Any]]:
        self._plugins.clear()
        self._scan_dir(PLUGINS_DIR, installed=True)
        # Bundled example plugin(s), installed=False
        for bundled in (PROJECT_ROOT / "plugins", packaged_plugins_dir()):
            if bundled.exists():
                self._scan_dir(bundled, installed=False)
        items = []
        for p in self._plugins.values():
            items.append(
                {
                    "id": p["id"],
                    "name": p["name"],
                    "version": p["version"],
                    "author": p.get("author", ""),
                    "description": p.get("description", ""),
                    "compatible": p["compatible"],
                    "compatibilityMessage": p.get("compatibilityMessage", ""),
                    "enabled": p["enabled"],
                    "installed": p["installed"],
                    "hasTokens": p["hasTokens"],
                    "slots": p.get("slots", []),
                    "error": p.get("error", ""),
                    "previewUrl": p.get("previewUrl", ""),
                    "path": str(p["path"]),
                }
            )
        items.sort(key=lambda x: (not x["enabled"], x["name"]))
        return items

    def _scan_dir(self, root: Path, *, installed: bool) -> None:
        if not root.exists():
            return
        for d in sorted(root.iterdir()):
            if not d.is_dir():
                continue
            manifest_path = d / "manifest.json"
            if not manifest_path.exists():
                continue
            try:
                with open(manifest_path, "r", encoding="utf-8") as f:
                    manifest = json.load(f)
            except (OSError, json.JSONDecodeError) as exc:
                self._plugins[d.name] = {
                    "id": d.name,
                    "name": d.name,
                    "version": "0.0.0",
                    "enabled": False,
                    "installed": installed,
                    "compatible": False,
                    "hasTokens": False,
                    "error": f"manifest.json 无法解析：{exc}",
                    "path": d,
                }
                continue
            pid = str(manifest.get("id") or d.name)
            if pid in self._plugins:
                continue
            version = parse_version(manifest.get("version", "0.0.0"))
            host_spec = manifest.get("host", ">=1.0.0")
            compatible = version is not None and version_in_range(HOST_VERSION, str(host_spec))
            plugins_host = manifest.get("apiVersion", 1)
            if plugins_host != 1:
                compatible = False
            tokens_path = d / "tokens.json"
            has_tokens = tokens_path.exists()
            preview = d / "preview.png"
            enabled = pid in self.enabled_ids and compatible
            self._plugins[pid] = {
                "id": pid,
                "name": str(manifest.get("name", pid)),
                "version": str(manifest.get("version", "0.0.0")),
                "author": str(manifest.get("author", "")),
                "description": str(manifest.get("description", "")),
                "host": str(host_spec),
                "apiVersion": plugins_host,
                "enabled": enabled,
                "installed": installed,
                "compatible": compatible,
                "compatibilityMessage": ""
                if compatible
                else f"需要宿主 {host_spec}，当前 {'.'.join(map(str, HOST_VERSION))}",
                "hasTokens": has_tokens,
                "slots": [s for s in manifest.get("slots", []) if s in SLOTS],
                "path": d,
                "previewUrl": preview.as_uri() if preview.exists() else "",
                "error": "",
            }

    # ------------------------------------------------------------------ #
    # State
    # ------------------------------------------------------------------ #
    def set_enabled(self, plugin_id: str, enabled: bool) -> None:
        if enabled:
            self.enabled_ids.add(plugin_id)
        else:
            self.enabled_ids.discard(plugin_id)
        if plugin_id in self._plugins:
            self._plugins[plugin_id]["enabled"] = enabled and self._plugins[plugin_id]["compatible"]

    def enabled_plugins(self) -> list[dict[str, Any]]:
        return [p for p in self._plugins.values() if p["enabled"] and p["compatible"]]

    def token_deltas(self, ids: list[str] | None = None) -> list[dict[str, Any]]:
        wanted = set(ids) if ids is not None else None
        deltas: list[dict[str, Any]] = []
        for p in self.enabled_plugins():
            if wanted is not None and p["id"] not in wanted:
                continue
            tokens_path = p["path"] / "tokens.json"
            if not tokens_path.exists():
                continue
            try:
                with open(tokens_path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                if isinstance(data, dict):
                    deltas.append(data)
            except (OSError, json.JSONDecodeError):
                continue
        return deltas

    def slot_component(self, slot: str, plugin_ids: list[str] | None = None) -> str:
        """Return a file:// URL for the highest-priority plugin component, or ''."""
        if slot not in SLOTS:
            return ""
        wanted = set(plugin_ids) if plugin_ids else None
        for p in self.enabled_plugins():
            if wanted is not None and p["id"] not in wanted:
                continue
            if slot not in p.get("slots", []):
                continue
            for candidate in (
                p["path"] / "components" / f"{slot}.qml",
                p["path"] / "components" / f"{slot}.qml",
            ):
                if candidate.exists():
                    return candidate.as_uri()
        return ""

    def install(self, source_dir: Path) -> str:
        manifest = source_dir / "manifest.json"
        if not manifest.exists():
            raise ValueError("插件目录缺少 manifest.json")
        with open(manifest, "r", encoding="utf-8") as f:
            data = json.load(f)
        pid = str(data.get("id") or source_dir.name)
        target = PLUGINS_DIR / pid
        if target.exists():
            raise FileExistsError(f"插件 {pid} 已安装")
        PLUGINS_DIR.mkdir(parents=True, exist_ok=True)
        shutil.copytree(source_dir, target)
        return pid

    def uninstall(self, plugin_id: str) -> None:
        p = self._plugins.get(plugin_id)
        if not p:
            raise KeyError(plugin_id)
        if not p["installed"]:
            raise ValueError("内置示例插件不能卸载")
        shutil.rmtree(p["path"])
        self.enabled_ids.discard(plugin_id)
        self._plugins.pop(plugin_id, None)

    def plugin_info(self, plugin_id: str) -> dict[str, Any] | None:
        p = self._plugins.get(plugin_id)
        if not p:
            return None
        return {k: (str(v) if isinstance(v, Path) else v) for k, v in p.items()}
