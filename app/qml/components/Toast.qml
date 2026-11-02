import QtQuick

Item {
    id: root
    property string text: ""
    property bool showing: false

    anchors.top: parent.top
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.topMargin: 26
    width: Math.min(parent.width * 0.8, 560)
    height: 44
    z: 1000

    function show(message) {
        text = message
        showing = true
        hideTimer.restart()
        enterAnim.restart()
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width, Math.max(160, msg.implicitWidth + 48))
        height: 44
        radius: 22
        color: Qt.rgba(0.06, 0.04, 0.09, 0.86)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.16)
        opacity: root.showing ? 1 : 0

        Text {
            id: msg
            anchors.centerIn: parent
            text: root.text
            color: "#fff3e9"
            font.family: theme.hanFamily
            font.pixelSize: 14
            elide: Text.ElideRight
            width: root.width - 48
            horizontalAlignment: Text.AlignHCenter
        }
    }

    ParallelAnimation {
        id: enterAnim
        NumberAnimation { target: root; property: "y"; from: 12; to: 0; duration: 220; easing.type: Easing.OutCubic }
    }

    Timer {
        id: hideTimer
        interval: 2400
        onTriggered: root.showing = false
    }

    Behavior on opacity { NumberAnimation { duration: 220 } }
    opacity: showing ? 1 : 0
    y: 0
}
