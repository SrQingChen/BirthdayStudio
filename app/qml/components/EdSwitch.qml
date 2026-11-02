import QtQuick

Item {
    id: root

    property bool checked: false
    signal toggled(bool value)

    readonly property var ui: (theme.tokens && theme.tokens.ui) ? theme.tokens.ui : ({})
    readonly property color accent: ui.accent || "#ffb08a"
    readonly property color muted: ui.textMuted || "#b9a9b6"

    width: 42
    height: 24
    opacity: enabled ? 1 : 0.45

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? root.accent : Qt.rgba(1, 1, 1, 0.12)
        border.width: root.checked ? 0 : 1
        border.color: Qt.rgba(1, 1, 1, 0.22)
        Behavior on color { ColorAnimation { duration: 140 } }
    }

    Rectangle {
        width: 18
        height: 18
        radius: 9
        y: 3
        x: root.checked ? root.width - width - 3 : 3
        color: root.checked ? "#2a1410" : root.muted
        Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        enabled: root.enabled
        onClicked: {
            root.checked = !root.checked
            root.toggled(root.checked)
        }
    }
}
