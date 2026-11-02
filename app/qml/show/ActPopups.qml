import QtQuick
import "Trajectory.js" as Trajectory

// Act 3 — the祝福 cards fly out along a trajectory, stagger 40–80 ms.
Item {
    id: root

    property var profile: ({})
    property var cfg: ({})
    property var tokens: ({})
    property bool reducedMotion: false
    property bool highContrast: false
    property real speedScale: 1.0
    signal actFinished()
    signal sfx(string kind)

    anchors.fill: parent

    readonly property var cards: (cfg && cfg.cards) ? cfg.cards : []
    readonly property int cardCount: cards.length
    readonly property var seq: (cfg && cfg.sequence) ? cfg.sequence : ({})
    readonly property var traj: (cfg && cfg.trajectory) ? cfg.trajectory : ({})
    readonly property var styleCfg: (cfg && cfg.color_strategy) ? cfg.color_strategy : ({})

    readonly property int startDelay: seq.start_delay_ms !== undefined ? seq.start_delay_ms : 260
    readonly property int stagger: {
        if (seq.total_duration_override_ms && cardCount > 1) {
            var per = (seq.total_duration_override_ms - startDelay) / (cardCount - 1)
            return Math.max(16, Math.round(per))
        }
        return seq.stagger_ms !== undefined ? seq.stagger_ms : 60
    }
    readonly property int lifetime: seq.lifetime_ms !== undefined ? seq.lifetime_ms : 8000
    readonly property int fadeMs: seq.fade_ms !== undefined ? seq.fade_ms : 220
    readonly property real finalOpacity: seq.opacity_final !== undefined ? seq.opacity_final : 0.0
    readonly property int maxLiving: seq.max_living !== undefined ? seq.max_living : 7
    readonly property string appearFrom: seq.appear_from || "letter"
    readonly property int holdAfter: seq.hold_after_ms !== undefined ? seq.hold_after_ms : 1400
    readonly property int floatAmplitude: seq.float_amplitude !== undefined ? seq.float_amplitude : 6
    readonly property real span: traj.span !== undefined ? traj.span : 0.72
    readonly property real cardScale: Math.max(0.78, Math.min(1.0, Math.min(width / 1600, height / 900) * 1.12))
    readonly property int flightMs: traj.duration_ms ? Math.min(820, Math.max(320, Math.round(traj.duration_ms * 0.45))) : 560
    readonly property int flightEasingType: {
        switch (traj.easing) {
        case "linear": return Easing.Linear
        case "outBack": return Easing.OutBack
        case "inOutCubic": return Easing.InOutCubic
        default: return Easing.OutCubic
        }
    }

    readonly property var targets: {
        var pts = Trajectory.generate(traj.preset || "heart", cardCount, traj.custom_points || [], span)
        var out = []
        for (var i = 0; i < cardCount; i++) {
            var c = cards[i]
            var w = (c.width || 320) * cardScale
            var h = (c.height || 196) * cardScale
            out.push(Trajectory.clampPoint(pts[i], w, h, width, height, 20))
        }
        return out
    }

    readonly property var accents: {
        var cs = styleCfg
        var out = []
        if (cs.mode === "single" && cs.single_color)
            for (var a = 0; a < cardCount; a++) out.push(cs.single_color)
        else if (cs.mode === "palette" && cs.palette && cs.palette.length)
            for (var b = 0; b < cardCount; b++) out.push(cs.palette[b % cs.palette.length])
        else {
            var s = cs.saturation_bucket || [0.46, 0.68]
            var l = cs.lightness_bucket || [0.64, 0.78]
            out = colors.harmony(cs.base_hue || 14, cs.harmony || "analogous", s[0], s[1], l[0], l[1], cardCount)
        }
        for (var i = 0; i < cardCount; i++) {
            if (cards[i].accent)
                out[i] = cards[i].accent
        }
        return out
    }

    property int spawned: 0
    property bool done: false
    property bool running: false

    Repeater {
        id: repeater
        model: root.cardCount

        delegate: Item {
            id: delegate
            width: (root.cards[index].width || 320) * root.cardScale
            height: (root.cards[index].height || 196) * root.cardScale
            x: target.x - width / 2
            y: target.y - height / 2
            opacity: 0

            readonly property var cardData: root.cards[index] || ({})
            readonly property var target: root.targets[index] || { "x": root.width / 2, "y": root.height / 2 }
            readonly property color accent: root.accents[index] || "#ffb08a"
            readonly property int radius: 18

            property bool spawnedHere: false

            function originScreen() {
                if (root.appearFrom === "trajectory")
                    return Qt.point(delegate.x + delegate.width / 2, delegate.y + delegate.height / 2)
                if (root.appearFrom === "center")
                    return Qt.point(root.width / 2, root.height / 2)
                return Qt.point(root.width * 0.5, root.height * 0.94)
            }

            Item {
                id: content
                anchors.fill: parent
                opacity: 0
                scale: 0.4
                transform: [
                    Translate { id: offset },
                    Translate { id: floatOffset }
                ]

                Loader {
                    id: cardLoader
                    anchors.fill: parent
                    source: {
                        var rev = showBridge.pluginRevision
                        var slot = showBridge.slotComponent("PopupCard")
                        return slot !== "" ? slot : "PopupCard.qml"
                    }
                    onLoaded: bind()
                    onStatusChanged: {
                        if (status === Loader.Error && source !== "PopupCard.qml" && source !== "") {
                            source = "PopupCard.qml"
                            bind()
                        }
                    }
                    function bind() {
                        if (!item)
                            return
                        item.card = delegate.cardData
                        item.tokens = root.tokens
                        item.cardWidth = delegate.width
                        item.cardHeight = delegate.height
                        item.accentColor = delegate.accent
                        item.displayStyle = delegate.cardData.style || (root.cfg ? root.cfg.style : "glass") || "glass"
                        // Optional contract v1.1 fields: older plugins may not
                        // declare them; never break a slot over a preference.
                        try { item.highContrast = root.highContrast } catch (e) { }
                        try { item.reducedMotion = root.reducedMotion } catch (e) { }
                    }
                    Component.onCompleted: bind()
                }

                // gentle 3D tilt
                rotation: root.reducedMotion ? 0 : (index % 2 === 0 ? -1.4 : 1.2)

                ParallelAnimation {
                    id: spawnAnim
                    NumberAnimation { target: content; property: "opacity"; from: 0; to: 1; duration: 240; easing.type: Easing.OutQuad }
                    NumberAnimation {
                        target: content; property: "scale"
                        from: root.reducedMotion ? 0.96 : 0.38; to: 1
                        duration: root.reducedMotion ? 200 : root.flightMs
                        easing.type: root.flightEasingType
                        easing.overshoot: 1.15
                    }
                    NumberAnimation {
                        target: offset; property: "x"
                        to: 0
                        duration: root.reducedMotion ? 1 : root.flightMs
                        easing.type: root.flightEasingType
                    }
                    NumberAnimation {
                        target: offset; property: "y"
                        to: 0
                        duration: root.reducedMotion ? 1 : root.flightMs
                        easing.type: root.flightEasingType
                    }
                }

                SequentialAnimation {
                    id: bobAnim
                    loops: Animation.Infinite
                    running: false
                    NumberAnimation { target: floatOffset; property: "y"; from: 0; to: -root.floatAmplitude * root.cardScale; duration: 2600 + index * 180; easing.type: Easing.InOutSine }
                    NumberAnimation { target: floatOffset; property: "y"; from: -root.floatAmplitude * root.cardScale; to: 0; duration: 2600 + index * 180; easing.type: Easing.InOutSine }
                }

                Timer {
                    id: lifeTimer
                    interval: root.lifetime
                    onTriggered: delegate.fadeNow()
                }
            }

            function playSpawn() {
                if (spawnedHere)
                    return
                spawnedHere = true
                var origin = originScreen()
                offset.x = origin.x - (delegate.x + delegate.width / 2)
                offset.y = origin.y - (delegate.y + delegate.height / 2)
                delegate.opacity = 1
                spawnAnim.start()
                lifeTimer.start()
                if (!root.reducedMotion && root.floatAmplitude > 0)
                    bobAnim.running = true
            }

            function fadeNow() {
                if (!spawnedHere)
                    return
                lifeTimer.stop()
                fadeAnim.start()
            }

            function reveal() {
                spawnedHere = true
                delegate.opacity = 1
                content.opacity = 1
                content.scale = 1
                offset.x = 0
                offset.y = 0
            }

            NumberAnimation {
                id: fadeAnim
                target: content
                property: "opacity"
                to: root.finalOpacity
                duration: root.fadeMs
                easing.type: Easing.InQuad
            }
        }
    }

    Timer {
        id: startTimer
        interval: root.startDelay
        onTriggered: root.spawnNext()
    }

    Timer {
        id: spawnTimer
        interval: root.reducedMotion ? Math.max(90, root.stagger) : root.stagger
        repeat: true
        onTriggered: root.spawnNext()
    }

    function start() {
        if (running)
            return
        running = true
        if (cardCount === 0) {
            doneTimer.start()
            return
        }
        if (root.reducedMotion) {
            // staggered fade-in at final positions
        }
        startTimer.start()
    }

    function spawnNext() {
        if (done || spawned >= cardCount) {
            spawnTimer.stop()
            return
        }
        var item = repeater.itemAt(spawned)
        if (item) {
            item.playSpawn()
            sfx("pop")
            if (spawned >= maxLiving) {
                var old = repeater.itemAt(spawned - maxLiving)
                if (old)
                    old.fadeNow()
            }
        }
        spawned += 1
        if (spawned >= cardCount) {
            spawnTimer.stop()
            holdTimer.start()
        } else if (!spawnTimer.running) {
            spawnTimer.start()
        }
    }

    property int autoExitMs: {
        var exit = cfg ? cfg.exit : ""
        if (exit && exit.indexOf("auto:") === 0)
            return parseInt(exit.substring(5)) || 0
        return 0
    }

    Timer {
        id: holdTimer
        interval: Math.max(root.holdAfter, root.autoExitMs)
        onTriggered: root.finish()
    }

    Timer {
        id: doneTimer
        interval: 400
        onTriggered: root.finish()
    }

    function finish() {
        if (done)
            return
        done = true
        completed()
    }

    function skip() {
        spawnTimer.stop()
        startTimer.stop()
        holdTimer.stop()
        for (var i = 0; i < cardCount; i++) {
            var it = repeater.itemAt(i)
            if (it)
                it.reveal()
        }
        finish()
    }

    Component.onCompleted: start()
}
