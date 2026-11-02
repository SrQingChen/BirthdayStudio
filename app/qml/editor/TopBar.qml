import QtQuick
import "../components"

Item {
    id: root

    property bool hasProfile: false
    property bool playing: false
    signal newProfile()
    signal playAll()
    signal playAct()
    signal stop()
    signal exportRequested()
    signal pluginsRequested()
    signal settingsRequested()
    signal snapshotsRequested()
    signal wizardRequested()

    readonly property var ui: (theme.tokens && theme.tokens.ui) ? theme.tokens.ui : ({})
    readonly property color ink: ui.text || "#f5ede8"
    readonly property color muted: ui.textMuted || "#b9a9b6"
    readonly property color accent: ui.accent || "#ffb08a"
    readonly property color dangerColor: ui.danger || "#ff8a80"
    readonly property color borderColor: ui.panelBorder || "#ffffff14"
    readonly property string state: session.saveState
    readonly property color stateColor: state === "failed" ? dangerColor
                                           : state === "dirty" ? "#ffd166"
                                           : state === "saving" ? accent : "#7ee0d0"

    height: 54

    Rectangle {
        anchors.fill: parent
        color: (theme.tokens && theme.tokens.ui && theme.tokens.ui.panel) ? theme.tokens.ui.panel : "#171020"
    }
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: root.borderColor
    }

    // brand
    Rectangle {
        x: 16
        anchors.verticalCenter: parent.verticalCenter
        width: 30
        height: 30
        radius: 9
        color: root.accent
        Text {
            anchors.centerIn: parent
            text: "生"
            color: "#2a1410"
            font.family: theme.serifFamily
            font.pixelSize: 16
            font.weight: Font.DemiBold
        }
    }
    Text {
        x: 54
        anchors.verticalCenter: parent.verticalCenter
        text: "BirthdayStudio"
        color: root.ink
        font.family: theme.hanFamily
        font.pixelSize: 13
        font.weight: Font.DemiBold
        font.letterSpacing: 0.3
    }

    // profile + save state
    Column {
        x: 182
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Text {
            text: root.hasProfile ? (session.draft.meta ? session.draft.meta.name : "未命名") : "未打开配置档"
            color: root.ink
            font.family: theme.hanFamily
            font.pixelSize: 12
            opacity: root.hasProfile ? 0.92 : 0.55
        }
        Row {
            spacing: 6
            Rectangle {
                width: 6
                height: 6
                radius: 3
                anchors.verticalCenter: parent.verticalCenter
                color: root.stateColor
                SequentialAnimation on opacity {
                    running: root.state === "saving"
                    loops: Animation.Infinite
                    NumberAnimation { from: 0.25; to: 1; duration: 520 }
                    NumberAnimation { from: 1; to: 0.25; duration: 520 }
                }
            }
            Text {
                text: root.hasProfile ? session.saveText : "新建或打开一个配置档开始"
                color: root.muted
                font.family: theme.hanFamily
                font.pixelSize: 10
            }
        }
    }

    // undo / redo
    Row {
        anchors.right: actions.left
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        visible: root.hasProfile
        EdButton {
            width: 30; height: 30; small: true; text: "↶"; ghost: false
            enabled: session.canUndo
            onClicked: session.undo()
        }
        EdButton {
            width: 30; height: 30; small: true; text: "↷"; ghost: false
            enabled: session.canRedo
            onClicked: session.redo()
        }
    }

    Row {
        id: actions
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        EdButton {
            text: app.editorMode === "wizard" ? "向导" : "专家"
            small: true
            onClicked: root.wizardRequested()
        }
        EdButton { text: "插件"; small: true; onClicked: root.pluginsRequested() }
        EdButton { text: "设置"; small: true; onClicked: root.settingsRequested() }

        Rectangle { width: 1; height: 22; color: root.borderColor; anchors.verticalCenter: parent.verticalCenter }

        EdButton {
            visible: root.hasProfile
            text: root.playing ? "■ 停止" : "▶ 试演"
            primary: !root.playing
            danger: root.playing
            onClicked: root.playing ? root.stop() : root.playAll()
        }
        EdButton {
            visible: root.hasProfile
            text: "从当前幕"
            onClicked: root.playAct()
        }
        EdButton {
            visible: root.hasProfile
            text: "导出"
            enabled: session.canExport
            icon: "⬆"
            onClicked: root.exportRequested()
        }
        EdButton {
            visible: !root.hasProfile
            text: "新建配置档"
            primary: true
            onClicked: root.newProfile()
        }
    }
}
