"""Build the distributable win64 zip: Player.exe + demo profile + docs + license.

Usage:
    python scripts/package_release.py --version 1.1.0 --exe dist/BirthdayStudioPlayer.exe \
        --demo-dir <dir with profile.json + preview.png>

The demo profile is upgraded through the current Profile schema (so a package
built today carries today's defaults), then exported as both a playable
directory and an editable .bbp package.
"""

from __future__ import annotations

import argparse
import json
import shutil
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys_path_added = False


def _ensure_import_path() -> None:
    global sys_path_added
    if not sys_path_added:
        import sys

        sys.path.insert(0, str(ROOT))
        sys_path_added = True


def _upgrade_profile(profile_dir: Path) -> dict:
    _ensure_import_path()
    from app.config.schema import Profile

    data = json.loads((profile_dir / "profile.json").read_text(encoding="utf-8"))
    profile = Profile.model_validate(data)
    (profile_dir / "profile.json").write_text(
        json.dumps(profile.dump(), ensure_ascii=False, indent=2), encoding="utf-8"
    )
    return profile.dump()


def _write_bbp(profile_dir: Path, profile: dict, dest: Path) -> None:
    meta = profile.get("meta", {})
    meta_payload = {
        "name": meta.get("name", ""),
        "honoree": meta.get("honoree", ""),
        "author": meta.get("author", ""),
        "theme": meta.get("theme", ""),
        "description": meta.get("description", ""),
        "created_at": meta.get("created_at", ""),
        "modified_at": meta.get("modified_at", ""),
    }
    with zipfile.ZipFile(dest, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("profile.json", json.dumps(profile, ensure_ascii=False, indent=2))
        z.writestr("meta.json", json.dumps(meta_payload, ensure_ascii=False, indent=2))
        preview = profile_dir / "preview.png"
        if preview.exists():
            z.write(preview, "preview.png")


USAGE_TXT = """BirthdayStudio {version} · 生贺演出终端
==================================

两种使用方式：

1. 看示例演出
   双击「启动示例.bat」。

2. 制作自己的生日祝福
   双击「打开编辑器.bat」（或直接双击 BirthdayStudioPlayer.exe）。
   首次启动会进入五步向导；也可以从「新建」选择「毛玻璃庆典 / 卡通立体」。
   编辑器内点「导出」即可生成收礼人直接可用的播放器包。

示例配置档
  demo-profile/        播放器直接使用
  示例配置.bbp          在编辑器「导入 .bbp」可再次编辑

演出操作
  开场先点「开启这份祝福」，随后信封与火漆才会亮出
  点击 / 空格 / 回车：推进仪式
  右下角「跳过」：跳过当前幕
  右上角：静音、暂停、音量
  Esc：退出

蛋糕幕
  左右拖动：水平旋转蛋糕（松开后保持角度，带惯性；不会上下翻转）
  点击蛋糕：果冻弹跳（连续点击会叠加）
  逐根点击蜡烛：吹灭，全部熄灭后许愿

祝福幕
  数百枚琉璃便签会沿轨迹连成一条曲线（可在编辑器「蜂群便签」里加文字），
  随后可读的祝福卡依次飞出。

数据目录
  %APPDATA%\\BirthdayStudio
  配置档、自动快照、回收站、插件与日志都在这里。

许可证
  本体 GPL-3.0-or-later + GPLv3 §7 插件接口例外。
  详见 LICENSE 与 LICENSES/（导出包内）。

作者：SrQingChen
"""

LAUNCH_SHOW_BAT = """@echo off
cd /d "%~dp0"
if not exist "BirthdayStudioPlayer.exe" (
    echo [ERROR] BirthdayStudioPlayer.exe not found.
    echo Please extract the whole package again.
    pause
    exit /b 1
)
if not exist "demo-profile\\profile.json" (
    echo [ERROR] demo-profile\\profile.json not found.
    echo Please extract the whole package again.
    pause
    exit /b 1
)
start "" "BirthdayStudioPlayer.exe" --play "demo-profile"
"""

OPEN_EDITOR_BAT = """@echo off
cd /d "%~dp0"
if not exist "BirthdayStudioPlayer.exe" (
    echo [ERROR] BirthdayStudioPlayer.exe not found.
    echo Please extract the whole package again.
    pause
    exit /b 1
)
start "" "BirthdayStudioPlayer.exe"
"""


def build_package(version: str, exe: Path, demo_src: Path, out_root: Path) -> tuple[Path, Path]:
    name = f"BirthdayStudio-{version}-win64"
    stage = out_root / name
    if stage.exists():
        shutil.rmtree(stage)
    stage.mkdir(parents=True)

    shutil.copy2(exe, stage / "BirthdayStudioPlayer.exe")
    (stage / "VERSION.txt").write_text(version + "\n", encoding="utf-8")
    (stage / "使用说明.txt").write_text(USAGE_TXT.format(version=version), encoding="utf-8")
    (stage / "启动示例.bat").write_bytes(LAUNCH_SHOW_BAT.replace("\n", "\r\n").encode("ascii"))
    (stage / "打开编辑器.bat").write_bytes(OPEN_EDITOR_BAT.replace("\n", "\r\n").encode("ascii"))

    demo_dst = stage / "demo-profile"
    shutil.copytree(demo_src, demo_dst)
    shutil.rmtree(demo_dst / "snapshots", ignore_errors=True)
    (demo_dst / "journal.jsonl").unlink(missing_ok=True)
    profile = _upgrade_profile(demo_dst)
    _write_bbp(demo_dst, profile, stage / "示例配置.bbp")

    for f in ("README.md", "LICENSE"):
        src = ROOT / f
        if src.exists():
            shutil.copy2(src, stage / f)
    docs_src = ROOT / "docs"
    if docs_src.exists():
        docs_dst = stage / "docs"
        docs_dst.mkdir()
        for f in docs_src.iterdir():
            if f.is_dir():
                shutil.copytree(f, docs_dst / f.name)
            elif f.suffix.lower() == ".md" and not f.name.startswith("V1.1.0修复方案"):
                shutil.copy2(f, docs_dst / f.name)
    plugins_src = ROOT / "plugins"
    if plugins_src.exists():
        shutil.copytree(plugins_src, stage / "plugins")

    zip_path = out_root / f"{name}.zip"
    if zip_path.exists():
        zip_path.unlink()
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as z:
        for path in sorted(stage.rglob("*")):
            if path.is_file():
                z.write(path, path.relative_to(out_root).as_posix())
    return stage, zip_path


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", required=True)
    ap.add_argument("--exe", default="dist/BirthdayStudioPlayer.exe")
    ap.add_argument("--demo-dir", required=True)
    ap.add_argument("--out", default=str(ROOT))
    args = ap.parse_args()

    exe = (ROOT / args.exe).resolve()
    demo = Path(args.demo_dir).resolve()
    if not exe.exists():
        raise SystemExit(f"player exe not found: {exe}")
    if not (demo / "profile.json").exists():
        raise SystemExit(f"demo profile not found: {demo}")
    out_root = Path(args.out).resolve()
    stage, zip_path = build_package(args.version, exe, demo, out_root)
    size = zip_path.stat().st_size / (1024 * 1024)
    print(f"staged: {stage}")
    print(f"zip   : {zip_path} ({size:.1f} MiB)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
