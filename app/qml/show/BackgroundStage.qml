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
