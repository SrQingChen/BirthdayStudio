"""Application-level settings, kept separate from profiles."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from ..config.io import atomic_write_json
from .paths import SETTINGS_PATH


DEFAULTS: dict[str, Any] = {
    "last_profile_id": "",
    "startup_restore": True,
    "editor_mode": "wizard",
    "window": {"x": 120, "y": 80, "width": 1440, "height": 900, "maximized": False},
    "layout": {"left_width": 268, "right_width": 348, "timeline_height": 220},
    "preview": {
        "resolution": "1080p",
        # Percentage (50..200). A legacy default of 1.0 here once shrank the
        # preview stage to an invisible speck — see Editor.qml sanitize.
        "zoom": 100,
        "environment": "dark",
        "slowmo": False,
        "muted": False,
        "reduced_motion": False,
        "high_contrast": False,
        "audit_overlay": False,
    },
    "contexts": {},
    "recent_profiles": [],
    "last_export_dir": "",
    "seen_welcome": False,
    "plugins": {"enabled": []},
}


class Settings:
    def __init__(self, path: Path | None = None) -> None:
        self.path = path or SETTINGS_PATH
        self.data: dict[str, Any] = json.loads(json.dumps(DEFAULTS))
        self.load()

    def load(self) -> None:
        if not self.path.exists():
            return
        try:
            with open(self.path, "r", encoding="utf-8") as f:
                loaded = json.load(f)
            if isinstance(loaded, dict):
                self.data = _merge(DEFAULTS, loaded)
        except (OSError, json.JSONDecodeError):
            # Settings are not precious; a corrupt file falls back to defaults.
            self.data = json.loads(json.dumps(DEFAULTS))

    def save(self) -> None:
        atomic_write_json(self.path, self.data)

    def get(self, key: str, default: Any = None) -> Any:
        cur: Any = self.data
        for part in key.split("."):
            if not isinstance(cur, dict) or part not in cur:
                return default
            cur = cur[part]
        return cur

    def set(self, key: str, value: Any) -> None:
        parts = key.split(".")
        cur = self.data
        for part in parts[:-1]:
            nxt = cur.get(part)
            if not isinstance(nxt, dict):
                nxt = {}
                cur[part] = nxt
            cur = nxt
        cur[parts[-1]] = value

    def remember_profile(self, profile_id: str) -> None:
        self.data["last_profile_id"] = profile_id
        recent = [p for p in self.data.get("recent_profiles", []) if p != profile_id]
        recent.insert(0, profile_id)
        self.data["recent_profiles"] = recent[:12]
        self.save()

    def context_for(self, profile_id: str) -> dict[str, Any]:
        return dict(self.data.get("contexts", {}).get(profile_id, {}))

    def set_context(self, profile_id: str, context: dict[str, Any]) -> None:
        self.data.setdefault("contexts", {})[profile_id] = context

    def forget_profile(self, profile_id: str) -> None:
        if self.data.get("last_profile_id") == profile_id:
            self.data["last_profile_id"] = ""
        self.data["recent_profiles"] = [
            p for p in self.data.get("recent_profiles", []) if p != profile_id
        ]
        self.data.get("contexts", {}).pop(profile_id, None)
        self.save()


def _merge(base: dict[str, Any], overlay: dict[str, Any]) -> dict[str, Any]:
    out = json.loads(json.dumps(base))
    for key, value in overlay.items():
        if isinstance(value, dict) and isinstance(out.get(key), dict):
            out[key] = _merge(out[key], value)
        else:
            out[key] = value
    return out
