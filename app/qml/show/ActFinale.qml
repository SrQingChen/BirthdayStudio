import QtQuick

// Act 7 — confetti, the name reveal, replay or close.
Item {
    id: root

    property var profile: ({})
    property var cfg: ({})
    property var tokens: ({})
    property bool reducedMotion: false
    property bool highContrast: false
    property real speedScale: 1.0
    signal actFinished()
    signal replay()
    signal closeShow()
    signal sfx(string kind)

    anchors.fill: parent
    focus: true

    property bool started: false
    property bool done: false
    property bool buttonsReady: false

    readonly property var finaleCfg: cfg || ({})
    readonly property var confettiCfg: finaleCfg.confetti || ({})
    readonly property var buttons: finaleCfg.buttons || ({})
    readonly property string headline: finaleCfg.headline || "生日快乐"
    readonly property string subline: format(finaleCfg.subline || "{honoree} · 今天的主角")

    function withAlpha(c, a) {
        var q = Qt.color(c)
        return Qt.rgba(q.r, q.g, q.b, a)
    }

    function format(t) {
        return String(t || "")
            .replace("{honoree}", profile && profile.meta ? profile.meta.honoree : "")
            .replace("{author}", profile && profile.meta ? profile.meta.author : "")
    }

    function enter() {
        if (started)
            return
        started = true
        sfx("sparkle")
        pulse.start()
        fuseTimer.start()
        contentIn.start()
        buttonTimer.start()
    }

    // dark scrim so the headline always wins over the cake
    Rectangle {
        anchors.fill: parent
        z: 1
        color: "#0a0512"
        opacity: root.highContrast ? 0.82 : 0.54
        visible: true
    }

    // warm light pool for text contrast
    Image {
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.9, parent.height * 1.5)
        height: width
        source: showBridge.textureUrl("bokeh_cream.png")
        opacity: 0.22
        visible: !root.highContrast
    }

    Loader {
        id: finaleFxSlot
        anchors.fill: parent
        z: 2
        source: {
            var rev = showBridge.pluginRevision
            return showBridge.slotComponent("FinaleFX")
        }
        visible: status === Loader.Ready
        onLoaded: {
            try {
                item.config = root.confettiCfg
                item.reducedMotion = root.reducedMotion
                item.active = Qt.binding(function () { return root.started })
            } catch (e) {
                source = ""
            }
        }
    }

    ConfettiCanvas {
        id: confetti
        anchors.fill: parent
        visible: finaleFxSlot.status !== Loader.Ready
        config: root.confettiCfg
        reducedMotion: root.reducedMotion
        active: root.started
        z: 2
    }

    // visual fuse: a small expanding ring 200 ms before the loud "boom"
    Rectangle {
        id: fuseRing
        anchors.centerIn: parent
        width: 44
        height: 44
        radius: 22
        color: "transparent"
        border.width: 2
        border.color: "#ffe9d6"
        opacity: 0
        visible: opacity > 0.01
        z: 3

        ParallelAnimation {
            id: pulse
            NumberAnimation { target: fuseRing; property: "scale"; from: 0.4; to: 5.0; duration: 420; easing.type: Easing.OutCubic }
            NumberAnimation { target: fuseRing; property: "opacity"; from: 0.55; to: 0; duration: 420; easing.type: Easing.OutQuad }
        }
    }

    Timer {
        id: fuseTimer
        interval: 210
        onTriggered: root.sfx("boom")
    }

    Item {
        id: content
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -30
        width: Math.min(parent.width * 0.9, 1100)
        height: 340
        z: 4
        opacity: 0
        scale: 0.9

        Column {
            anchors.centerIn: parent
            spacing: 16
            width: parent.width

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.subline
                color: "#ffd9b8"
                opacity: 0.85
                font.family: theme.hanFamily
                font.pixelSize: 17
                font.letterSpacing: 4
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.headline
                color: "#fff8ee"
                font.family: theme.serifFamily
                font.pixelSize: Math.min(92, root.width * 0.066)
                font.weight: Font.DemiBold
                font.letterSpacing: Math.min(12, root.width * 0.007)
                horizontalAlignment: Text.AlignHCenter
                style: Text.Outline
                styleColor: Qt.rgba(0.98, 0.68, 0.45, 0.28)
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "愿今天的光，够你照亮很久很久"
                color: "#ffe9df"
                opacity: 0.92
                font.family: theme.hanFamily
                font.pixelSize: 18
                font.letterSpacing: 2
            }

            Item { width: 1; height: 14 }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16
                opacity: root.buttonsReady ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 320 } }

                Rectangle {
                    id: replayBtn
                    width: 168
                    height: 50
                    radius: 25
                    color: root.highContrast ? "#ffffff" : root.withAlpha(theme.palette["primary"] || "#ffb08a", 0.92)
                    border.width: 0
                    scale: replayArea.pressed ? 0.96 : (replayArea.containsMouse ? 1.03 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
                    Text {
                        anchors.centerIn: parent
                        text: root.buttons.replay || "再看一次"
                        color: "#3a1a10"
                        font.family: theme.hanFamily
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                    }
                    MouseArea {
                        id: replayArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!root.done) {
                                root.done = true
                                root.replay()
                            }
                        }
                    }
                }

                Rectangle {
                    id: closeBtn
                    width: 168
                    height: 50
                    radius: 25
                    color: closeArea.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(0.04, 0.02, 0.07, 0.55)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.55)
                    scale: closeArea.pressed ? 0.96 : 1.0
                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
                    Text {
                        anchors.centerIn: parent
                        text: root.buttons.close || "合上贺卡"
                        color: "#fff5ee"
                        font.family: theme.hanFamily
                        font.pixelSize: 16
                    }
                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closeShow()
                    }
                }
            }
        }
    }

    ParallelAnimation {
        id: contentIn
        NumberAnimation { target: content; property: "opacity"; from: 0; to: 1; duration: 520 }
        NumberAnimation {
            target: content; property: "scale"
            from: root.reducedMotion ? 1 : 0.9; to: 1
            duration: 720; easing.type: Easing.OutBack; easing.overshoot: 1.06
        }
    }

    Timer {
        id: buttonTimer
        interval: 780
        onTriggered: root.buttonsReady = true
    }

    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_R) {
            if (!root.done) { root.done = true; root.replay() }
            event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
            root.closeShow()
            event.accepted = true
        }
    }

    Component.onCompleted: {
        enter()
        forceActiveFocus()
    }
}
