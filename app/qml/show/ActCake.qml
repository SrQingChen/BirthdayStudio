import QtQuick

// Act 6 — cake, candles, blowing, the wish, and the reveal.
Item {
    id: root

    property var profile: ({})
    property var cfg: ({})
    property var tokens: ({})
    property bool reducedMotion: false
    property bool highContrast: false
    property real speedScale: 1.0
    property var cakeStage: null
    signal actFinished()
    signal sfx(string kind)

    anchors.fill: parent

    readonly property var cakeCfg: cfg || ({})
    readonly property var wish: cakeCfg.wish || ({})
    readonly property var candlesCfg: cakeCfg.candles || ({})
    readonly property bool micEnabled: candlesCfg.mic_enabled === true
    readonly property real micThreshold: candlesCfg.mic_threshold !== undefined ? candlesCfg.mic_threshold : 0.22
    readonly property int darkenMs: wish.darken_ms || 520
    readonly property int silenceMs: wish.silence_ms || 2400
    readonly property string revealText: wish.reveal_text || "生日快乐"
    readonly property int revealMs: wish.reveal_duration_ms || 900
    readonly property string hintText: cakeCfg.hint || "点亮蜡烛后，逐根点击吹灭"

    property bool started: false
    property bool allOut: false
    property bool wishing: false
    property bool revealed: false
    property bool done: false
    property int blown: 0
    property bool hintShown: true
    property bool micBlowing: false
    property string micNote: ""

    function enter() {
        if (started)
            return
        started = true
        if (cakeStage) {
            cakeStage.resetCandles()
            cakeStage.active = true
        }
        hintFade.start()
        if (micEnabled) {
            showBridge.micStart()
            micNote = showBridge.micMessage
            micTimer.start()
        }
    }

    function onCandleOut(index) {
        blown += 1
        hintFade.running = false
        hint.opacity = 0
        if (blown >= (candlesCfg.count || 5)) {
            // allCandlesOut follows from the stage; guard duplicates
        }
    }

    function allCandlesGone() {
        if (allOut)
            return
        allOut = true
        hintFade.stop()
        hint.opacity = 0
        wishSequence.start()
    }

    function skip() {
        skipToEnd()
    }

    function skipToEnd() {
        if (done)
            return
        wishSequence.stop()
        revealTimer.stop()
        darkOverlay.opacity = 0
        wishText.opacity = 0
        revealGroup.opacity = 1
        revealGroup.scale = 1
        revealed = true
        done = true
        completed()
    }

    // darkening + wish
    Rectangle {
        id: darkOverlay
        anchors.fill: parent
        color: "#05030a"
        opacity: 0
        visible: opacity > 0.01
    }

    Column {
        id: wishText
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -10
        spacing: 14
        opacity: 0
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "许愿…"
            color: "#ffe9d6"
            font.family: theme.serifFamily
            font.pixelSize: 34
            font.letterSpacing: 8
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "在心里，把愿望说给今晚的烛光听"
            color: "#ffe9d6"
            opacity: 0.55
            font.family: theme.hanFamily
            font.pixelSize: 14
            font.letterSpacing: 1
        }
    }

    // final reveal
    Item {
        id: revealGroup
        anchors.centerIn: parent
        width: parent.width * 0.9
        height: parent.height * 0.5
        opacity: 0
        scale: 0.86

        Image {
            anchors.centerIn: parent
            width: parent.width * 0.6
            height: width * 0.6
            source: showBridge.textureUrl("bokeh_cream.png")
            opacity: 0.34
        }
        Column {
            anchors.centerIn: parent
            spacing: 14
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.revealText
                color: "#fff6e8"
                font.family: theme.serifFamily
                font.pixelSize: Math.min(78, root.width * 0.052)
                font.weight: Font.DemiBold
                font.letterSpacing: 6
                style: Text.Outline
                styleColor: Qt.rgba(0.95, 0.62, 0.42, 0.25)
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: profile && profile.meta ? profile.meta.honoree + " · 今天的主角" : ""
                color: "#ffd9b8"
                font.family: theme.hanFamily
                font.pixelSize: 18
                font.letterSpacing: 3
                opacity: 0.9
            }
        }
    }

    // hint + counter
    Item {
        id: hint
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.max(34, parent.height * 0.05)
        width: parent.width * 0.8
        height: 68

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width, 470)
            height: 64
            radius: 32
            color: Qt.rgba(0.05, 0.03, 0.08, 0.55)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.14)
        }

        Column {
            anchors.centerIn: parent
            spacing: 8
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.micEnabled && showBridge.micAvailable
                      ? "对着麦克风吹气，或逐根点击蜡烛"
                      : root.hintText
                color: "#ffe9df"
                font.family: theme.hanFamily
                font.pixelSize: 18
                opacity: 0.86
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.micNote !== "" ? root.micNote : ("还剩 " + Math.max(0, (root.candlesCfg.count || 5) - root.blown) + " 根蜡烛")
                color: "#ffc9a8"
                font.family: theme.hanFamily
                font.pixelSize: 13
                opacity: 0.62
            }
        }
    }

    SequentialAnimation {
        id: hintFade
        PauseAnimation { duration: 7000 }
        NumberAnimation { target: hint; property: "opacity"; to: 0; duration: 600 }
    }

    SequentialAnimation {
        id: wishSequence
        NumberAnimation { target: darkOverlay; property: "opacity"; to: root.reducedMotion ? 0.5 : 0.68; duration: root.darkenMs; easing.type: Easing.InOutQuad }
        PauseAnimation { duration: 220 }
        NumberAnimation { target: wishText; property: "opacity"; from: 0; to: 1; duration: 700; easing.type: Easing.OutQuad }
        PauseAnimation { duration: root.silenceMs }
        NumberAnimation { target: wishText; property: "opacity"; to: 0; duration: 420 }
        NumberAnimation { target: darkOverlay; property: "opacity"; to: 0.42; duration: 680; easing.type: Easing.InOutQuad }
        PauseAnimation { duration: 180 }
        ScriptAction { script: root.sfx("chime") }
        ParallelAnimation {
            NumberAnimation { target: revealGroup; property: "opacity"; from: 0; to: 1; duration: root.reducedMotion ? 300 : 620 }
            NumberAnimation {
                target: revealGroup; property: "scale"
                from: root.reducedMotion ? 1.0 : 0.86; to: 1
                duration: root.revealMs; easing.type: Easing.OutBack; easing.overshoot: 1.08
            }
        }
        ScriptAction { script: root.sfx("sparkle") }
        PauseAnimation { duration: 1500 }
        ScriptAction {
            script: {
                if (!root.done) {
                    root.revealed = true
                    root.done = true
                    root.actFinished()
                }
            }
        }
    }

    Timer {
        id: revealTimer
        interval: 4000
        onTriggered: {
            if (!root.done) {
                root.done = true
                root.actFinished()
            }
        }
    }

    // microphone blow loop: one candle per ~240 ms while the level is high
    Timer {
        id: micTimer
        interval: 240
        repeat: true
        onTriggered: {
            if (!root.micEnabled || !root.cakeStage)
                return
            var level = showBridge.micLevel
            if (level >= root.micThreshold) {
                root.micBlowing = true
                for (var i = 0; i < (root.candlesCfg.count || 5); i++) {
                    var flags = root.cakeStage.outFlags
                    if (!flags[i]) {
                        root.cakeStage.blowOut(i)
                        break
                    }
                }
            } else {
                root.micBlowing = false
            }
        }
    }

    Connections {
        target: root.cakeStage
        enabled: root.cakeStage !== null
        function onCandleBlownOut(index) { root.onCandleOut(index) }
        function onAllCandlesOut() { root.allCandlesGone() }
    }


    Connections {
        target: showBridge
        function onMicChanged() {
            if (root.micEnabled)
                root.micNote = showBridge.micAvailable ? "" : showBridge.micMessage
        }
    }

    onCakeStageChanged: {
        if (cakeStage && started) {
            cakeStage.resetCandles()
            cakeStage.active = true
        }
    }

    Component.onCompleted: enter()
    Component.onDestruction: {
        if (root.micEnabled)
            showBridge.micStop()
    }
}
