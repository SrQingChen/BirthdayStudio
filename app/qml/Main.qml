import QtQuick
import QtQuick.Controls
import QtQuick.Window

ApplicationWindow {
    id: window

    visible: true
    title: app.isPlayer ? "生日祝福" : "BirthdayStudio · 生贺演出终端"
    width: 1440
    height: 900
    color: app.isPlayer ? "#000000" : ((theme.tokens.ui && theme.tokens.ui.panel) ? theme.tokens.ui.panel : "#171020")
    flags: app.isPlayer ? (Qt.FramelessWindowHint | Qt.Window) : Qt.Window
    visibility: app.isPlayer && !app.windowedPlayer ? Window.FullScreen : Window.Windowed

    Loader {
        anchors.fill: parent
        source: app.isPlayer ? "Player.qml" : "Editor.qml"
        asynchronous: false
    }

    Component.onCompleted: {
        if (!app.isPlayer) {
            var g = app.windowGeometry || {}
            if (g.width > 900 && g.height > 600) {
                width = g.width
                height = g.height
                x = g.x
                y = g.y
                if (g.maximized)
                    showMaximized()
            }
        }
    }

    onClosing: function (close) {
        if (!app.isPlayer)
            app.saveWindowGeometry(x, y, width, height, visibility === Window.Maximized)
    }
}
