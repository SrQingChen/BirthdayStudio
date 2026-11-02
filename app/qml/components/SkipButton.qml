import QtQuick

Rectangle {
    id: skip

    property var tokens: ({})
    property bool visibleHint: true
    signal clicked()

    width: 108
    height: 44
    radius: 22
    visible: visibleHint
    opacity: visible ? 0.92 : 0
    color: {
        var light = tokens && tokens.ui && tokens.ui.mode === "light"
        return hover.containsMouse
            ? (light ? Qt.rgba(1, 1, 1, 0.98) : Qt.rgba(1, 1, 1, 0.16))
            : (light ? Qt.rgba(1, 1, 1, 0.80) : Qt.rgba(0.08, 0.05, 0.12, 0.62))
    }
    border.width: 1
    border.color: {
        var light = tokens && tokens.ui && tokens.ui.mode === "light"
        return light ? Qt.rgba(0.29, 0.17, 0.16, 0.18) : Qt.rgba(1, 1, 1, 0.20)
    }

    readonly property color ink: (tokens && tokens.ui && tokens.ui.text) ? tokens.ui.text : "#f5ede8"

    Text {
        anchors.centerIn: parent
        text: "跳过  ›"
        color: skip.ink
        font.family: theme.hanFamily
        font.pixelSize: 14
        opacity: 0.85
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: skip.clicked()
    }

    Behavior on opacity { NumberAnimation { duration: 180 } }
}
