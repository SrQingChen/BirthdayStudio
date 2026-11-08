import QtQuick

Column {
    id: root

    property string title: ""
    property string subtitle: ""
    property bool expanded: true
    property bool collapsible: true

    default property alias content: body.data

    readonly property var ui: (theme.tokens && theme.tokens.ui) ? theme.tokens.ui : ({})
    readonly property color ink: ui.text || "#f5ede8"
    readonly property color muted: ui.textMuted || "#b9a9b6"
    readonly property color accent: ui.accent || "#ffb08a"
    readonly property bool dark: !ui || ui.mode !== "light"

    width: parent ? parent.width : 300
    spacing: 8

    Item {
        width: parent.width
        height: 30

        Rectangle {
            anchors.fill: parent
            radius: 7
            color: headerMouse.containsMouse && root.collapsible
                   ? (root.dark ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.05))
                   : "transparent"
            Behavior on color { ColorAnimation { duration: 110 } }
        }

        MouseArea {
            id: headerMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: root.collapsible ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (root.collapsible) root.expanded = !root.expanded
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 3
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Text {
                width: 10
                text: root.collapsible ? "▾" : "·"
                color: root.muted
                font.pixelSize: 11
                rotation: root.expanded ? 0 : -90
                Behavior on rotation { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            }
            Text {
                text: root.title
                color: root.ink
                font.family: theme.hanFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
                font.letterSpacing: 0.6
            }
            Rectangle {
                visible: root.subtitle !== ""
                width: 1
                height: 10
                anchors.verticalCenter: parent.verticalCenter
                color: root.dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.14)
            }
            Text {
                text: root.subtitle
                color: root.muted
                font.family: theme.hanFamily
                font.pixelSize: 10
                opacity: 0.85
            }
        }

        // Expanded marker: a short accent rule under the header.
        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 19
            anchors.bottom: parent.bottom
            width: root.expanded ? 18 : 0
            height: 1.5
            radius: 0.75
            color: root.accent
            opacity: root.expanded ? 0.55 : 0
            Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 140 } }
        }
    }

    Column {
        id: body
        width: parent.width
        spacing: 8
        visible: root.expanded
    }
}
