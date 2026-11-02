.pragma library

// Normalised trajectory points in [0..1] screen space, ordered for a pleasing
// sequential reveal.  Pure data: no timers, no randomness.

function heartPoint(t) {
    var x = 16 * Math.pow(Math.sin(t), 3)
    var y = 13 * Math.cos(t) - 5 * Math.cos(2 * t) - 2 * Math.cos(3 * t) - Math.cos(4 * t)
    return { x: x / 17.0, y: -y / 17.0 }
}

function heart(count, span) {
    // A hand-tuned heart outline, ordered bottom -> left -> right -> top.
    // More robust than sampling the parametric curve with few cards.
    var base = [
        [0.50, 0.88],
        [0.19, 0.62],
        [0.81, 0.62],
        [0.24, 0.30],
        [0.76, 0.30],
        [0.38, 0.20],
        [0.62, 0.20],
        [0.50, 0.34],
        [0.22, 0.46],
        [0.78, 0.46]
    ]
    var out = []
    var k = span / 0.72
    for (var i = 0; i < count; i++) {
        var p = base[i % base.length]
        out.push({ x: 0.5 + (p[0] - 0.5) * k, y: 0.5 + (p[1] - 0.5) * k })
    }
    return out
}

function circle(count, span) {
    var out = []
    for (var i = 0; i < count; i++) {
        var a = -Math.PI / 2 + (i / Math.max(1, count)) * Math.PI * 2
        out.push({ x: 0.5 + Math.cos(a) * 0.36 * span, y: 0.5 + Math.sin(a) * 0.30 * span })
    }
    return out
}

function wave(count, span) {
    var out = []
    for (var i = 0; i < count; i++) {
        var f = count <= 1 ? 0.5 : i / (count - 1)
        out.push({ x: 0.5 + (f - 0.5) * 0.78 * span, y: 0.5 + Math.sin(f * Math.PI * 3.0) * 0.15 * span })
    }
    return out
}

function diagonal(count, span) {
    var out = []
    for (var i = 0; i < count; i++) {
        var f = count <= 1 ? 0.5 : i / (count - 1)
        out.push({ x: 0.30 + f * 0.42 * span, y: 0.72 - f * 0.42 * span })
    }
    return out
}

function arc(count, span) {
    var out = []
    for (var i = 0; i < count; i++) {
        var f = count <= 1 ? 0.5 : i / (count - 1)
        var a = Math.PI - f * Math.PI
        out.push({ x: 0.5 + Math.cos(a) * 0.40 * span, y: 0.58 - Math.sin(a) * 0.30 * span })
    }
    return out
}

function spiral(count, span) {
    var out = []
    for (var i = 0; i < count; i++) {
        var f = count <= 1 ? 0 : i / (count - 1)
        var a = f * Math.PI * 2.6
        var r = (0.09 + f * 0.31) * span
        out.push({ x: 0.5 + Math.cos(a) * r, y: 0.52 + Math.sin(a) * r * 0.84 })
    }
    return out
}

function custom(points, count, span) {
    if (!points || points.length < 2)
        return diagonal(count, span)
    var out = []
    for (var i = 0; i < count; i++) {
        var f = count <= 1 ? 0 : i / (count - 1)
        var scaled = f * (points.length - 1)
        var idx = Math.min(points.length - 2, Math.floor(scaled))
        var local = scaled - idx
        var a = points[idx]
        var b = points[idx + 1]
        out.push({
            x: 0.5 + ((a[0] + (b[0] - a[0]) * local) - 0.5) * span,
            y: 0.5 + ((a[1] + (b[1] - a[1]) * local) - 0.5) * span
        })
    }
    return out
}

function generate(preset, count, customPoints, span) {
    var s = span || 0.72
    switch (preset) {
    case "heart": return heart(count, s)
    case "circle": return circle(count, s)
    case "wave": return wave(count, s)
    case "diagonal": return diagonal(count, s)
    case "arc": return arc(count, s)
    case "spiral": return spiral(count, s)
    case "custom": return custom(customPoints, count, s)
    default: return heart(count, s)
    }
}

// Clamp a card centre so the whole card stays inside the stage with margins.
function clampPoint(p, cardW, cardH, stageW, stageH, margin) {
    var m = margin === undefined ? 18 : margin
    var x = p.x * stageW
    var y = p.y * stageH
    var minX = cardW / 2 + m
    var maxX = stageW - cardW / 2 - m
    var minY = cardH / 2 + m + 24
    var maxY = stageH - cardH / 2 - m - 72
    return {
        x: Math.max(minX, Math.min(maxX, x)),
        y: Math.max(minY, Math.min(maxY, y))
    }
}
