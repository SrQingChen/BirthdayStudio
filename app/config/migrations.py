"""Schema version migration framework.

Only v1 exists today, but every loader goes through :func:`migrate` so future
versions have one place to land.  Unknown newer files are rejected with a
readable message instead of silently dropping fields.
"""

from __future__ import annotations

import copy
import uuid
from typing import Any, Callable

from .schema import SCHEMA_VERSION, now_iso


class SchemaTooNew(Exception):
    def __init__(self, found: int, supported: int = SCHEMA_VERSION) -> None:
        self.found = found
        self.supported = supported
        super().__init__(
            f"配置档版本 v{found} 高于本程序支持的 v{supported}，请升级 BirthdayStudio。"
        )


Migration = Callable[[dict[str, Any]], dict[str, Any]]


def _legacy_v0(data: dict[str, Any]) -> dict[str, Any]:
    """Best-effort adapter for the V0.1 ``theme.json`` layout.

    V0.1 used a flat theme file; V1.0 stores everything under a profile.  We
    keep whatever can be mapped, and everything else falls back to defaults.
    """
    out = copy.deepcopy(data)
    migrated: dict[str, Any] = {
        "schema_version": 1,
        "id": out.get("id") or f"legacy-{uuid.uuid4().hex[:8]}",
        "meta": {
            "name": out.get("name") or out.get("title") or "导入的旧版主题",
            "honoree": out.get("honoree") or "你",
            "author": out.get("author") or "SrQingChen",
            "theme": out.get("theme") or "glass-celebration",
            "created_at": now_iso(),
            "modified_at": now_iso(),
        },
        "global": {
            "audio": {
                "bgm": {
                    "path": (out.get("music") or {}).get("path", ""),
                    "volume_pct": int((out.get("music") or {}).get("volume", 0.5) * 100),
                    "loop": bool((out.get("music") or {}).get("loop", True)),
                }
            }
        },
        "acts": {},
    }
    letter = out.get("letter") or {}
    if letter:
        migrated["acts"]["wax"] = {
            "letter_mode": "none" if letter.get("none") else "animated",
            "letter": {
                "text": letter.get("text", ""),
                "paperColor": letter.get("paperColor", "#f8f0e1"),
                "inkColor": letter.get("inkColor", "#3a2e28"),
            },
        }
    popups = out.get("popups") or {}
    if isinstance(popups, list) and popups:
        migrated["acts"]["popups"] = {
            "cards": [
                {
                    "title": p.get("title", ""),
                    "body": p.get("body", p.get("text", "")),
                    "width": p.get("width", 320),
                    "height": p.get("height", 196),
                }
                for p in popups
            ]
        }
    cake = out.get("cake") or {}
    if cake:
        migrated["acts"]["cake"] = {
            "candles": {"count": cake.get("candles", 5)},
        }
    return migrated


_MIGRATIONS: dict[int, Migration] = {
    0: _legacy_v0,
}


def migrate(data: dict[str, Any]) -> dict[str, Any]:
    """Return a v{CURRENT} dict, raising on future versions or bad input."""
    if not isinstance(data, dict):
        raise ValueError("配置档根节点必须是对象")
    version = data.get("schema_version")
    if version is None:
        # A file with no version at all is treated as the V0.1 legacy layout.
        version = 0
    try:
        version = int(version)
    except (TypeError, ValueError) as exc:
        raise ValueError(f"schema_version 非法：{version!r}") from exc
    if version > SCHEMA_VERSION:
        raise SchemaTooNew(version)
    current = copy.deepcopy(data)
    while version < SCHEMA_VERSION:
        fn = _MIGRATIONS.get(version)
        if fn is None:
            raise ValueError(f"缺少 v{version} -> v{version + 1} 的迁移器")
        current = fn(current)
        version = int(current.get("schema_version", version + 1))
    current["schema_version"] = SCHEMA_VERSION
    return current
