import QtQuick

// canvas-confetti model ported to QML: initial velocity + gravity + drag +
// 3D flip, normalised origin, capped particle count (F-23).
Canvas {
    id: canvas

    property var config: ({})
    property bool active: false
    property bool reducedMotion: false

    property var particles: []
    property bool ownTimer: true
    property int burstIndex: 0
    property real lastTick: 0

    readonly property var cfg: config || ({})
    readonly property var colorsList: cfg.colors || ["#ff8fab", "#ffd166", "#8ecae6", "#b8e0d2", "#cdb4db"]
    readonly property int bursts: cfg.bursts !== undefined ? cfg.bursts : 3
    readonly property int perBurst: cfg.particles_per_burst !== undefined ? cfg.particles_per_burst : 110
    readonly property real gravity: cfg.gravity !== undefined ? cfg.gravity : 900
    readonly property real drag: cfg.drag !== undefined ? cfg.drag : 0.992
    readonly property real originX: cfg.origin_x !== undefined ? cfg.origin_x : 0.5
    readonly property real originY: cfg.origin_y !== undefined ? cfg.origin_y : 0.58
    readonly property real spread: cfg.spread !== undefined ? cfg.spread : 68
    readonly property int maxParticles: cfg.max_particles !== undefined ? cfg.max_particles : 420

    anchors.fill: parent
    visible: active
    renderStrategy: Canvas.Cooperative

    Component.onCompleted: lastTick = Date.now()

    onActiveChanged: {
        if (active) {
            particles = []
            burstIndex = 0
            lastTick = Date.now()
            burstTimer.interval = 1
            burstTimer.start()
            tickTimer.start()
        } else {
            burstTimer.stop()
            tickTimer.stop()
            particles = []
            requestPaint()
        }
    }

    function spawn(count) {
        var arr = particles.slice()
        var n = Math.min(count, Math.max(0, maxParticles - arr.length))
        var w = width
        var h = height
        var ox = w * originX
        var oy = h * originY
        var scale = Math.max(0.7, Math.min(1.5, h / 900))
        for (var i = 0; i < n; i++) {
            var theta = ((Math.random() - 0.5) * spread) * Math.PI / 180
            var speed = (520 + Math.random() * 620) * scale
            var life = 5.0 + Math.random() * 2.0
            arr.push({
                x: ox + (Math.random() - 0.5) * 16,
                y: oy + (Math.random() - 0.5) * 10,
                vx: Math.sin(theta) * speed,
                vy: -Math.cos(theta) * speed,
                w: (6 + Math.random() * 7) * scale,
                h: (10 + Math.random() * 12) * scale,
                color: colorsList[i % colorsList.length],
                rot: Math.random() * Math.PI * 2,
                vr: (Math.random() - 0.5) * 12,
                flip: Math.random() * Math.PI * 2,
                flipSpeed: reducedMotion ? 0 : 4 + Math.random() * 8,
                ttl: life,
                round: Math.random() < 0.18
            })
        }
        particles = arr
    }

    Timer {
        id: burstTimer
        interval: 1
        repeat: false
        onTriggered: {
            if (!canvas.active)
                return
            var count = canvas.reducedMotion ? Math.min(28, canvas.perBurst) : canvas.perBurst
            canvas.spawn(count)
            canvas.burstIndex += 1
            if (canvas.burstIndex < (canvas.reducedMotion ? 1 : canvas.bursts)) {
                burstTimer.interval = 420 + Math.random() * 240
                burstTimer.start()
            }
        }
    }

    Timer {
        id: tickTimer
        interval: canvas.reducedMotion ? 33 : 16
        repeat: true
        onTriggered: canvas.step()
    }

    function step() {
        var now = Date.now()
        var dt = Math.min(0.05, (now - lastTick) / 1000)
        lastTick = now
        var arr = particles.slice()
        var out = []
        var damp = Math.pow(drag, dt * 60)
        for (var i = 0; i < arr.length; i++) {
            var p = arr[i]
            p.vy += gravity * dt
            p.vx *= damp
            p.vy *= damp
            p.x += p.vx * dt
            p.y += p.vy * dt
            p.rot += p.vr * dt
            p.flip += p.flipSpeed * dt
            p.ttl -= dt
            if (p.ttl > 0 && p.y < height + 120)
                out.push(p)
        }
        particles = out
        requestPaint()
    }

    onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        var arr = particles
        for (var i = 0; i < arr.length; i++) {
            var p = arr[i]
            ctx.save()
            ctx.translate(p.x, p.y)
            ctx.rotate(p.rot)
            var sx = reducedMotion ? 1 : Math.cos(p.flip)
            if (sx < 0)
                sx = -sx * 0.85 + 0.15
            ctx.scale(sx, 1)
            ctx.globalAlpha = Math.max(0, Math.min(1, p.ttl / 1.4))
            ctx.fillStyle = p.color
            if (p.round) {
                ctx.beginPath()
                ctx.arc(0, 0, p.w / 2, 0, Math.PI * 2)
                ctx.fill()
            } else {
                ctx.fillRect(-p.w / 2, -p.h / 2, p.w, p.h)
            }
            ctx.restore()
        }
    }

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
}
