import QtQuick
import QtQuick.Window
import "../../app/qml/show"

Window {
    id: root
    visible: true
    width: 1280
    height: 720
    color: "#000000"
    flags: Qt.FramelessWindowHint

    property var testProfile: ({})

    Cake3DStage {
        anchors.fill: parent
        profile: root.testProfile
        tokens: theme.tokens
        active: true
        onSfx: function (kind) {}
    }
}
