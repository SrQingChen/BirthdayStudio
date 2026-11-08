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
    // Presentation only: the CALLER owns `checked`. A control that assigns to
    // its own bound property destroys the binding, which used to leave every
    // tab/chip visually selected after the first click.
    property bool checkable: false
    property bool checked: false
    signal clicked()

    readonly property var ui: (theme.tokens && theme.tokens.ui) ? theme.tokens.ui : ({})
    readonly property color accent: ui.accent || "#ffb08a"
    readonly property color ink: ui.text || "#f5ede8"
    readonly property color panel: ui.panelAlt || "#1f1629"
    readonly property color dangerColor: ui.danger || "#ff8a80"
    readonly property bool dark: !ui || ui.mode !== "light"
    readonly property bool down: hover.pressed && root.enabled
    readonly property bool lit: hover.containsMouse && root.enabled
    readonly property color accentTint: Qt.rgba(accent.r, accent.g, accent.b, 0.18)
    // Ghost chrome must flip with the theme: white hairlines are invisible on
    // the light cartoon themes, which made every unselected tab read as text.
    readonly property color hairline: dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.16)
    readonly property color hairlineLit: dark ? Qt.rgba(1, 1, 1, 0.26) : Qt.rgba(0, 0, 0, 0.28)
    readonly property color hoverFill: dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.05)
    readonly property color pressFill: dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.10)

    width: Math.max(root.large ? 130 : (small ? 56 : 74), label.implicitWidth + (icon !== "" ? 34 : 20) + (root.large ? 44 : (small ? 14 : 20)))
    height: root.large ? 48 : (small ? 28 : 34)
    radius: height / 2
    opacity: enabled ? 1.0 : 0.42
    scale: down ? 0.965 : (lit && !primary && !danger ? 1.015 : 1.0)
    color: {
        if (!enabled)
            return "transparent"
        if (primary)
            return down ? Qt.darker(accent, 1.12) : accent
        if (danger)
            return down ? Qt.rgba(1, 0.54, 0.5, 0.26) : (lit ? Qt.rgba(1, 0.54, 0.5, 0.16) : "transparent")
        if (root.checked)
            return down ? Qt.rgba(accent.r, accent.g, accent.b, 0.28) : root.accentTint
        return down ? root.pressFill : (lit ? root.hoverFill : "transparent")
    }
    border.width: root.ghost && !root.primary ? 1 : 0
    border.color: {
        if (root.danger)
            return Qt.rgba(1, 0.54, 0.5, root.checked ? 0.65 : 0.35)
        if (root.checked)
            return Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.62)
        return root.lit ? root.hairlineLit : root.hairline
    }

    Row {
        anchors.centerIn: parent
        spacing: 6
        Text {
            visible: root.icon !== ""
            text: root.icon
            color: root.primary ? "#3a1a10" : (root.danger ? root.dangerColor : (root.checked ? root.accent : root.ink))
            font.pixelSize: root.large ? 17 : (root.small ? 12 : 14)
            opacity: 0.9
        }
        Text {
            id: label
            text: root.text
            color: root.primary ? "#3a1a10" : (root.danger ? root.dangerColor : (root.checked ? root.accent : root.ink))
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
        onClicked: root.clicked()
    }

    Behavior on color { ColorAnimation { duration: 110 } }
    Behavior on border.color { ColorAnimation { duration: 110 } }
    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
    Behavior on opacity { NumberAnimation { duration: 120 } }
}
