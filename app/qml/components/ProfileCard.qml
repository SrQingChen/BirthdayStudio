import QtQuick
import QtQuick.Controls

Item {
    id: root

    property var profile: ({})
    property bool selected: false
    signal activated(string id)
    signal action(string action, string id)

    readonly property var ui: (theme.tokens && theme.tokens.ui) ? theme.tokens.ui : ({})
    readonly property color ink: ui.text || "#f5ede8"
    readonly property color muted: ui.textMuted || "#b9a9b6"
    readonly property color accent: ui.accent || "#ffb08a"
    readonly property color borderColor: ui.panelBorder || "#ffffff14"

    width: parent ? parent.width : 240
    height: 82

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: root.selected
               ? Qt.rgba(1, 1, 1, 0.10)
               : (hover.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
        border.width: 1
        border.color: root.selected ? root.accent : (hover.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent")
    }

    Rectangle {
        id: thumb
        x: 8
        y: 8
        width: 92
        height: 54
        radius: 7
        clip: true
        color: Qt.rgba(1, 1, 1, 0.06)

        Image {
            anchors.fill: parent
            source: root.profile.previewUrl || ""
            fillMode: Image.PreserveAspectCrop
            visible: root.profile.previewUrl !== undefined && root.profile.previewUrl !== ""
        }
        Text {
            anchors.centerIn: parent
            visible: !root.profile.previewUrl
            text: (root.profile.name || "?").substring(0, 1)
            color: root.accent
            font.family: theme.serifFamily
            font.pixelSize: 26
        }
    }

    Column {
        anchors.left: thumb.right
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Text {
            width: parent.width
            text: root.profile.name || "未命名"
            color: root.ink
            font.family: theme.hanFamily
            font.pixelSize: 12
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            text: "致 " + (root.profile.honoree || "你")
            color: root.muted
            font.family: theme.hanFamily
            font.pixelSize: 11
            elide: Text.ElideRight
        }
        Row {
            spacing: 6
            Text {
                text: root.profile.themeName || ""
                color: root.accent
                opacity: 0.85
                font.family: theme.hanFamily
                font.pixelSize: 9
            }
            Text {
                text: (root.profile.modifiedAt || "").replace("T", " ").substring(0, 16)
                color: root.muted
                opacity: 0.7
                font.family: theme.hanFamily
                font.pixelSize: 9
            }
        }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: function (mouse) {
            if (mouse.button === Qt.RightButton)
                menu.popup()
            else
                root.activated(root.profile.id)
        }
    }

    Menu {
        id: menu
        MenuItem { text: "打开"; onTriggered: root.activated(root.profile.id) }
        MenuItem { text: "复制配置档"; onTriggered: root.action("duplicate", root.profile.id) }
        MenuItem { text: "导出 .bbp"; onTriggered: root.action("export", root.profile.id) }
        MenuItem { text: "快照历史"; onTriggered: root.action("snapshots", root.profile.id) }
        MenuItem { text: "在资源管理器中显示"; onTriggered: root.action("reveal", root.profile.id) }
        MenuSeparator { }
        MenuItem { text: "移入回收站"; onTriggered: root.action("delete", root.profile.id) }
    }
}
