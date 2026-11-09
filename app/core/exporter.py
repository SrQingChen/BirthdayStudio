"""Export & distribution (X-01 … X-06).

Default form: prebuilt Player.exe + profile/ + launcher inside a folder/zip.
If no prebuilt player exists, a clearly-labelled dev launcher is emitted so
the workflow is still testable end to end.
"""

from __future__ import annotations

import json
import re
import shutil
import sys
import zipfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from ..config.io import atomic_write_json
from ..config.schema import Profile, now_iso
from .paths import BUNDLE_ROOT, PROJECT_ROOT

SOURCE_URL = "https://github.com/SrQingChen/BirthdayStudio"
PLAYER_CANDIDATES = [
    PROJECT_ROOT / "dist" / "BirthdayStudioPlayer.exe",
    PROJECT_ROOT / "dist" / "Player.exe",
    PROJECT_ROOT / "build" / "player" / "BirthdayStudioPlayer.exe",
]


def _safe_filename(name: str, fallback: str = "生日礼物") -> str:
    cleaned = re.sub(r'[<>:"/\\|?*\x00-\x1f]', "", name).strip().strip(".")
    return cleaned or fallback


@dataclass
class ExportOptions:
    form: str = "folder"  # folder | single
    exe_name: str = ""
    icon_path: str = ""
    include_profile_bbp: bool = True
    license_confirmations: dict[str, str] = field(default_factory=dict)
    copyright_confirmed: bool = False
    destination: str = ""


class Exporter:
    def __init__(self, store, plugins) -> None:
        self.store = store
        self.plugins = plugins

    def find_player(self) -> Path | None:
        if getattr(sys, "frozen", False):
            exe = Path(sys.executable)
            if exe.suffix.lower() == ".exe":
                return exe
        for candidate in PLAYER_CANDIDATES:
            if candidate.exists():
                return candidate
        return None

    def export(
        self,
        profile: Profile,
        destination: Path,
        options: ExportOptions,
        *,
        tokens: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        destination = Path(destination)
        destination.mkdir(parents=True, exist_ok=True)
        for pid in profile.plugins:
            self.plugins.set_enabled(pid, True)
        honoree = _safe_filename(profile.meta.honoree, "你")
        default_exe = f"给{honoree}的生日礼物"
        stem = _safe_filename(options.exe_name, default_exe)
        package = destination / stem
        if package.exists():
            shutil.rmtree(package)
        package.mkdir(parents=True, exist_ok=True)

        # ---- profile copy (no journal / snapshots / trash metadata) ------
        src = self.store.dir_of(profile.id)
        profile_dst = package / "profile"
        profile_dst.mkdir(parents=True, exist_ok=True)
        for p in src.rglob("*"):
            if not p.is_file():
                continue
            rel = p.relative_to(src)
            if rel.name in {"journal.jsonl", "trash.json"} or "snapshots" in rel.parts:
                continue
            if rel.suffix == ".tmp":
                continue
            target = profile_dst / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(p, target)
        # ensure the exported profile carries the enabled plugin ids
        raw = json.loads((profile_dst / "profile.json").read_text(encoding="utf-8"))
        raw["plugins"] = [p["id"] for p in self.plugins.enabled_plugins()]
        atomic_write_json(profile_dst / "profile.json", raw)

        # ---- player binary ------------------------------------------------
        # Keep the executable name ASCII even when the gift folder is Chinese:
        # cmd's batch parser is code-page sensitive, and a UTF-8 Chinese exe
        # name inside 启动演出.bat made the launcher flash and exit on some
        # Windows configurations.
        player = self.find_player()
        exe_name = "BirthdayStudioPlayer.exe"
        used_prebuilt = False
        if player is not None:
            shutil.copy2(player, package / exe_name)
            used_prebuilt = True

        # ---- plugins embedded --------------------------------------------
        plugin_root = package / "plugins"
        for p in self.plugins.enabled_plugins():
            target = plugin_root / p["id"]
            if p["path"].exists():
                shutil.copytree(p["path"], target, dirs_exist_ok=True)

        # ---- launcher -----------------------------------------------------
        if used_prebuilt:
            # Pure ASCII + relative paths: the launcher works from Chinese,
            # spaced and long paths without depending on the console code page.
            bat = (
                "@echo off\r\n"
                'cd /d "%~dp0"\r\n'
                'if not exist "BirthdayStudioPlayer.exe" (\r\n'
                "    echo [ERROR] BirthdayStudioPlayer.exe not found.\r\n"
                "    echo Please extract the whole gift package again.\r\n"
                "    pause\r\n"
                "    exit /b 1\r\n"
                ")\r\n"
                'if not exist "profile\\profile.json" (\r\n'
                "    echo [ERROR] profile\\profile.json not found.\r\n"
                "    echo Please extract the whole gift package again.\r\n"
                "    pause\r\n"
                "    exit /b 1\r\n"
                ")\r\n"
                'start "" "BirthdayStudioPlayer.exe" --play "profile"\r\n'
            )
            readme_note = "双击 BirthdayStudioPlayer.exe 或 启动演出.bat 即可开始。"
            if options.form == "single":
                readme_note += "\n（单文件专用构建未启用，已按「播放器 + 配置包」形态导出。）"
        else:
            py = str(Path(sys.executable))
            proj = str(PROJECT_ROOT)
            bat = (
                "@echo off\r\n"
                "chcp 65001 >nul\r\n"
                "rem Development launcher: Python 3.10+ and dependencies required.\r\n"
                "rem Build dist/BirthdayStudioPlayer.exe for a standalone distribution.\r\n"
                f'pushd "{proj}"\r\n'
                f'"{py}" -m app --play "%~dp0profile"\r\n'
                "popd\r\n"
                "pause\r\n"
            )
            readme_note = (
                "当前包未检测到预编译播放器，使用开发模式启动器（需要 Python 环境）。\n"
                "正式分发前请运行 scripts/build_player.bat 生成 dist/BirthdayStudioPlayer.exe。"
            )
        # write_bytes avoids Windows text-mode newline translation (which
        # turned the intended CRLF into CR CR LF).
        (package / "启动演出.bat").write_bytes(bat.encode("ascii" if used_prebuilt else "utf-8"))

        (package / "README.txt").write_text(
            "生贺演出\n"
            "==========\n\n"
            f"{readme_note}\n\n"
            f"寿星：{profile.meta.honoree}\n"
            f"作者：{profile.meta.author}\n"
            f"导出时间：{now_iso()}\n\n"
            "操作：\n"
            "  · 鼠标点击 / 空格 / 回车：推进仪式\n"
            "  · 右下角“跳过”：跳过当前幕\n"
            "  · 右上角：静音、暂停、音量\n"
            "  · Esc：退出\n\n"
            f"源代码（GPL-3.0）：{SOURCE_URL}\n",
            encoding="utf-8",
        )

        # ---- licenses -----------------------------------------------------
        licenses = package / "LICENSES"
        licenses.mkdir(exist_ok=True)
        self._write_licenses(licenses, profile, options)

        # ---- optional .bbp -------------------------------------------------
        if options.include_profile_bbp:
            try:
                self.store.export_bbp(profile.id, package / "profile.bbp")
            except Exception:
                pass

        # ---- zip -----------------------------------------------------------
        zip_path = destination / f"{stem}.zip"
        if zip_path.exists():
            zip_path.unlink()
        with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
            for p in package.rglob("*"):
                if p.is_file():
                    zf.write(p, arcname=str(p.relative_to(destination)).replace("\\", "/"))

        return {
            "ok": True,
            "packageDir": str(package),
            "zipPath": str(zip_path),
            "usedPrebuilt": used_prebuilt,
            "exeName": exe_name if used_prebuilt else "",
            "sizeBytes": sum(p.stat().st_size for p in package.rglob("*") if p.is_file()),
        }

    def _write_licenses(self, folder: Path, profile: Profile, options: ExportOptions) -> None:
        for base in (PROJECT_ROOT, BUNDLE_ROOT):
            root_license = base / "LICENSE"
            if root_license.exists():
                shutil.copy2(root_license, folder / "GPL-3.0.txt")
                break
        (folder / "SOURCE.txt").write_text(
            "BirthdayStudio 1.0.0\n"
            f"源代码获取：{SOURCE_URL} (tag v1.0.0)\n\n"
            "本分发包包含 GPL-3.0-or-later 许可的 BirthdayStudio 二进制。\n"
            "GPLv3 §6 要求二进制分发同时提供对应源码的获取方式；上述仓库地址即满足该要求。\n"
            "插件接口例外：通过 Stable Slots API 加载的主题插件不视为本作品衍生作品（GPLv3 §7 附加许可）。\n",
            encoding="utf-8",
        )
        (folder / "THIRD-PARTY.md").write_text(
            "第三方组件：\n"
            "- Qt 6 / PySide6 —— LGPLv3（动态链接分发，随包附许可声明）\n"
            "- Pydantic —— MIT\n"
            "- 内置字体 —— SIL OFL 1.1（若随包分发）\n"
            "- 内置合成音效 —— 由本项目脚本生成，随本体 GPL-3.0 发布\n",
            encoding="utf-8",
        )
        (folder / "PROFILE-CONTENT.txt").write_text(
            "配置档内容（文字、图片、音乐、视频）由创作者提供，归创作者所有，\n"
            "不因随 GPL 程序打包而变为 GPL 覆盖作品。\n\n"
            f"配置档：{profile.meta.name}\n作者：{profile.meta.author}\n",
            encoding="utf-8",
        )
        if options.license_confirmations:
            (folder / "ASSET-LICENSES.md").write_text(
                "# 素材版权确认清单\n\n"
                + "\n".join(f"- **{k}**：{v}" for k, v in options.license_confirmations.items())
                + "\n",
                encoding="utf-8",
            )
