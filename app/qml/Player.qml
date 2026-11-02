import QtQuick
import QtQuick.Controls
import "show"
import "components"

Item {
    id: player
    anchors.fill: parent

    property bool startedOnce: false

    ShowStage {
        id: showStage
        anchors.fill: parent
        profile: app.playerProfile
        tokens: theme.tokens
        autoStart: false
        onCloseRequested: app.closePlayer()
        onToast: function (message) { toast.show(message) }
    }

    AudioBar {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 22
        anchors.topMargin: 20
        tokens: theme.tokens
    }

    SkipButton {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 24
        anchors.bottomMargin: 24
        tokens: theme.tokens
        visibleHint: showStage.canSkip && (app.playerProfile.global && app.playerProfile.global.skip ? app.playerProfile.global.skip.show_button !== false : true)
        onClicked: showStage.skipCurrent()
    }

    Toast {
        id: toast
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
    }

    // error / loading
    Rectangle {
        anchors.fill: parent
        color: "#0d0812"
        visible: !app.playerReady
        Text {
            anchors.centerIn: parent
            width: Math.min(parent.width * 0.8, 760)
            text: app.playerError !== ""
                  ? "无法开始演出\n\n" + app.playerError
                  : "正在准备今晚的祝福…"
            color: "#f5ede8"
            font.family: theme.hanFamily
            font.pixelSize: 18
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            lineHeight: 1.6
        }
        MouseArea {
            anchors.fill: parent
            onClicked: if (app.playerError !== "") app.closePlayer()
        }
    }

    function beginShow() {
        if (startedOnce || !app.playerReady)
            return
        startedOnce = true
        showStage.start("")
    }

    Connections {
        target: app
        function onPlayerChanged() { player.beginShow() }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: app.closePlayer()
    }
    Shortcut {
        sequence: "F5"
        onActivated: showStage.restart()
    }

    Component.onCompleted: beginShow()
}
