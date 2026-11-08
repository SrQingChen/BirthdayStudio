import QtQuick
import QtQuick.Controls

Slider {
    id: root

    readonly property var ui: (theme.tokens && theme.tokens.ui) ? theme.tokens.ui : ({})
    readonly property bool dark: !ui || ui.mode !== "light"
    property color accentColor: ui.accent || "#ffb08a"
    property color trackColor: root.dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.14)

    implicitHeight: 24
    leftPadding: 0
    rightPadding: 0
    topPadding: 0
    bottomPadding: 0

    background: Rectangle {
        x: 0
        y: root.topPadding + root.availableHeight / 2 - height / 2
        width: root.availableWidth
        height: 3
        radius: 1.5
        color: root.trackColor
        Rectangle {
            width: root.visualPosition * parent.width
            height: parent.height
            radius: 1.5
            color: root.accentColor
        }
    }

    handle: Rectangle {
        x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
        y: root.topPadding + root.availableHeight / 2 - height / 2
        width: 14
        height: 14
        radius: 7
        color: "#fff5ee"
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, root.dark ? 0.22 : 0.32)
    }
}
