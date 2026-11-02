"""Filesystem contract for BirthdayStudio.

All persistent data lives under ``%APPDATA%/BirthdayStudio`` unless
``BIRTHDAY_STUDIO_HOME`` is set (used by tests and portable distributions).
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

APP_NAME = "BirthdayStudio"
_FROZEN = bool(getattr(sys, "frozen", False)) or "__compiled__" in globals()
# Where the executable lives (external plugins/licences when packaged).
PROJECT_ROOT = Path(sys.executable).resolve().parent if _FROZEN else Path(__file__).resolve().parent.parent.parent
# Where read-only bundled data lives (PyInstaller onefile extracts to _MEIPASS).
BUNDLE_ROOT = Path(getattr(sys, "_MEIPASS", PROJECT_ROOT)) if _FROZEN else PROJECT_ROOT
RESOURCES_DIR = BUNDLE_ROOT / "resources"
QML_DIR = BUNDLE_ROOT / "app" / "qml"


def _default_home() -> Path:
    env = os.environ.get("BIRTHDAY_STUDIO_HOME")
    if env:
        return Path(env).expanduser().resolve()
    appdata = os.environ.get("APPDATA")
    if appdata:
        return Path(appdata) / APP_NAME
    return Path.home() / f".{APP_NAME.lower()}"


HOME_DIR = _default_home()
PROFILES_DIR = HOME_DIR / "profiles"
TRASH_DIR = HOME_DIR / "trash"
PLUGINS_DIR = HOME_DIR / "plugins"
LOGS_DIR = HOME_DIR / "logs"
SETTINGS_PATH = HOME_DIR / "settings.json"
THEMES_DIR = RESOURCES_DIR / "themes"
TOKENS_PATH = RESOURCES_DIR / "design-tokens.json"
FONTS_DIR = RESOURCES_DIR / "fonts"
BUILTIN_AUDIO_DIR = RESOURCES_DIR / "audio"
BUILTIN_TEXTURE_DIR = RESOURCES_DIR / "textures"


def ensure_home() -> None:
    for p in (HOME_DIR, PROFILES_DIR, TRASH_DIR, PLUGINS_DIR, LOGS_DIR):
        p.mkdir(parents=True, exist_ok=True)


def profile_dir(profile_id: str) -> Path:
    return PROFILES_DIR / profile_id


def is_within(child: Path, parent: Path) -> bool:
    try:
        child.resolve().relative_to(parent.resolve())
        return True
    except ValueError:
        return False


def packaged_plugins_dir() -> Path:
    """Bundled example plugins (inside the PyInstaller/Nuitka bundle)."""
    return BUNDLE_ROOT / "plugins"
