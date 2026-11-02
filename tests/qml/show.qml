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
    property string startAt: "confirm"
    property bool autoRun: true
    property int confirmAt: 2600
    property int blowAt: 0
    property int actionAt: 0

    ShowStage {
        id: stage
        anchors.fill: parent
        profile: root.testProfile
        tokens: theme.tokens
        autoStart: false
    }

    function begin() {
        stage.start(root.startAt)
    }
    function confirmNow() {
        var it = stage.currentItem()
        console.log("CONFIRMNOW act=", stage.currentActId, " item=", it, " fn=", it ? typeof it.confirm : "none")
        if (it && typeof it.confirm === "function")
            it.confirm()
    }
    function skipNow() {
        stage.skipCurrent()
    }
    function blowAllNow() {
        if (stage.cakeScene && typeof stage.cakeScene.blowAll === "function") {
            stage.cakeScene.blowAll()
            return
        }
        for (var i = 0; i < stage.children.length; i++) {
            var c = stage.children[i]
            if (c && typeof c.blowAll === "function") {
                c.blowAll()
                console.log("BLOW ALL candles")
                return
            }
        }
    }

    Timer { interval: 600; running: root.autoRun; onTriggered: root.begin() }
    Timer { interval: root.confirmAt; running: root.autoRun; onTriggered: root.confirmNow() }
    Timer { interval: root.blowAt; running: root.autoRun && root.blowAt > 0; onTriggered: root.blowAllNow() }
    Timer {
        interval: root.actionAt
        running: root.autoRun && root.actionAt > 0
        onTriggered: {
            var it = stage.currentItem()
            if (!it) return
            if (root.startAt === "intro" && typeof it.advance === "function") it.advance()
            else if (root.startAt === "wax" && typeof it.openSeal === "function") it.openSeal()
        }
    }
}
