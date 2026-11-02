import QtQuick

Column {
    id: root

    property string title: ""
    property string subtitle: ""
    property bool expanded: true
    property bool collapsible: true

    default property alias content: body.data

    width: parent ? parent.width : 300
    spacing: 8

    Item {
        width: parent.width
        height: 30
        MouseArea {
            anchors.fill: parent
            cursorShape: root.collapsible ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (root.collapsible) root.expanded = !root.expanded
        }
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Text {
                text: root.collapsible ? (root.expanded ? "▾" : "▸") : "·"
                color: (theme.tokens && theme.tokens.ui && theme.tokens.ui.textMuted) ? theme.tokens.ui.textMuted : "#b9a9b6"
                font.pixelSize: 11
            }
            Text {
                text: root.title
                color: (theme.tokens && theme.tokens.ui && theme.tokens.ui.text) ? theme.tokens.ui.text : "#f5ede8"
                font.family: theme.hanFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
                font.letterSpacing: 0.6
            }
            Text {
                text: root.subtitle
                color: (theme.tokens && theme.tokens.ui && theme.tokens.ui.textMuted) ? theme.tokens.ui.textMuted : "#b9a9b6"
                font.family: theme.hanFamily
                font.pixelSize: 11
                opacity: 0.7
            }
        }
    }

    Column {
        id: body
        width: parent.width
        spacing: 8
        visible: root.expanded
    }
}
