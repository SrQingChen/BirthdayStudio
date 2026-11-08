import QtQuick

// 2.5D fallback for machines where Qt Quick 3D cannot initialise.
// API-compatible with Cake3DStage so the show controller and ActCake overlay
// do not need a second code path.
Item {
    id: root

    property var profile: ({})
    property var tokens: ({})
    property bool reducedMotion: false
    property bool highContrast: false
    property bool active: false

    signal candleBlownOut(int index)
    signal allCandlesOut()
    signal sfx(string kind)

    property var outFlags: []
    property int litCount: 0
    property bool entered: false
    // V1.1.0 fix #3c: same damped-oscillator jelly as the 3D stage so rapid
    // taps stack (a plain SequentialAnimation.start() is a no-op mid-run).
    property real jellyX: 0
    property real jellyV: 0
    readonly property var jellyCfg: (profile.acts && profile.acts.cake && profile.acts.cake.jelly) ? profile.acts.cake.jelly : ({})
    readonly property real jellyK: (jellyCfg.spring || 4.2) * 14
    readonly property real jellyC: (jellyCfg.damping || 0.42) * 6

    readonly property var cakeCfg: (profile.acts && profile.acts.cake && profile.acts.cake.cake) ? profile.acts.cake.cake : ({})
    readonly property var candleCfg: (profile.acts && profile.acts.cake && profile.acts.cake.candles) ? profile.acts.cake.candles : ({})
    readonly property int candleCount: candleCfg.count !== undefined ? candleCfg.count : 5
    readonly property real imgW: Math.min(width * 0.46, height * 0.88)
    readonly property real imgH: imgW * 760 / 900

    function resetCandles() {
        var flags = []
        for (var i = 0; i < candleCount; i++)
            flags.push(false)
        outFlags = flags
        litCount = candleCount
    }

    function resetAll() {
        entrance.stop()
        entered = false
        resetCandles()
        group.scale = 0.94
        group.opacity = 0
        root.jellyX = 0
        root.jellyV = 0
        jellyAnim.running = false
    }

    function blowOut(index) {
        var flags = outFlags.slice()
        if (flags[index])
            return
        flags[index] = true
        outFlags = flags
        litCount = candleCount - flags.filter(function (v) { return v }).length
        sfx("blow")
        candleBlownOut(index)
        if (litCount <= 0)
            allCandlesOut()
    }

    function blowAll() {
        var flags = []
        for (var i = 0; i < candleCount; i++)
            flags.push(true)
        outFlags = flags
        litCount = 0
        allCandlesOut()
    }

    function jelly() {
        if (reducedMotion)
            return
        if (entrance.running) {
            entrance.stop()
            group.opacity = 1
            group.scale = 1
            jellyX = 0
        }
        jellyV = Math.min(8, jellyV + 2.0)
        jellyAnim.running = true
    }

    onOutFlagsChanged: litCount = candleCount - outFlags.filter(function (v) { return v }).length

    Component.onCompleted: resetCandles()

    onActiveChanged: {
        if (active && !entered) {
            entered = true
            entrance.start()
        }
    }

    BackgroundStage {
        anchors.fill: parent
        tokens: root.tokens
        variant: "cake"
        reducedMotion: root.reducedMotion
        highContrast: root.highContrast
    }

    Item {
        id: group
        anchors.centerIn: parent
        width: root.imgW
        height: root.imgH
        opacity: 0
        scale: 0.94

        Image {
            id: cakeImg
            anchors.fill: parent
            source: showBridge.textureUrl("cake_2d.png")
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        Repeater {
            model: root.candleCount
            Item {
                id: candle
                property bool isOut: root.outFlags.length > index ? root.outFlags[index] : false
                property real cx: root.imgW * (0.5 + (index - (root.candleCount - 1) / 2) * 0.038)
                property real cy: root.imgH * (0.25 - Math.abs(index - (root.candleCount - 1) / 2) * 0.003)
                x: cx - width / 2
                y: cy - height
                width: root.imgW * 0.032
                height: root.imgH * 0.075

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: root.imgW * 0.012
                    height: parent.height
                    radius: width / 2
                    color: {
                        var list = root.candleCfg.colors || ["#f2a7b8"]
                        return list[index % list.length]
                    }
                    border.width: 1
                    border.color: Qt.rgba(0, 0, 0, 0.18)
                }

                Item {
                    id: flame
                    visible: !candle.isOut
                    anchors.bottom: parent.top
                    anchors.bottomMargin: -2
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: root.imgW * 0.035
                    height: width * 1.5

                    Image {
                        anchors.fill: parent
                        source: showBridge.textureUrl("flame.png")
                        fillMode: Image.PreserveAspectFit
                    }
                    SequentialAnimation on scale {
                        running: !root.reducedMotion && !candle.isOut
                        loops: Animation.Infinite
                        NumberAnimation { from: 1.0; to: 1.08; duration: 280 + index * 25 }
                        NumberAnimation { from: 1.08; to: 0.96; duration: 220 }
                        NumberAnimation { from: 0.96; to: 1.0; duration: 180 }
                    }
                }

                Image {
                    id: smoke
                    anchors.bottom: parent.top
                    anchors.bottomMargin: -6
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: root.imgW * 0.09
                    height: width
                    source: showBridge.textureUrl("smoke.png")
                    opacity: 0
                    visible: candle.isOut
                    SequentialAnimation {
                        running: candle.isOut
                        PauseAnimation { duration: 80 + index * 50 }
                        NumberAnimation { target: smoke; property: "opacity"; from: 0.8; to: 0; duration: 1200; easing.type: Easing.OutQuad }
                    }
                }

                MouseArea {
                    // Cover the stick AND the flame above it (the flame is a
                    // sibling anchored to this item's top edge, outside any
                    // hit area — taps on the flame tip fell through to the
                    // cake jelly below). Same F-22 gap fixed in Cake3DStage.
                    anchors.fill: parent
                    anchors.margins: -8
                    anchors.topMargin: -8 - flame.height
                    enabled: !candle.isOut
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.blowOut(index)
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: root.jelly()
        }
    }

    SequentialAnimation {
        id: entrance
        ParallelAnimation {
            NumberAnimation { target: group; property: "opacity"; from: 0; to: 1; duration: 500 }
            NumberAnimation { target: group; property: "scale"; from: 0.94; to: 1; duration: root.reducedMotion ? 200 : 620; easing.type: Easing.OutBack; easing.overshoot: 1.04 }
        }
    }

    // V1.1.0 fix #3c: replaces jellyDown above as the live jelly driver.
    FrameAnimation {
        id: jellyAnim
        running: false
        onCurrentFrameChanged: {
            var step = Math.min(frameTime, 1 / 30)   // frameTime is in seconds on this Qt build
            root.jellyV += (-root.jellyK * root.jellyX - root.jellyC * root.jellyV) * step
            root.jellyX = Math.max(-0.32, Math.min(0.32, root.jellyX + root.jellyV * step))
            group.scale = 1 - root.jellyX
            if (Math.abs(root.jellyX) < 0.008 && Math.abs(root.jellyV) < 0.10) {
                root.jellyX = 0
                root.jellyV = 0
                group.scale = 1
                jellyAnim.running = false
            }
        }
    }
}
