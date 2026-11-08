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
    focus: !autoAdvance

    Keys.onPressed: function (event) {
        if (root.awaitingTap && (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
            root.finish()
            event.accepted = true
        }
    }

    readonly property var allCards: (cfg && cfg.cards) ? cfg.cards : []
    readonly property bool cardsEnabled: cfg ? cfg.cards_enabled !== false : true
    readonly property int allCardCount: allCards.length
    // 0 / missing = every configured card; otherwise cap to the first N.
    readonly property int cardLimit: {
        if (!cfg)
            return 0
        var lim = cfg.cards_limit !== undefined ? cfg.cards_limit : 0
        return (typeof lim === "number" && lim > 0) ? Math.min(allCardCount, Math.round(lim)) : allCardCount
    }
    readonly property int cardCount: cardsEnabled ? cardLimit : 0
    readonly property var cards: {
        if (!cardsEnabled)
            return []
        var out = []
        for (var i = 0; i < cardLimit; i++)
            out.push(allCards[i])
        return out
    }
    readonly property bool autoAdvance: cfg ? cfg.auto_advance !== false : true
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

    // Card rectangles for a trial scale. Kept separate from `targets` so the
    // scale can be fitted without creating a binding loop.
    function rectsAtScale(scale) {
        var pts = Trajectory.generate(traj.preset || "heart", cardCount, traj.custom_points || [], span)
        var out = []
        for (var i = 0; i < cardCount; i++) {
            var c = cards[i]
            var w = (c.width || 320) * scale
            var h = (c.height || 196) * scale
            var p = Trajectory.clampPoint(pts[i], w, h, width, height, 20)
            out.push({ "x": p.x - w / 2, "y": p.y - h / 2, "w": w, "h": h })
        }
        return out
    }

    function rectsClear(rects, gap) {
        for (var i = 0; i < rects.length; i++) {
            for (var j = i + 1; j < rects.length; j++) {
                var a = rects[i]
                var b = rects[j]
                if (a.x < b.x + b.w + gap && b.x < a.x + a.w + gap
                        && a.y < b.y + b.h + gap && b.y < a.y + a.h + gap)
                    return false
            }
        }
        return true
    }

    // V1.1.2 — the hand-tuned heart needs ~400px cards at 1080p, but the old
    // 0.78 floor kept them that large on small/odd screens, so the bottom
    // note collided with the two middle notes (and the two columns touched).
    // Shrink only as far as needed, keeping a gap that still absorbs the
    // float bob. Large stages keep the original scale untouched.
    readonly property real cardScale: {
        var base = Math.max(0.78, Math.min(1.0, Math.min(width / 1600, height / 900) * 1.12))
        if (cardCount <= 1 || cardCount > 10 || width <= 0 || height <= 0)
            return base
        var gap = Math.max(8, floatAmplitude * 2 + 6)
        var s = base
        for (var i = 0; i < 12; i++) {
            if (rectsClear(rectsAtScale(s), gap))
                break
            s = Math.max(0.5, s - 0.03)
        }
        return s
    }
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

    // ------------------------------------------------------------------ //
    // Note swarm (V1.1.0 fix #5)
    // ------------------------------------------------------------------ //
    readonly property var swarmCfg: (cfg && cfg.swarm) ? cfg.swarm : ({})
    readonly property bool swarmEnabled: swarmCfg.enabled === true
    readonly property int swarmCount: Math.max(40, Math.min(400, swarmCfg.count !== undefined ? swarmCfg.count : 320))
    readonly property int swarmSize: Math.max(20, Math.min(90, swarmCfg.note_size !== undefined ? swarmCfg.note_size : 44))
    // One shared ratio for the whole band: `note_size` is the width and the
    // height is derived, so every chip is exactly the same shape.
    readonly property real swarmRatio: {
        switch (swarmCfg.note_aspect) {
        case "4:3": return 4 / 3
        case "3:4": return 3 / 4
        case "16:9": return 16 / 9
        default: return 1
        }
    }
    readonly property int swarmNoteW: swarmSize
    readonly property int swarmNoteH: Math.max(16, Math.round(swarmSize / swarmRatio))
    readonly property int swarmOverlap: Math.max(50, Math.min(98, swarmCfg.overlap_pct !== undefined ? swarmCfg.overlap_pct : 90))
    readonly property int swarmStagger: Math.max(4, Math.min(60, swarmCfg.stagger_ms !== undefined ? swarmCfg.stagger_ms : 14))
    readonly property int swarmStaggerEffective: root.reducedMotion ? Math.max(30, swarmStagger) : swarmStagger
    readonly property int swarmFadeIn: Math.max(40, Math.min(600, swarmCfg.fade_in_ms !== undefined ? swarmCfg.fade_in_ms : 120))
    readonly property int swarmJitter: Math.max(0, Math.min(30, swarmCfg.jitter_px !== undefined ? swarmCfg.jitter_px : 6))
    readonly property int swarmMs: swarmEnabled ? swarmCount * swarmStaggerEffective + swarmFadeIn : 0

    // Fit the whole curve: shrink the trajectory span until the notes at the
    // requested overlap can cover the full arc length (so the band always
    // closes into a complete heart/line instead of trailing off).
    readonly property var swarmPoints: {
        if (!swarmEnabled)
            return []
        var n = swarmCount
        var step = swarmNoteW * (1 - swarmOverlap / 100)
        var pts = Trajectory.dense(traj.preset || "heart", n, span, traj.custom_points || [])
        var len = 0
        for (var i = 1; i < pts.length; i++) {
            var dx = (pts[i].x - pts[i - 1].x) * width
            var dy = (pts[i].y - pts[i - 1].y) * height
            len += Math.sqrt(dx * dx + dy * dy)
        }
        var k = 1
        if (len > 0 && n * step < len)
            k = (n * step) / len
        var fitted = Trajectory.dense(traj.preset || "heart", n, span * k, traj.custom_points || [])
        var out = []
        for (var j = 0; j < fitted.length; j++)
            out.push(Trajectory.clampPoint(fitted[j], swarmNoteW, swarmNoteH, width, height, 6))
        return out
    }

    readonly property string swarmAccentColor: {
        var pal = (tokens && tokens.color && tokens.color.palette) ? tokens.color.palette : ({})
        // The core pulls the accent into the candy tone band, so the raw
        // tertiary is fine here; no manual lightening needed.
        return (pal && pal.tertiary) ? String(pal.tertiary) : "#9fd8cb"
    }

    readonly property var swarmColors: {
        if (!swarmEnabled)
            return []
        var cs = styleCfg || ({})
        var out = []
        // A deliberate monochrome swarm is honoured verbatim.
        if (cs.mode === "single" && cs.single_color) {
            for (var a = 0; a < swarmCount; a++)
                out.push(cs.single_color)
            return out
        }
        // The band does NOT inherit the readable-card palette: those colours
        // are tuned for large frosted cards and can be dusty (tan/grey).
        // `swarmRamp` builds a candy-pastel ribbon whose hues always include
        // pink and powder blue and whose tone band keeps notes out of brown,
        // olive and grey.  `base_hue` picks the family, `harmony` the span.
        return colors.swarmRamp(cs.base_hue || 14, cs.harmony || "analogous",
                                swarmCount, [], swarmAccentColor)
    }

    // Optional per-note text (V1.1.1): one entry per line in the editor.
    readonly property var swarmTexts: {
        var raw = (swarmCfg.text_block !== undefined ? swarmCfg.text_block : "") || ""
        var out = []
        var parts = String(raw).split("
")
        for (var i = 0; i < parts.length; i++) {
            var t = parts[i].trim()
            if (t.length > 0)
                out.push(t)
        }
        return out
    }
    readonly property int swarmTextSize: Math.max(6, Math.min(22, swarmCfg.text_size !== undefined ? swarmCfg.text_size : 11))
    readonly property int swarmTextEvery: Math.max(1, Math.min(40, swarmCfg.text_every !== undefined ? swarmCfg.text_every : 6))

    readonly property var accents: {
        var cs = styleCfg
        var out = []
        if (cs.mode === "single" && cs.single_color)
            for (var a = 0; a < cardCount; a++) out.push(cs.single_color)
        else if (cs.mode === "palette" && cs.palette && cs.palette.length) {
            // Empty strings can survive from older hand-edited profiles; drop
            // them rather than handing invalid colours to QML.
            var pal = []
            for (var p = 0; p < cs.palette.length; p++) {
                if (cs.palette[p])
                    pal.push(cs.palette[p])
            }
            if (pal.length) {
                for (var b = 0; b < cardCount; b++) out.push(pal[b % pal.length])
            } else {
                var s0 = cs.saturation_bucket || [0.46, 0.68]
                var l0 = cs.lightness_bucket || [0.64, 0.78]
                out = colors.harmony(cs.base_hue || 14, cs.harmony || "analogous", s0[0], s0[1], l0[0], l0[1], cardCount)
            }
        } else {
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
    property int swarmSpawned: 0
    property real swarmStartMs: 0
    // Manual-advance state: the act has nothing left to animate and is
    // waiting for the user to tap anywhere (or press the global skip button).
    property bool awaitingTap: false

    // ------------------------------------------------------------------ //
    // Swarm layer — hundreds of small glass notes tracing the curve.
    // The model is a ListModel that grows by ONE row per tick: a Repeater
    // bound to a plain int REBUILDS every delegate on each change (verified:
    // growing 1..14 produced 105 constructions), which kept every note stuck
    // in its fade-in and made the band look washed-out. Appending rows keeps
    // existing delegates alive and lets each note play its pop exactly once.
    // ------------------------------------------------------------------ //
    ListModel {
        id: swarmModel
    }

    Item {
        id: swarmLayer
        anchors.fill: parent

        Repeater {
            model: swarmModel

            delegate: Item {
                id: swarmNote
                width: root.swarmNoteW
                height: root.swarmNoteH
                property int noteIndex: (typeof idx !== "undefined") ? idx : index
                property var pt: root.swarmPoints.length > noteIndex ? root.swarmPoints[noteIndex] : { "x": root.width / 2, "y": root.height / 2 }
                // deterministic per-note jitter (reproducible, no Math.random)
                property real jx: (((noteIndex * 37) % 100) / 100 - 0.5) * 2 * root.swarmJitter
                property real jy: (((noteIndex * 61) % 100) / 100 - 0.5) * 2 * root.swarmJitter
                property real rot: (((noteIndex * 29) % 100) / 100 - 0.5) * 10
                // optional text: spread the lines along the curve, lifted above
                // the stack so the words stay readable on the overlapping band
                property int textSlot: Math.floor(noteIndex / root.swarmTextEvery)
                property bool hasText: root.swarmTexts.length > 0 && noteIndex % root.swarmTextEvery === 0
                property color noteColor: root.swarmColors.length > noteIndex ? root.swarmColors[noteIndex] : "#ffd9b8"
                x: pt.x - width / 2 + jx
                y: pt.y - height / 2 + jy
                rotation: rot
                opacity: 0
                z: hasText ? 2 : 0
                Component.onCompleted: noteIn.start()

                // ---- liquid-glass note ------------------------------------ //
                // (1) soft coloured glow, contained in the chip footprint
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -1
                    radius: 4
                    color: swarmNote.noteColor
                    opacity: 0.22
                }
                // (2) glass body: bright sheen fading into a deeper edge
                Rectangle {
                    anchors.fill: parent
                    radius: 3
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.55)
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.lighter(swarmNote.noteColor, 1.55) }
                        GradientStop { position: 0.42; color: swarmNote.noteColor }
                        GradientStop { position: 1.0; color: Qt.darker(swarmNote.noteColor, 1.22) }
                    }
                }
                // (3) specular highlight band (the 琉璃 sheen)
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.topMargin: 1.5
                    anchors.leftMargin: 1.5
                    anchors.rightMargin: 1.5
                    height: Math.max(4, parent.height * 0.34)
                    radius: 2
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.55) }
                        GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.02) }
                    }
                }
                // (4) inner bottom shade = thickness / depth
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 1
                    anchors.leftMargin: 1
                    anchors.rightMargin: 1
                    height: 2
                    radius: 1
                    color: Qt.rgba(0, 0, 0, 0.16)
                }
                // (5) bright top rim
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.topMargin: 1
                    anchors.leftMargin: 3
                    anchors.rightMargin: 3
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.75)
                }
                Text {
                    visible: swarmNote.hasText
                    anchors.fill: parent
                    anchors.margins: 2
                    text: swarmNote.hasText
                          ? root.swarmTexts[swarmNote.textSlot % root.swarmTexts.length]
                          : ""
                    color: "#3b2a2f"
                    font.family: theme.hanFamily
                    font.pixelSize: Math.min(root.swarmTextSize, swarmNote.height * 0.34, swarmNote.width * 0.23)
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    style: Text.Outline
                    styleColor: Qt.rgba(1, 1, 1, 0.45)
                }

                ParallelAnimation {
                    id: noteIn
                    onFinished: {
                        swarmNote.opacity = 1
                        notePop.xScale = 1
                        notePop.yScale = 1
                    }
                    NumberAnimation { target: swarmNote; property: "opacity"; from: 0; to: 1; duration: root.reducedMotion ? 1 : Math.max(70, root.swarmFadeIn); easing.type: Easing.OutQuad }
                    SequentialAnimation {
                        NumberAnimation { target: notePop; property: "xScale"; from: root.reducedMotion ? 1 : 0.25; to: root.reducedMotion ? 1 : 1.12; duration: root.reducedMotion ? 1 : 150; easing.type: Easing.OutQuad }
                        NumberAnimation { target: notePop; property: "xScale"; to: 1; duration: root.reducedMotion ? 1 : 90; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
                    }
                    SequentialAnimation {
                        NumberAnimation { target: notePop; property: "yScale"; from: root.reducedMotion ? 1 : 0.25; to: root.reducedMotion ? 1 : 1.12; duration: root.reducedMotion ? 1 : 150; easing.type: Easing.OutQuad }
                        NumberAnimation { target: notePop; property: "yScale"; to: 1; duration: root.reducedMotion ? 1 : 90; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
                    }
                }
                transform: Scale { id: notePop; origin.x: swarmNote.width / 2; origin.y: swarmNote.height / 2; xScale: 1; yScale: 1 }
            }
        }
    }

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
                // Manual advance keeps the cards up until the tap; auto mode
                // still lets each card retire after its lifetime.
                if (root.autoAdvance)
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

    // ------------------------------------------------------------------ //
    // Manual advance (auto_advance = false)
    // The whole stage is the continuation target once the cards/swarm have
    // settled. The Player's skip button is a sibling above ShowStage, so it
    // still receives its own clicks.
    // ------------------------------------------------------------------ //
    MouseArea {
        anchors.fill: parent
        // Below the cards and the Player's skip button: bare items do not
        // consume clicks, so a tap anywhere still lands here.
        z: -1
        enabled: root.awaitingTap && !root.done
        visible: enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.finish()
    }

    Rectangle {
        id: advanceHint
        z: 61
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        width: advanceHintText.width + 40
        height: 34
        radius: 17
        color: Qt.rgba(0, 0, 0, 0.30)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.20)
        opacity: (root.awaitingTap && !root.done) ? 1 : 0
        visible: root.awaitingTap || opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }

        Text {
            id: advanceHintText
            anchors.centerIn: parent
            text: "轻触继续  ·  空格"
            color: "#fff5ee"
            font.family: theme.hanFamily
            font.pixelSize: 12
            font.weight: Font.Medium
            opacity: 0.92
        }
    }

    Timer {
        id: swarmTimer
        interval: root.swarmStaggerEffective
        repeat: true
        triggeredOnStart: true
        // The default timer quantises 14ms to the 15.6ms Windows tick, which
        // stretched a 320-note draw to ~5.1s. Catch up against the wall clock
        // instead of assuming one note per tick.
        onTriggered: {
            if (!root.swarmEnabled || root.swarmSpawned >= root.swarmCount) {
                stop()
                return
            }
            var target = Math.floor((Date.now() - root.swarmStartMs) / root.swarmStaggerEffective) + 1
            target = Math.min(root.swarmCount, Math.max(swarmModel.count + 1, target))
            // Append only the missing rows: ListModel inserts are incremental,
            // so already-visible notes keep their opacity and keep spinning.
            while (swarmModel.count < target)
                swarmModel.append({ "idx": swarmModel.count })
            root.swarmSpawned = swarmModel.count
            if (root.swarmSpawned >= root.swarmCount) {
                stop()
                root.onSwarmComplete()
            }
        }
    }

    // Readable cards wait for the swarm to finish drawing the curve. The
    // delay is anchored to the ACTUAL completion (not a nominal count*stagger
    // estimate), so a slow frame cannot push the cards later than intended.
    function onSwarmComplete() {
        if (done)
            return
        if (cardCount === 0) {
            settleAndFinish(true)
            return
        }
        if (swarmCfg.cards_delay_after === false)
            return
        startTimer.interval = root.startDelay
        startTimer.start()
    }

    // The act is done animating. Auto mode waits out the configured dwell;
    // manual mode exposes a tap target instead of silently moving on.
    function settleAndFinish(afterSwarm) {
        if (done || awaitingTap)
            return
        if (root.autoAdvance) {
            if (afterSwarm) {
                holdTimer.interval = Math.max(root.holdAfter, root.autoExitMs)
                holdTimer.start()
            } else {
                doneTimer.start()
            }
        } else {
            awaitingTap = true
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
        if (root.swarmEnabled) {
            swarmModel.clear()
            root.swarmSpawned = 0
            root.swarmStartMs = Date.now()
            swarmTimer.start()
            // Cards start immediately when the user opts out of waiting for
            // the swarm; total act time is then max(swarm, cards). With no
            // cards the band is the act, so settle on its completion.
            if (root.swarmCfg.cards_delay_after === false && cardCount > 0)
                startTimer.start()
            return
        }
        if (cardCount === 0) {
            settleAndFinish(false)
            return
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
            if (root.autoAdvance)
                holdTimer.start()
            else
                root.awaitingTap = true
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
        awaitingTap = false
        swarmTimer.stop()
        spawnTimer.stop()
        startTimer.stop()
        holdTimer.stop()
        doneTimer.stop()
        // The popups act stays alive under act 4 — fade the swarm band out
        // explicitly so 300+ notes do not sit beneath the confirm overlay.
        swarmFade.start()
        actFinished()
    }

    NumberAnimation {
        id: swarmFade
        target: swarmLayer
        property: "opacity"
        to: 0
        duration: 600
        easing.type: Easing.InQuad
    }

    function skip() {
        spawnTimer.stop()
        startTimer.stop()
        holdTimer.stop()
        swarmTimer.stop()
        for (var i = 0; i < cardCount; i++) {
            var it = repeater.itemAt(i)
            if (it)
                it.reveal()
        }
        finish()
    }

    Component.onCompleted: {
        start()
        if (!autoAdvance)
            forceActiveFocus()
    }
}
