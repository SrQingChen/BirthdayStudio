import QtQuick

Rectangle {
    id: root

    property string text: ""
    property string icon: ""
    property bool primary: false
    property bool danger: false
    property bool ghost: true
    property bool small: false
    property bool large: false
    property bool checkable: false
    property bool checked: false
    signal clicked()

    readonly property var ui: (theme.tokens && theme.tokens.ui) ? theme.tokens.ui : ({})
    readonly property color accent: ui.accent || "#ffb08a"
    readonly property color ink: ui.text || "#f5ede8"
    readonly property color panel: ui.panelAlt || "#1f1629"
    readonly property color dangerColor: ui.danger || "#ff8a80"

    width: Math.max(root.large ? 130 : (small ? 56 : 74), label.implicitWidth + (icon !== "" ? 34 : 20) + (root.large ? 44 : (small ? 14 : 20)))
    height: root.large ? 48 : (small ? 28 : 34)
    radius: height / 2
    opacity: enabled ? 1.0 : 0.45
    color: {
        if (primary)
            return accent
        if (danger)
            return hover.containsMouse ? Qt.rgba(1, 0.54, 0.5, 0.16) : "transparent"
        if (root.checked)
            return Qt.rgba(1, 1, 1, 0.14)
        return hover.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
    }
    border.width: root.ghost && !root.primary ? 1 : 0
    border.color: root.danger ? Qt.rgba(1, 0.54, 0.5, 0.35) : Qt.rgba(1, 1, 1, 0.16)

    Row {
        anchors.centerIn: parent
        spacing: 6
        Text {
            visible: root.icon !== ""
            text: root.icon
            color: root.primary ? "#3a1a10" : (root.danger ? root.dangerColor : root.ink)
            font.pixelSize: root.large ? 17 : (root.small ? 12 : 14)
            opacity: 0.9
        }
        Text {
            id: label
            text: root.text
            color: root.primary ? "#3a1a10" : (root.danger ? root.dangerColor : root.ink)
            font.family: theme.hanFamily
            font.pixelSize: root.large ? 15 : (root.small ? 12 : 13)
            font.weight: root.primary ? Font.DemiBold : Font.Normal
        }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.checkable)
                root.checked = !root.checked
            root.clicked()
        }
    }

    Behavior on color { ColorAnimation { duration: 120 } }
}
