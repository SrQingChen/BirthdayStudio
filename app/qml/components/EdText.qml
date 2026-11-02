import QtQuick
import QtQuick.Controls

TextField {
    id: root

    property bool invalid: false
    property bool compact: false
    property bool mono: false

    readonly property var ui: (theme.tokens && theme.tokens.ui) ? theme.tokens.ui : ({})
    readonly property color ink: ui.text || "#f5ede8"
    readonly property color muted: ui.textMuted || "#b9a9b6"
    readonly property color accent: ui.accent || "#ffb08a"
    readonly property color dangerColor: ui.danger || "#ff8a80"
    readonly property color borderColor: ui.panelBorder || "#ffffff14"

    color: ink
    placeholderTextColor: root.muted
    selectionColor: root.accent
    selectedTextColor: "#241018"
    font.family: root.mono ? "Consolas" : theme.hanFamily
    font.pixelSize: root.mono ? 12 : 13
    implicitHeight: root.compact ? 30 : 34
    leftPadding: 10
    rightPadding: 10
    topPadding: 0
    bottomPadding: 0
    verticalAlignment: TextInput.AlignVCenter

    background: Rectangle {
        radius: 8
        color: Qt.rgba(0, 0, 0, 0.14)
        border.width: root.activeFocus || root.invalid ? 1.5 : 1
        border.color: root.invalid ? root.dangerColor : (root.activeFocus ? root.accent : root.borderColor)
        Behavior on border.color { ColorAnimation { duration: 120 } }
    }
}
