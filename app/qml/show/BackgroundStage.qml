import QtQuick

// Procedural celebration backdrop: gradient + bokeh + stars + grain + vignette.
// Cheap at rest (Canvas paints once) while the bokeh layers drift slowly.
Item {
    id: root

    property var tokens: ({})
    property string variant: "paper"   // paper | cake | finale
    property bool reducedMotion: false
    property bool highContrast: false

    readonly property var bg: (tokens && tokens.background) ? tokens.background : ({})
    readonly property var stops: bg.stops || ["#2b1730", "#160d1c", "#0d0812"]
    readonly property var bokehColors: bg.bokeh || ["#ff9e7a", "#ffd6a5", "#8fd6c6", "#c9a7e8"]
    readonly property bool dark: !tokens || !tokens.ui || tokens.ui.mode !== "light"
    readonly property color baseColor: bg.base || "#140c1a"
    readonly property real vignetteStrength: bg.vignette !== undefined ? bg.vignette : 0.55
    readonly property bool stars: bg.stars === true && !highContrast
    readonly property bool dots: bg.confettiDots === true && !highContrast
    // Ambient dressing is on unless a theme opts out or contrast mode is on.
    readonly property bool ambience: bg.ambience !== false && !highContrast
    readonly property bool stringLights: ambience && dark
    readonly property bool bunting: ambience && !dark
    readonly property int bulbsPerSwag: 9
    readonly property var swagDefs: [
        { "x0": 0.02, "x1": 0.50, "y0": 0.012, "sag": 0.052 },
        { "x0": 0.50, "x1": 0.98, "y0": 0.012, "sag": 0.052 }
    ]

    // Position of `t` (0..1) along a swag, in stage pixels. The canvas draws
    // the wire and the bulb delegates sit on the same curve.
    function swagPoint(t, d) {
        return {
            "x": (d.x0 + (d.x1 - d.x0) * t) * width,
            "y": (d.y0 + d.sag * Math.sin(Math.PI * t)) * height
        }
    }

    readonly property var moteSpecs: {
        var out = []
        for (var i = 0; i < 16; i++) {
            out.push({
                "fx": 0.06 + ((i * 37) % 100) / 112,
                "fy": 0.18 + ((i * 53) % 100) / 155,
                "s": 10 + ((i * 29) % 18),
                "o": 0.10 + ((i * 17) % 20) / 100,
                "dur": 12000 + (i % 5) * 2600,
                "sway": 6 + (i % 4) * 3
            })
        }
        return out
    }

    Rectangle {
        anchors.fill: parent
        color: root.variant === "cake" ? (root.dark ? "#08050d" : "#fff1df") : root.baseColor
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            var w = width, h = height
            var g = ctx.createLinearGradient(w * 0.15, 0, w * 0.85, h)
            var stops = root.stops.length ? root.stops : ["#2b1730", "#160d1c"]
            for (var i = 0; i < stops.length; i++)
                g.addColorStop(i / Math.max(1, stops.length - 1), stops[i])
            ctx.fillStyle = g
            ctx.fillRect(0, 0, w, h)

            // soft wash from above: the room reads as lit, not flat
            if (root.ambience) {
                var tg = ctx.createRadialGradient(w * 0.5, -h * 0.18, 0, w * 0.5, -h * 0.18, h * 1.15)
                tg.addColorStop(0, Qt.rgba(1.0, 0.88, 0.70, root.dark ? 0.17 : 0.14))
                tg.addColorStop(0.5, Qt.rgba(1.0, 0.82, 0.64, root.dark ? 0.055 : 0.045))
                tg.addColorStop(1, Qt.rgba(0, 0, 0, 0))
                ctx.fillStyle = tg
                ctx.fillRect(0, 0, w, h)
            }

            // warm centre bloom
            var rg = ctx.createRadialGradient(w * 0.5, h * 0.46, 0, w * 0.5, h * 0.5, Math.max(w, h) * 0.62)
            rg.addColorStop(0, Qt.rgba(1.0, 0.72, 0.56, root.dark ? 0.16 : 0.20))
            rg.addColorStop(0.55, Qt.rgba(1.0, 0.68, 0.54, 0.05))
            rg.addColorStop(1, Qt.rgba(0, 0, 0, 0))
            ctx.fillStyle = rg
            ctx.fillRect(0, 0, w, h)

            if (root.variant === "cake") {
                var cg = ctx.createRadialGradient(w * 0.5, h * 0.64, 0, w * 0.5, h * 0.64, Math.max(w, h) * 0.5)
                cg.addColorStop(0, Qt.rgba(1.0, 0.66, 0.36, 0.14))
                cg.addColorStop(1, Qt.rgba(0, 0, 0, 0))
                ctx.fillStyle = cg
                ctx.fillRect(0, 0, w, h)
            }

            // fairy-light wires (dark) / bunting (light). Bulbs are separate
            // items so they can twinkle; the wire itself is painted once.
            if (root.stringLights || root.bunting) {
                for (var sw = 0; sw < root.swagDefs.length; sw++) {
                    var sd = root.swagDefs[sw]
                    ctx.beginPath()
                    for (var sk = 0; sk <= 28; sk++) {
                        var sp = root.swagPoint(sk / 28, sd)
                        if (sk === 0)
                            ctx.moveTo(sp.x, sp.y)
                        else
                            ctx.lineTo(sp.x, sp.y)
                    }
                    ctx.strokeStyle = root.dark ? "rgba(255,232,196,0.20)" : "rgba(74,44,42,0.30)"
                    ctx.lineWidth = 1.2
                    ctx.stroke()

                    if (root.bunting) {
                        for (var f = 0; f < root.bulbsPerSwag; f++) {
                            var ft = (f + 0.5) / root.bulbsPerSwag
                            var fp = root.swagPoint(ft, sd)
                            var fc = Qt.color(root.bokehColors[f % root.bokehColors.length])
                            ctx.fillStyle = Qt.rgba(fc.r, fc.g, fc.b, 0.62)
                            ctx.beginPath()
                            ctx.moveTo(fp.x - 9, fp.y + 1)
                            ctx.lineTo(fp.x + 9, fp.y + 1)
                            ctx.lineTo(fp.x, fp.y + 26)
                            ctx.closePath()
                            ctx.fill()
                        }
                    }
                }
            }

            // deterministic star field
            if (root.stars) {
                var seed = 20261102
                function rnd() {
                    seed = (seed * 1664525 + 1013904223) % 4294967296
                    return seed / 4294967296
                }
                for (var s = 0; s < 130; s++) {
                    var x = rnd() * w
                    var y = rnd() * h * 0.92
                    var r = rnd() * 1.6 + 0.3
                    var a = rnd() * 0.55 + 0.10
                    ctx.fillStyle = Qt.rgba(1, 0.95, 0.86, a)
                    ctx.beginPath()
                    ctx.arc(x, y, r, 0, Math.PI * 2)
                    ctx.fill()
                }
            }

            // playful dots for the light cartoon theme
            if (root.dots) {
                var seed2 = 77
                function rnd2() {
                    seed2 = (seed2 * 1103515245 + 12345) % 2147483648
                    return seed2 / 2147483648
                }
                for (var d = 0; d < 70; d++) {
                    var dx = rnd2() * w
                    var dy = rnd2() * h
                    var dr = rnd2() * 4 + 1.2
                    var c = root.bokehColors[d % root.bokehColors.length]
                    var q = Qt.color(c)
                    ctx.fillStyle = Qt.rgba(q.r, q.g, q.b, 0.28)
                    ctx.beginPath()
                    ctx.arc(dx, dy, dr, 0, Math.PI * 2)
                    ctx.fill()
                }
            }
        }
    }

    // soft bokeh, drifting slowly
    Repeater {
        model: 4
        Image {
            id: blob
            property var positions: [
                { "fx": 0.18, "fy": 0.28, "s": 0.62, "o": 0.34 },
                { "fx": 0.80, "fy": 0.20, "s": 0.52, "o": 0.26 },
                { "fx": 0.68, "fy": 0.80, "s": 0.70, "o": 0.30 },
                { "fx": 0.30, "fy": 0.72, "s": 0.46, "o": 0.22 }
            ]
            property var pos: positions[index % 4]
            property var names: ["bokeh_peach.png", "bokeh_cream.png", "bokeh_teal.png", "bokeh_lilac.png"]
            property real driftX: 0
            property real driftY: 0
            width: Math.max(280, root.width * pos.s)
            height: width
            source: showBridge.textureUrl(names[index % 4])
            x: root.width * pos.fx - width / 2 + driftX
            y: root.height * pos.fy - height / 2 + driftY
            opacity: root.highContrast ? 0 : pos.o * (root.bg.bokehOpacity !== undefined ? root.bg.bokehOpacity : 0.38)
            visible: !root.highContrast
            fillMode: Image.PreserveAspectFit
            smooth: true
            SequentialAnimation on driftX {
                running: !root.reducedMotion
                loops: Animation.Infinite
                NumberAnimation { from: -14; to: 18; duration: 14000 + index * 3500; easing.type: Easing.InOutSine }
                NumberAnimation { from: 18; to: -14; duration: 14000 + index * 3500; easing.type: Easing.InOutSine }
            }
            SequentialAnimation on driftY {
                running: !root.reducedMotion
                loops: Animation.Infinite
                NumberAnimation { from: 10; to: -16; duration: 17000 + index * 2600; easing.type: Easing.InOutSine }
                NumberAnimation { from: -16; to: 10; duration: 17000 + index * 2600; easing.type: Easing.InOutSine }
            }
        }
    }

    // warm pool of light under the cake stand
    Image {
        visible: root.variant === "cake" && !root.highContrast
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -height * 0.34
        width: root.width * 1.28
        height: root.height * 0.46
        source: showBridge.textureUrl("bokeh_cream.png")
        fillMode: Image.Stretch
        smooth: true
        opacity: 0.22
    }

    // warm bulbs on the two swags (dark themes)
    Item {
        id: bulbLayer
        anchors.fill: parent
        visible: root.stringLights

        Repeater {
            model: root.stringLights ? root.bulbsPerSwag * 2 : 0
            Item {
                id: bulb
                property int swagIndex: index < root.bulbsPerSwag ? 0 : 1
                property real t: ((index % root.bulbsPerSwag) + 0.5) / root.bulbsPerSwag
                property var p: root.swagPoint(t, root.swagDefs[swagIndex])
                width: 34
                height: 34
                x: p.x - width / 2
                y: p.y - height / 2 + 4
                opacity: 0.82

                Image {
                    anchors.centerIn: parent
                    width: 38
                    height: 38
                    source: showBridge.textureUrl("bokeh_cream.png")
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    opacity: 0.78
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 6
                    height: 6
                    radius: 3
                    color: "#fff6e0"
                }
                SequentialAnimation on opacity {
                    running: !root.reducedMotion
                    loops: Animation.Infinite
                    NumberAnimation {
                        from: 0.52; to: 0.94
                        duration: 1900 + index * 170
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        from: 0.94; to: 0.52
                        duration: 2100 + index * 150
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }
    }

    // slow dust motes drifting through the light
    Repeater {
        model: root.ambience ? 16 : 0

        Image {
            id: mote
            property var spec: root.moteSpecs[index % root.moteSpecs.length]
            property real driftX: 0
            property real driftY: 0
            width: spec.s
            height: width
            x: root.width * spec.fx - width / 2 + driftX
            y: root.height * spec.fy - height / 2 + driftY
            source: showBridge.textureUrl(index % 2 === 0 ? "bokeh_cream.png" : "bokeh_peach.png")
            fillMode: Image.PreserveAspectFit
            smooth: true
            opacity: spec.o
            visible: !root.highContrast
            SequentialAnimation on driftY {
                running: !root.reducedMotion
                loops: Animation.Infinite
                NumberAnimation {
                    from: 18; to: -42
                    duration: spec.dur
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    from: -42; to: 18
                    duration: spec.dur
                    easing.type: Easing.InOutSine
                }
            }
            SequentialAnimation on driftX {
                running: !root.reducedMotion
                loops: Animation.Infinite
                NumberAnimation {
                    from: -spec.sway; to: spec.sway
                    duration: 9000 + index * 420
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    from: spec.sway; to: -spec.sway
                    duration: 9000 + index * 420
                    easing.type: Easing.InOutSine
                }
            }
            SequentialAnimation on opacity {
                running: !root.reducedMotion && !root.highContrast
                loops: Animation.Infinite
                NumberAnimation {
                    from: spec.o; to: spec.o * 0.35
                    duration: 2600 + index * 140
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    from: spec.o * 0.35; to: spec.o
                    duration: 2600 + index * 140
                    easing.type: Easing.InOutSine
                }
            }
        }
    }

    Image {
        anchors.fill: parent
        source: showBridge.textureUrl("vignette.png")
        fillMode: Image.Stretch
        opacity: root.highContrast ? 0 : root.vignetteStrength
        visible: !root.highContrast
    }

    Image {
        anchors.fill: parent
        source: showBridge.textureUrl("grain.png")
        fillMode: Image.Tile
        opacity: root.highContrast ? 0 : 0.55
        visible: !root.highContrast
    }
}
