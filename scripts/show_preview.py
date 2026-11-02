"""Render ShowStage frames to PNG for visual iteration (dev tool)."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PySide6.QtCore import QTimer, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickWindow
import shiboken6

PROJECT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT))

from app.backend.app_bridge import AppBridge  # noqa: E402
from app.backend.bridges import LibraryBridge  # noqa: E402
from app.backend.session_bridge import SessionBridge  # noqa: E402
from app.backend.show_bridge import ShowBridge  # noqa: E402
from app.backend.theme_bridge import ColorTools, ThemeBridge  # noqa: E402
from app.core.audio import AudioEngine  # noqa: E402
from app.core.plugin_manager import PluginManager  # noqa: E402
from app.core.profile_store import ProfileStore  # noqa: E402
from app.core.settings import Settings  # noqa: E402
from app.core.tokens import TokenResolver  # noqa: E402


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("profile_id")
    parser.add_argument("--start", default="confirm")
    parser.add_argument("--out", default=".tests")
    parser.add_argument("--confirm-at", type=int, default=2600)
    parser.add_argument("--grabs", default="3000,3600,4600")
    parser.add_argument("--size", default="1280x720")
    parser.add_argument("--no-auto", action="store_true")
    parser.add_argument("--tag", default="")
    parser.add_argument("--qml", default="tests/qml/show.qml")
    parser.add_argument("--blow-at", type=int, default=0)
    parser.add_argument("--action-at", type=int, default=0)
    args = parser.parse_args()

    app = QGuiApplication(sys.argv[:1])
    store = ProfileStore()
    settings = Settings()
    resolver = TokenResolver()
    plugins = PluginManager(list(settings.get("plugins.enabled", [])))
    plugins.scan()
    theme = ThemeBridge(resolver)
    theme.plugin_provider = lambda ids: plugins.token_deltas(ids)
    audio = AudioEngine()
    show = ShowBridge(audio, plugins)
    session = SessionBridge(store, settings, theme, resolver, plugins)
    library = LibraryBridge(store, settings)
    app_bridge = AppBridge(
        mode="editor",
        play_arg="",
        store=store,
        settings=settings,
        theme=theme,
        session=session,
        library=library,
        show=show,
        audio=audio,
        plugins=plugins,
    )
    profile, _ = store.load_path(store.dir_of(args.profile_id) / "profile.json")
    theme.refresh(profile.meta.theme, profile.token_overrides, False, False, profile.plugins)
    show.setProfileDir(str(store.dir_of(args.profile_id)))
    show.setPluginIds(profile.plugins)

    colors = ColorTools()
    engine = QQmlApplicationEngine()
    ctx = engine.rootContext()
    ctx.setContextProperty("app", app_bridge)
    ctx.setContextProperty("theme", theme)
    ctx.setContextProperty("session", session)
    ctx.setContextProperty("library", library)
    ctx.setContextProperty("audio", audio)
    ctx.setContextProperty("showBridge", show)
    ctx.setContextProperty("colors", colors)
    engine.load(QUrl.fromLocalFile(str(PROJECT / args.qml)))
    if not engine.rootObjects():
        print("QML load failed")
        return 2
    root = engine.rootObjects()[0]
    if not isinstance(root, QQuickWindow):
        root = shiboken6.wrapInstance(shiboken6.getCppPointer(root)[0], QQuickWindow)
    print("root type", type(root), flush=True)
    root.setProperty("testProfile", profile.dump())
    root.setProperty("startAt", args.start)
    root.setProperty("confirmAt", args.confirm_at)
    root.setProperty("blowAt", args.blow_at)
    root.setProperty("actionAt", args.action_at)
    root.setProperty("autoRun", not args.no_auto)
    w, h = (int(x) for x in args.size.lower().split("x"))
    root.setProperty("width", w)
    root.setProperty("height", h)

    grabs = [int(x) for x in args.grabs.split(",") if x.strip()]
    tag = f"{args.tag}_" if args.tag else ""

    def grab(index: int, ms: int) -> None:
        img = root.grabWindow()
        out = PROJECT / args.out / f"{tag}frame_{index}_{ms}.png"
        out.parent.mkdir(parents=True, exist_ok=True)
        img.save(str(out), "PNG")
        print("saved", out, flush=True)

    for i, ms in enumerate(grabs):
        QTimer.singleShot(ms, lambda i=i, ms=ms: grab(i, ms))
    QTimer.singleShot(max(grabs) + 900, app.quit)
    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
