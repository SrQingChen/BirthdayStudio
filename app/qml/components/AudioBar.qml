import QtQuick

// Always-visible audio transport (WCAG 1.4.2): mute, pause, independent volume.
Rectangle {
    id: bar

    property var tokens: ({})
    property bool compact: false

    width: compact ? 196 : 232
    height: 46
    radius: 23
    color: {
        var light = tokens && tokens.ui && tokens.ui.mode === "light"
        return light ? Qt.rgba(1, 1, 1, 0.86) : Qt.rgba(0.10, 0.06, 0.14, 0.72)
    }
    border.width: 1
    border.color: {
        var light = tokens && tokens.ui && tokens.ui.mode === "light"
        return light ? Qt.rgba(0.29, 0.17, 0.16, 0.16) : Qt.rgba(1, 1, 1, 0.18)
    }

    readonly property color ink: (tokens && tokens.ui && tokens.ui.text) ? tokens.ui.text : "#f5ede8"
    readonly property color accent: (tokens && tokens.color && tokens.color.palette && tokens.color.palette.primary) ? tokens.color.palette.primary : "#ffb08a"

    Row {
        anchors.centerIn: parent
        spacing: 4

        Rectangle {
            width: 32; height: 32; radius: 16
            color: muteArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
            Text {
                anchors.centerIn: parent
                text: audioBridge.muted ? "静" : "♪"
                color: bar.ink
                font.family: theme.hanFamily
                font.pixelSize: 15
                font.weight: Font.DemiBold
                opacity: audioBridge.muted ? 0.65 : 0.95
            }
            MouseArea {
                id: muteArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: audioBridge.toggleMute()
            }
        }

        Rectangle {
            width: 32; height: 32; radius: 16
            color: pauseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
            Text {
                anchors.centerIn: parent
                text: audioBridge.playing ? "❚❚" : "▶"
                color: bar.ink
                font.pixelSize: 11
                opacity: 0.9
            }
            MouseArea {
                id: pauseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: audioBridge.togglePause()
            }
        }

        Item {
            width: bar.compact ? 58 : 82
            height: 28

            readonly property int value: audioBridge.masterVolume

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: 4
                width: parent.width - 8
                height: 3
                radius: 1.5
                color: Qt.rgba(1, 1, 1, 0.18)
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: 4
                width: (parent.width - 8) * parent.value / 100
                height: 3
                radius: 1.5
                color: bar.accent
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: 1 + (parent.width - 8) * parent.value / 100
                width: 12
                height: 12
                radius: 6
                color: bar.ink
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.18)
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                function apply(x) {
                    var pct = Math.round(Math.max(0, Math.min(1, (x - 4) / (width - 8))) * 100)
                    audioBridge.setMasterVolume(pct)
                }
                onPressed: function (mouse) { apply(mouse.x) }
                onPositionChanged: function (mouse) { if (pressed) apply(mouse.x) }
            }
        }
    }
}
