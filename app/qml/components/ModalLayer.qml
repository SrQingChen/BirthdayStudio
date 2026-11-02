import QtQuick
import QtQuick.Controls

Item {
    id: root

    property bool opened: false
    property string title: ""
    property string subtitle: ""
    property int cardWidth: 720
    property int cardHeight: 540
    property bool closeOnDim: true
    property bool showClose: true
    signal closed()

    default property alias content: body.data

    visible: opened
    anchors.fill: parent
    z: 2000

    function close() {
        opened = false
        closed()
    }

    Rectangle {
        anchors.fill: parent
        color: "#05030a"
        opacity: 0.62
        MouseArea {
            anchors.fill: parent
            onClicked: if (root.closeOnDim) root.close()
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(root.cardWidth, parent.width - 80)
        height: Math.min(root.cardHeight, parent.height - 60)
        radius: 18
        color: (theme.tokens && theme.tokens.ui && theme.tokens.ui.panel) ? theme.tokens.ui.panel : "#171020"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.16)

        Rectangle {
            anchors.fill: parent
            anchors.margins: -8
            radius: 24
            color: "#000000"
            opacity: 0.35
            z: -1
        }

        // header
        Item {
            id: header
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 64
            Column {
                anchors.left: parent.left
                anchors.leftMargin: 22
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Text {
                    text: root.title
                    color: (theme.tokens && theme.tokens.ui && theme.tokens.ui.text) ? theme.tokens.ui.text : "#f5ede8"
                    font.family: theme.hanFamily
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                }
                Text {
                    text: root.subtitle
                    visible: text !== ""
                    color: (theme.tokens && theme.tokens.ui && theme.tokens.ui.textMuted) ? theme.tokens.ui.textMuted : "#b9a9b6"
                    font.family: theme.hanFamily
                    font.pixelSize: 11
                }
            }
            Text {
                visible: root.showClose
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                text: "✕"
                color: (theme.tokens && theme.tokens.ui && theme.tokens.ui.textMuted) ? theme.tokens.ui.textMuted : "#b9a9b6"
                font.pixelSize: 16
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.close()
                }
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: header.bottom
            height: 1
            color: Qt.rgba(1, 1, 1, 0.10)
        }

        Column {
            id: body
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: header.bottom
            anchors.bottom: parent.bottom
            anchors.leftMargin: 22
            anchors.rightMargin: 22
            anchors.topMargin: 16
            anchors.bottomMargin: 18
            spacing: 12
            clip: true
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.opened
        onActivated: root.close()
    }
}
