"""BirthdayStudio entry point: editor by default, `--play <profile>` for the player."""

from __future__ import annotations

import argparse
import os
import logging
import sys
from pathlib import Path

from PySide6.QtCore import QCoreApplication, Qt, QUrl
from PySide6.QtGui import QFontDatabase, QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickWindow
from PySide6.QtQuickControls2 import QQuickStyle
from PySide6.QtWidgets import QApplication

from .backend.app_bridge import APP_VERSION, AppBridge
from .backend.bridges import AudioBridge, ExportBridge, LibraryBridge, PluginBridge
from .backend.session_bridge import SessionBridge
from .backend.show_bridge import ShowBridge
from .backend.theme_bridge import ColorTools, ThemeBridge
from .core.audio import AudioEngine
from .core.exporter import Exporter
from .core.paths import FONTS_DIR, LOGS_DIR, QML_DIR, ensure_home
from .core.plugin_manager import PluginManager
from .core.profile_store import ProfileStore
from .core.settings import Settings
from .core.tokens import TokenResolver

def _setup_logging() -> None:
    ensure_home()
    LOGS_DIR.mkdir(parents=True, exist_ok=True)
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
        handlers=[
            logging.FileHandler(LOGS_DIR / "app.log", encoding="utf-8"),
            logging.StreamHandler(sys.stderr),
        ],
    )


def _load_bundled_fonts() -> list[str]:
    loaded: list[str] = []
    if not FONTS_DIR.exists():
        return loaded
    for path in FONTS_DIR.glob("*"):
        if path.suffix.lower() not in {".ttf", ".otf", ".ttc"}:
            continue
        idx = QFontDatabase.addApplicationFont(str(path))
        if idx >= 0:
            loaded.extend(QFontDatabase.applicationFontFamilies(idx))
    return loaded


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="birthday-studio", description="配置驱动的交互式生贺演出终端")
    parser.add_argument("--play", metavar="PROFILE", default="", help="直接进入播放器：配置档 id、目录、profile.json 或 .bbp 包")
    parser.add_argument("--windowed", action="store_true", help="播放器使用窗口模式（调试用）")
    parser.add_argument("--version", action="version", version=f"BirthdayStudio {APP_VERSION}")
    parser.add_argument("--screenshot", default="", help="开发用：启动后截图到指定路径并退出")
    parser.add_argument("--screenshot-delay", type=int, default=2200)
    parser.add_argument("--dialog", default="", help="开发用：启动后打开指定对话框")
    parser.add_argument("--autoplay", action="store_true", help="开发用：打开配置档后自动试演")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    # A gift package puts the player next to a "profile/" folder. Double-
    # clicking the exe should start the show, not open the editor. Only the
    # frozen build does this; `python -m app` keeps its editor default.
    auto_play = ""
    if not args.play and getattr(sys, "frozen", False):
        sibling = Path(sys.executable).resolve().parent / "profile" / "profile.json"
        if sibling.is_file():
            auto_play = str(sibling.parent)
            args.play = auto_play
    _setup_logging()
    log = logging.getLogger("birthday-studio")
    if auto_play:
        log.info("auto-play from sibling profile: %s", auto_play)

    QGuiApplication.setHighDpiScaleFactorRoundingPolicy(
        Qt.HighDpiScaleFactorRoundingPolicy.PassThrough
    )
    QCoreApplication.setOrganizationName("SrQingChen")
    QCoreApplication.setApplicationName("BirthdayStudio")
    QCoreApplication.setApplicationVersion(APP_VERSION)

    QQuickStyle.setStyle("Basic")
    app = QApplication(sys.argv[:1])
    # If the platform cannot provide a hardware RHI backend, use the 2.5D cake.
    try:
        gfx = QQuickWindow.graphicsApi()
        if gfx.name in {"Software", "Null", "Unknown"}:
            os.environ.setdefault("BIRTHDAY_STUDIO_FORCE_2D", "1")
    except Exception:
        pass
    app.setQuitOnLastWindowClosed(True)
    _load_bundled_fonts()

    settings = Settings()
    store = ProfileStore()
    resolver = TokenResolver()
    plugin_manager = PluginManager(list(settings.get("plugins.enabled", [])))
    plugin_manager.scan()
    theme = ThemeBridge(resolver)
    theme.plugin_provider = lambda ids: plugin_manager.token_deltas(ids)  # type: ignore[attr-defined]
    audio = AudioEngine()
    show = ShowBridge(audio, plugin_manager)
    session = SessionBridge(store, settings, theme, resolver, plugin_manager)
    library = LibraryBridge(store, settings)
    exporter = Exporter(store, plugin_manager)
    export_bridge = ExportBridge(exporter, store)
    plugin_bridge = PluginBridge(plugin_manager, settings)
    colors = ColorTools()
    mode = "player" if args.play else "editor"
    app_bridge = AppBridge(
        mode=mode,
        play_arg=args.play,
        store=store,
        settings=settings,
        theme=theme,
        session=session,
        library=library,
        show=show,
        audio=audio,
        plugins=plugin_manager,
        windowed=args.windowed,
        dev_dialog=args.dialog,
        dev_autoplay=args.autoplay,
    )

    engine = QQmlApplicationEngine()
    engine.addImportPath(str(QML_DIR))
    context = engine.rootContext()
    for name, obj in (
        ("app", app_bridge),
        ("theme", theme),
        ("library", library),
        ("session", session),
        ("audio", audio),
        ("audioBridge", AudioBridge(audio)),
        ("showBridge", show),
        ("exporter", export_bridge),
        ("plugins", plugin_bridge),
        ("colors", colors),
    ):
        context.setContextProperty(name, obj)

    qml_main = QML_DIR / "Main.qml"
    engine.load(QUrl.fromLocalFile(str(qml_main)))
    if not engine.rootObjects():
        log.error("QML 加载失败：%s", qml_main)
        return 2

    app.aboutToQuit.connect(app_bridge.finish)

    if args.screenshot:
        from PySide6.QtCore import QTimer

        def _shot():
            window = engine.rootObjects()[0]
            grab = getattr(window, "grabWindow", None)
            if grab is None:
                log.error("screenshot: root object has no grabWindow")
                app.quit()
                return
            image = grab()
            ok = image.save(args.screenshot, "PNG")
            log.info("screenshot saved=%s path=%s", ok, args.screenshot)
            app.quit()

        QTimer.singleShot(max(300, args.screenshot_delay), _shot)

    log.info("BirthdayStudio %s started in %s mode", APP_VERSION, mode)
    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
