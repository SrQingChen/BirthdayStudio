"""Factory templates and profile instantiation.

"Everything is a profile": a theme is nothing more than a factory profile
template (built-in, or supplied by a theme plugin).  A new profile is created
by deep-merging the theme overlay onto the schema defaults.
"""

from __future__ import annotations

import copy
import json
import uuid
from pathlib import Path
from typing import Any

from ..core.paths import THEMES_DIR
from .schema import SCHEMA_VERSION, Profile, ProfileMeta, now_iso


def deep_merge(base: dict[str, Any], overlay: dict[str, Any]) -> dict[str, Any]:
    """Recursively merge ``overlay`` into a copy of ``base``.

    Lists replace wholesale (sequence order is meaningful), dicts merge.
    """
    out = copy.deepcopy(base)
    for key, value in overlay.items():
        if isinstance(value, dict) and isinstance(out.get(key), dict):
            out[key] = deep_merge(out[key], value)
        else:
            out[key] = copy.deepcopy(value)
    return out


def load_json(path: Path) -> dict[str, Any]:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def list_themes() -> list[dict[str, Any]]:
    themes: list[dict[str, Any]] = []
    if not THEMES_DIR.exists():
        return themes
    for d in sorted(THEMES_DIR.iterdir()):
        tokens_path = d / "tokens.json"
        template_path = d / "template.json"
        if not (tokens_path.exists() and template_path.exists()):
            continue
        try:
            tokens = load_json(tokens_path)
            template = load_json(template_path)
        except (OSError, json.JSONDecodeError):
            continue
        meta = tokens.get("theme", {})
        themes.append(
            {
                "id": meta.get("id", d.name),
                "name": meta.get("name", d.name),
                "tagline": meta.get("tagline", ""),
                "author": meta.get("author", ""),
                "version": meta.get("version", "1.0.0"),
                "style": meta.get("style", "glass"),
                "previewColors": meta.get("previewColors", []),
                "description": template.get("description", ""),
                "dir": str(d),
            }
        )
    themes.sort(key=lambda t: 0 if t["id"] == "glass-celebration" else 1)
    return themes


def theme_dir(theme_id: str) -> Path:
    return THEMES_DIR / theme_id


def load_theme_tokens(theme_id: str) -> dict[str, Any]:
    path = theme_dir(theme_id) / "tokens.json"
    if not path.exists():
        return {}
    return load_json(path)


def load_theme_template(theme_id: str) -> dict[str, Any]:
    path = theme_dir(theme_id) / "template.json"
    if not path.exists():
        return {}
    return load_json(path)


def default_profile_dict(profile_id: str | None = None) -> dict[str, Any]:
    pid = profile_id or uuid.uuid4().hex[:12]
    model = Profile(id=pid, meta=ProfileMeta())
    return model.dump()


def create_profile(
    *,
    theme_id: str = "glass-celebration",
    name: str = "",
    honoree: str = "你",
    author: str = "SrQingChen",
    profile_id: str | None = None,
) -> Profile:
    pid = profile_id or uuid.uuid4().hex[:12]
    template = load_theme_template(theme_id)
    merged = deep_merge(default_profile_dict(pid), template)
    merged["schema_version"] = SCHEMA_VERSION
    merged["id"] = pid
    theme_meta = load_theme_tokens(theme_id).get("theme", {})
    display_name = name or f"给{honoree}的生日祝福"
    merged.setdefault("meta", {})
    merged["meta"].update(
        {
            "name": display_name,
            "honoree": honoree,
            "author": author,
            "theme": theme_id,
            "created_at": now_iso(),
            "modified_at": now_iso(),
        }
    )
    profile = Profile.model_validate(merged)
    # Keep the theme's own copy out of token overrides; tokens are resolved live.
    return profile


def theme_template_preview(theme_id: str) -> dict[str, Any]:
    meta = load_theme_tokens(theme_id).get("theme", {})
    template = load_theme_template(theme_id)
    return {
        "id": theme_id,
        "name": meta.get("name", theme_id),
        "tagline": meta.get("tagline", ""),
        "description": template.get("description", ""),
        "previewColors": meta.get("previewColors", []),
    }
