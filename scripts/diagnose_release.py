#!/usr/bin/env python3
"""Standalone diagnostic for a BirthdayStudio release folder (stdlib only).

Put the built BirthdayStudioDiagnose.exe next to BirthdayStudioPlayer.exe and
run it. It exercises the packaged app/bats, collects environment and log data,
and writes 诊断报告.txt next to the package (or on the Desktop/TEMP).
"""

from __future__ import annotations

import argparse
import csv
import ctypes
import datetime as _dt
import hashlib
import locale
import os
import platform
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

APP_EXE = "BirthdayStudioPlayer.exe"
DEBUG_EXE = "BirthdayStudioPlayerDebug.exe"
BATS = ("启动示例.bat", "启动演出.bat", "打开编辑器.bat", "start_show.bat", "open_editor.bat")
REPORT_NAME = "诊断报告.txt"


def _decode(data: bytes | None) -> str:
    if not data:
        return ""
    for enc in ("utf-8-sig", "utf-8", locale.getpreferredencoding(False), "gbk", "latin-1"):
        try:
            text = data.decode(enc)
            if "\ufffd" not in text:
                return text
        except (UnicodeDecodeError, LookupError):
            continue
    return data.decode("utf-8", "replace")


def _tail(path: Path, n: int = 80) -> str:
    try:
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        return "\n".join(lines[-n:])
    except OSError:
        return ""


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def _zone(path: Path) -> str:
    try:
        with open(str(path) + ":Zone.Identifier", "r", encoding="utf-8", errors="replace") as f:
            return f.read().strip()
    except OSError:
        return ""


class Diag:
    def __init__(self, root: Path) -> None:
        self.root = root
        self.lines: list[str] = []
        self.failures: list[str] = []
        self.app_exe = self._detect_exe()
        self.profile_dir = self._detect_profile()

    def _detect_exe(self) -> Path | None:
        direct = self.root / APP_EXE
        if direct.is_file():
            return direct
        # Editor exports rename the player to the gift name; the real player
        # is the largest exe in the folder (diagnostic/debug builds excluded).
        excluded = {APP_EXE, DEBUG_EXE, "BirthdayStudioDiagnose.exe"}
        candidates = [
            p for p in self.root.glob("*.exe") if p.name not in excluded and p.is_file()
        ]
        return max(candidates, key=lambda p: p.stat().st_size) if candidates else None

    def _detect_profile(self) -> Path | None:
        for rel in ("demo-profile", "profile"):
            if (self.root / rel / "profile.json").is_file():
                return self.root / rel
        return None

    # ------------------------------------------------------------------ #
    def log(self, msg: str = "") -> None:
        print(msg, flush=True)
        self.lines.append(msg)

    def section(self, title: str) -> None:
        self.log("")
        self.log("=" * 64)
        self.log(title)
        self.log("=" * 64)

    def check(self, name: str, ok: bool, detail: str = "") -> None:
        self.log(f"[{'PASS' if ok else 'FAIL'}] {name}" + (f" — {detail}" if detail else ""))
        if not ok:
            self.failures.append(name + (f": {detail}" if detail else ""))

    def run(
        self,
        args: list[str],
        *,
        timeout: int = 90,
        cwd: Path | None = None,
        env: dict[str, str] | None = None,
        capture: bool = True,
    ) -> tuple[int | None, str, str, float]:
        started = time.time()
        kwargs: dict = {
            "cwd": str(cwd or self.root),
            "env": env,
            "timeout": timeout,
            "stdin": subprocess.DEVNULL,
        }
        if capture:
            kwargs["stdout"] = subprocess.PIPE
            kwargs["stderr"] = subprocess.PIPE
        else:
            kwargs["stdout"] = subprocess.DEVNULL
            kwargs["stderr"] = subprocess.DEVNULL
        if os.name == "nt":
            kwargs["creationflags"] = getattr(subprocess, "CREATE_NO_WINDOW", 0)
        try:
            r = subprocess.run(args, **kwargs)
            return r.returncode, _decode(r.stdout), _decode(r.stderr), time.time() - started
        except subprocess.TimeoutExpired as exc:
            return None, _decode(exc.stdout), _decode(exc.stderr), time.time() - started
        except OSError as exc:
            return None, "", str(exc), time.time() - started

    # ------------------------------------------------------------------ #
    def player_pids(self) -> set[int]:
        rc, out, _err, _dt_ = self.run(
            ["tasklist", "/FI", "IMAGENAME eq BirthdayStudioPlayer.exe", "/FO", "CSV", "/NH"],
            timeout=20,
        )
        pids: set[int] = set()
        for row in csv.reader(out.splitlines()):
            if len(row) >= 2 and APP_EXE.lower() in row[0].lower():
                try:
                    pids.add(int(row[1]))
                except ValueError:
                    pass
        return pids

    def kill_pids(self, pids: set[int]) -> None:
        for pid in sorted(pids):
            self.run(["taskkill", "/PID", str(pid), "/F"], timeout=15)

    # ------------------------------------------------------------------ #
    def system(self) -> None:
        self.section("一、系统环境")
        self.log(f"时间: {_dt.datetime.now().astimezone().isoformat(timespec='seconds')}")
        self.log(f"系统: {platform.platform()}")
        self.log(f"版本: {platform.version()} 架构: {platform.machine()} 处理器: {platform.processor()}")
        try:
            wv = sys.getwindowsversion()
            self.log(f"Windows: major={wv.major} minor={wv.minor} build={wv.build} service_pack={wv.service_pack}")
            if wv.major == 10 and wv.build < 17763:
                self.check("Windows 版本受支持", False, f"build {wv.build} < 17763（Windows 10 1809）")
            else:
                self.check("Windows 版本受支持", True, f"build {wv.build}")
        except Exception as exc:
            self.log(f"Windows 版本读取失败: {exc}")
        try:
            admin = bool(ctypes.windll.shell32.IsUserAnAdmin())
        except Exception:
            admin = False
        self.log(f"管理员权限: {admin}")
        self.log(f"Python: {sys.version.split()[0]}  frozen={getattr(sys, 'frozen', False)}")
        self.log(f"首选编码: {locale.getpreferredencoding(False)}  cwd={os.getcwd()}")
        self.log(f"EXE 目录: {Path(sys.executable).resolve().parent}")
        self.log(f"包目录: {self.root}")

        for label, env_key in (("TEMP", "TEMP"), ("APPDATA", "APPDATA"), ("LOCALAPPDATA", "LOCALAPPDATA")):
            value = os.environ.get(env_key, "")
            self.log(f"{label}: {value}")
        for label, path in (
            ("包所在盘", self.root),
            ("%TEMP%", Path(tempfile.gettempdir())),
            ("%APPDATA%", Path(os.environ.get("APPDATA", tempfile.gettempdir()))),
        ):
            try:
                usage = shutil.disk_usage(path)
                free_gb = usage.free / (1024 ** 3)
                self.log(f"磁盘 {label}: 可用 {free_gb:.1f} GB")
                if label == "%TEMP%" and free_gb < 0.5:
                    self.check("临时目录空间", False, f"仅 {free_gb:.2f} GB，onefile 需要解压约 180 MB")
            except OSError as exc:
                self.log(f"磁盘 {label}: 读取失败 {exc}")
        try:
            probe = Path(tempfile.gettempdir()) / "bs-diag-write-test.txt"
            probe.write_text("ok", encoding="utf-8")
            probe.unlink()
            self.check("临时目录可写", True)
        except OSError as exc:
            self.check("临时目录可写", False, str(exc))
        for key in ("PATH", "QT_QPA_PLATFORM", "PYTHONHOME", "PYTHONPATH", "QT_PLUGIN_PATH"):
            self.log(f"{key}={os.environ.get(key, '')}")

    def files(self) -> None:
        self.section("二、文件检查")
        if self.app_exe is not None:
            size = self.app_exe.stat().st_size
            self.log(f"主程序: {self.app_exe.name}  {size} bytes  sha256={_sha256(self.app_exe)}")
            self.check("主程序存在", True, f"{self.app_exe.name}（{size / (1024**2):.1f} MiB）")
            zone = _zone(self.app_exe)
            if zone:
                self.log(f"  Zone.Identifier: {zone}")
        else:
            self.check("主程序存在", False, "没有找到 BirthdayStudioPlayer.exe 或礼物 exe")
        debug = self.root / DEBUG_EXE
        if not debug.exists():
            debug = Path(sys.executable).resolve().parent / DEBUG_EXE
        if debug.exists():
            self.log(f"调试版: {debug}  {debug.stat().st_size} bytes")
        for bat in BATS:
            path = self.root / bat
            if path.exists():
                data = path.read_bytes()
                self.log(f"{bat}: {len(data)} bytes")
                self.log("  " + data.decode("utf-8", "replace").replace("\r\n", " | ").replace("\n", " | "))
                if any(b > 127 for b in data):
                    self.log(f"注意: {bat} 含非 ASCII 字节；cmd 可能因代码页解析失败。")
            else:
                self.log(f"{bat}: 不存在")
        version = self.root / "VERSION.txt"
        if version.exists():
            self.log(f"VERSION.txt: {version.read_text(encoding='utf-8', errors='replace').strip()}")
        if self.profile_dir is not None:
            prof = self.profile_dir / "profile.json"
            self.log(f"配置档: {prof}")
            self.check(f"{self.profile_dir.name}/profile.json 存在", True)
            try:
                import json

                data = json.loads(prof.read_text(encoding="utf-8"))
                audio = data.get("global", {}).get("audio", {})
                self.log(f"  主题: {data.get('meta', {}).get('theme')}  audio keys={sorted(audio)}")
                self.log(f"  voice={audio.get('voice')}")
            except Exception as exc:
                self.check(f"{self.profile_dir.name} 可解析", False, str(exc))
        else:
            self.check("配置档存在", False, "没有找到 demo-profile/ 或 profile/")
        for path in [self.app_exe, self.profile_dir and (self.profile_dir / "profile.json")] + [
            self.root / bat for bat in BATS
        ]:
            if path is None or not path.exists():
                continue
            zone = _zone(path)
            if zone:
                self.log(f"注意: {path.name} 带网络标记（Zone.Identifier），可能被 SmartScreen 拦截；右键属性→解除锁定。")

    # ------------------------------------------------------------------ #
    def _env(self, home: Path) -> dict[str, str]:
        env = os.environ.copy()
        env["BIRTHDAY_STUDIO_HOME"] = str(home)
        env.pop("PYTHONHOME", None)
        env.pop("PYTHONPATH", None)
        return env

    def _logtail(self, home: Path, label: str) -> None:
        log = home / "logs" / "app.log"
        text = _tail(log, 60)
        if text:
            self.log(f"--- {label} app.log 末尾 ---")
            self.log(text)
        else:
            self.log(f"--- {label} 没有 app.log ---")

    def test_exe_version(self, exe: Path, label: str, env: dict[str, str]) -> bool:
        self.section(f"{label} --version")
        rc, out, err, secs = self.run([str(exe), "--version"], timeout=120, env=env)
        self.log(f"返回码: {rc}  耗时: {secs:.1f}s")
        if out.strip():
            self.log("stdout:\n" + out.strip())
        if err.strip():
            self.log("stderr:\n" + err.strip())
        # A windowed PyInstaller build may not attach stdout; rc is the
        # authoritative check, the version string is a bonus.
        ok = rc == 0
        self.check(f"{label} --version", ok, f"rc={rc}" + ("" if out.strip() else "（stdout 为空，窗口化构建正常）"))
        return ok

    def test_screenshot(self, exe: Path, label: str, args: list[str], home: Path, shot: Path) -> bool:
        self.section(f"{label} 截图启动")
        env = self._env(home)
        rc, out, err, secs = self.run(
            [str(exe), *args, "--screenshot", str(shot), "--screenshot-delay", "4500"],
            timeout=150,
            env=env,
        )
        self.log(f"返回码: {rc}  耗时: {secs:.1f}s")
        if out.strip():
            self.log("stdout:\n" + out.strip())
        if err.strip():
            self.log("stderr:\n" + err.strip())
        self._logtail(home, label)
        ok = rc == 0 and shot.exists() and shot.stat().st_size > 1000
        self.check(f"{label} 截图生成", ok, f"rc={rc} shot={shot.exists()}")
        return ok

    def test_bat(self, bat: Path, label: str, home: Path) -> bool:
        self.section(f"{label}")
        if not bat.exists():
            self.check(label, False, "bat 不存在")
            return False
        env = self._env(home)
        before = self.player_pids()
        self.log(f"启动前 BirthdayStudioPlayer 进程: {sorted(before) or '无'}")
        rc, out, err, secs = self.run(["cmd", "/c", bat.name], timeout=45, env=env, capture=False)
        self.log(f"cmd 返回码: {rc}  耗时: {secs:.1f}s（bat 使用 start，返回快是正常现象）")
        time.sleep(15)
        after = self.player_pids()
        new = after - before
        self.log(f"启动后 BirthdayStudioPlayer 进程: {sorted(after) or '无'}")
        self.log(f"新增进程: {sorted(new) or '无'}")
        self._logtail(home, label)
        ok = bool(new)
        self.check(f"{label} 拉起进程", ok, f"新增 PID={sorted(new)}")
        if new:
            self.log("正在结束诊断启动的进程…")
            self.kill_pids(new)
        return ok

    # ------------------------------------------------------------------ #
    def logs(self) -> None:
        self.section("三、真实应用日志")
        real_home = Path(os.environ.get("APPDATA", "")) / "BirthdayStudio"
        log = real_home / "logs" / "app.log"
        self.log(f"日志: {log}")
        text = _tail(log, 80)
        self.log(text if text else "（不存在或为空）")

    def events(self) -> None:
        self.section("四、Windows 事件（最近的错误/拦截）")
        for label, log_name in (
            ("应用程序错误", "Application"),
            ("Defender 防护", "Microsoft-Windows-Windows Defender/Operational"),
        ):
            rc, out, err, _secs = self.run(
                ["wevtutil", "qe", log_name, "/c:80", "/rd:true", "/f:text"],
                timeout=40,
            )
            if rc != 0:
                self.log(f"{label}: 查询失败 rc={rc} {err.strip()[:200]}")
                continue
            hits = [
                line
                for line in out.splitlines()
                if "BirthdayStudio" in line or "BirthdayStudioPlayer" in line
            ]
            if hits:
                self.log(f"{label} 命中 {len(hits)} 行:")
                self.log("\n".join(hits[-30:]))
            else:
                self.log(f"{label}: 最近 80 条中没有 BirthdayStudio 记录")

    def antivirus(self) -> None:
        self.section("五、安全软件")
        script = (
            "Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct "
            "| Select-Object displayName,productState | ConvertTo-Json -Compress"
        )
        rc, out, err, _secs = self.run(
            ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", script],
            timeout=30,
        )
        if rc == 0 and out.strip():
            self.log(out.strip())
        else:
            self.log(f"无法查询安全软件（rc={rc}）：{err.strip()[:200]}")

    # ------------------------------------------------------------------ #
    def conclusion(self, results: dict[str, bool], skip_gui: bool = False) -> None:
        self.section("六、结论")
        if not results.get("version", False):
            self.log("主程序在 Python/启动器阶段就失败了。")
            self.log("常见原因：文件被杀软隔离/删除、缺少运行库、系统架构不符、文件损坏、TEMP 不可写。")
            self.log("请把本报告连同包目录文件列表一起发回。")
        elif skip_gui:
            self.log("只完成了版本/文件/日志检查（--skip-gui），未启动图形界面。")
        elif not results.get("editor", False) or not results.get("player", False):
            self.log("exe 能通过 --version，但 Qt/QML 图形启动失败。")
            self.log("请重点看上面的 stderr、app.log 和 Windows 事件；可能是 Qt 平台插件/显卡驱动/D3D11 初始化失败。")
            self.log("可在测试机尝试：set BIRTHDAY_STUDIO_FORCE_2D=1 后重新运行。")
        elif not results.get("bat_show", False) or not results.get("bat_editor", False):
            self.log("exe 直接启动正常，但 bat 启动链路失败。")
            self.log("请检查 cmd 是否被策略限制、bat 是否被杀软拦截、路径是否可访问。")
        else:
            self.log("exe、编辑器、播放器和两个 bat 均能启动并产生进程。")
            self.log("如果双击仍然无界面，优先检查 SmartScreen/杀软首次拦截、窗口是否被最小化到后台，以及是否在 zip 预览里直接双击。")
        if self.failures:
            self.log("")
            self.log("失败项汇总:")
            for item in self.failures:
                self.log(f"- {item}")

    # ------------------------------------------------------------------ #
    def write_report(self) -> Path:
        content = "\n".join(self.lines) + "\n"
        candidates = [
            self.root / REPORT_NAME,
            Path.home() / "Desktop" / REPORT_NAME,
            Path(tempfile.gettempdir()) / REPORT_NAME,
        ]
        for path in candidates:
            try:
                path.write_text(content, encoding="utf-8-sig")
                return path
            except OSError:
                continue
        return Path(tempfile.gettempdir()) / REPORT_NAME

    def run_all(self, skip_gui: bool = False) -> int:
        self.system()
        self.files()
        exe = self.app_exe
        debug = self.root / DEBUG_EXE
        if not debug.exists():
            # The console debug build may sit next to the diagnostic tool
            # instead of inside the release folder.
            debug = Path(sys.executable).resolve().parent / DEBUG_EXE
        work = Path(tempfile.mkdtemp(prefix="bs-diag-"))
        results: dict[str, bool] = {}
        if exe is not None:
            env = self._env(work / "home-version")
            results["version"] = self.test_exe_version(exe, exe.name, env)
            if not skip_gui and results["version"]:
                results["editor"] = self.test_screenshot(
                    exe,
                    "主程序默认启动",
                    [],
                    work / "home-editor",
                    work / "editor.png",
                )
                if self.profile_dir is not None:
                    results["player"] = self.test_screenshot(
                        exe,
                        "播放器",
                        ["--play", str(self.profile_dir), "--windowed"],
                        work / "home-player",
                        work / "player.png",
                    )
                else:
                    results["player"] = False
                    self.check("播放器配置档", False, "没有找到 demo-profile/ 或 profile/")
                show_bat = next(
                    (
                        self.root / n
                        for n in ("启动示例.bat", "启动演出.bat", "start_show.bat")
                        if (self.root / n).is_file()
                    ),
                    None,
                )
                if show_bat is not None:
                    results["bat_show"] = self.test_bat(
                        show_bat, f"bat {show_bat.name}", work / "home-bat-show"
                    )
                else:
                    results["bat_show"] = False
                    self.check("启动 bat", False, "没有找到 启动示例.bat / 启动演出.bat")
                editor_bat = next(
                    (
                        self.root / n
                        for n in ("打开编辑器.bat", "open_editor.bat")
                        if (self.root / n).is_file()
                    ),
                    None,
                )
                if editor_bat is not None:
                    results["bat_editor"] = self.test_bat(
                        editor_bat, f"bat {editor_bat.name}", work / "home-bat-editor"
                    )
                elif self.profile_dir is not None and self.profile_dir.name == "profile":
                    # A gift export has no editor launcher; that is normal.
                    results["bat_editor"] = True
                    self.log("礼物包没有「打开编辑器.bat」，正常。")
                else:
                    results["bat_editor"] = False
        else:
            results["version"] = False
            self.check("主程序存在", False, "找不到 BirthdayStudioPlayer.exe 或礼物 exe")
        if debug.exists() and not skip_gui:
            denv = self._env(work / "home-debug")
            self.test_exe_version(debug, DEBUG_EXE, denv)
            self.test_screenshot(
                debug,
                DEBUG_EXE + " 编辑器",
                [],
                work / "home-debug-editor",
                work / "debug-editor.png",
            )
        self.logs()
        self.events()
        self.antivirus()
        self.conclusion(results, skip_gui=skip_gui)
        report = self.write_report()
        self.log("")
        self.log(f"报告已写入: {report}")
        return 0 if not self.failures else 1


def main() -> int:
    parser = argparse.ArgumentParser(description="BirthdayStudio 发布包诊断工具")
    parser.add_argument("--dir", default="", help="包目录（默认：本 exe 所在目录）")
    parser.add_argument("--skip-gui", action="store_true", help="只做版本/文件/日志检查，不启动图形界面")
    parser.add_argument("--no-pause", action="store_true", help="结束后不等待回车")
    args = parser.parse_args()
    root = Path(args.dir).expanduser().resolve() if args.dir else Path(sys.executable).resolve().parent
    diag = Diag(root)
    print(f"BirthdayStudio 诊断工具\n包目录: {root}\n", flush=True)
    try:
        rc = diag.run_all(skip_gui=args.skip_gui)
    except Exception as exc:
        import traceback

        diag.log("诊断工具自身异常:")
        diag.log(traceback.format_exc())
        report = diag.write_report()
        print(f"报告已写入: {report}", flush=True)
        rc = 2
    if not args.no_pause:
        try:
            input("按回车退出…")
        except EOFError:
            pass
    return rc


if __name__ == "__main__":
    raise SystemExit(main())
