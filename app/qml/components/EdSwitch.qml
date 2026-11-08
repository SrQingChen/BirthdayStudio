import QtQuick

Item {
    id: root

    property bool checked: false
    signal toggled(bool value)

    readonly property var ui: (theme.tokens && theme.tokens.ui) ? theme.tokens.ui : ({})
    readonly property color accent: ui.accent || "#ffb08a"
    readonly property color muted: ui.textMuted || "#b9a9b6"
    readonly property bool dark: !ui || ui.mode !== "light"
    readonly property color offTrack: dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.12)
    readonly property color offBorder: dark ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.18)

    width: 42
    height: 24
    opacity: enabled ? 1 : 0.45
    scale: press.pressed && enabled ? 0.94 : 1.0
    Behavior on scale { NumberAnimation { duration: 80 } }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? (press.pressed ? Qt.darker(root.accent, 1.08) : root.accent) : (press.pressed ? (root.dark ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(0, 0, 0, 0.18)) : root.offTrack)
        border.width: root.checked ? 0 : 1
        border.color: root.offBorder
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
        id: press
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: root.enabled
        // Never assign `checked` here: callers bind it to their own model.
        // The old self-toggle destroyed that binding, so the switch stopped
        // reflecting reset/undo/model refreshes.
        onClicked: root.toggled(!root.checked)
    }
}
