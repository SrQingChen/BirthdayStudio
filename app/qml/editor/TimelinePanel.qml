import QtQuick
import "../components"

Item {
    id: root

    property string selectedAct: "intro"
    property string playingAct: ""
    property bool playing: false
    signal selectAct(string id)
    signal playFrom(string id)

    readonly property var ui: (theme.tokens && theme.tokens.ui) ? theme.tokens.ui : ({})
    readonly property color ink: ui.text || "#f5ede8"
    readonly property color muted: ui.textMuted || "#b9a9b6"
    readonly property color accent: ui.accent || "#ffb08a"
    readonly property color borderColor: ui.panelBorder || "#ffffff14"
    readonly property var paletteMap: (theme.tokens && theme.tokens.color && theme.tokens.color.palette) ? theme.tokens.color.palette : ({})
    readonly property var draft: session.draft
    readonly property var actsCfg: (draft && draft.acts) ? draft.acts : ({})

    readonly property var ids: ["intro", "wax", "popups", "confirm", "dissolve", "cake", "finale"]
    readonly property var labels: ["开场", "火漆", "祝福", "收下", "揭幕", "蛋糕", "终幕"]
    readonly property var colors: [
        paletteMap.primary || "#ffb08a",
        paletteMap.secondary || "#ffd5a6",
        paletteMap.tertiary || "#9fd8cb",
        paletteMap.primary || "#ffb08a",
        paletteMap.outline || "#f5d8c8",
        paletteMap.secondary || "#ffd5a6",
        paletteMap.primary || "#ffb08a"
    ]

    readonly property var lanes: {
        var out = []
        var t = 0.0
        for (var i = 0; i < ids.length; i++) {
            var id = ids[i]
            var cfg = actsCfg[id]
            var enabled = cfg ? cfg.enabled !== false : false
            var dur = 0
            if (enabled) {
                switch (id) {
                case "intro": dur = 3.2; break
                case "wax": dur = Math.max(4, (cfg.letter && cfg.letter.text ? cfg.letter.text.length / Math.max(6, cfg.letter.chars_per_second || 24) : 5) + 2.2); break
                case "popups": {
                    var allCards = cfg.cards || []
                    var n = allCards.length
                    // Match the runtime: the card layer can be switched off,
                    // and `cards_limit` caps the first N configured cards.
                    if (cfg.cards_enabled === false)
                        n = 0
                    else if (cfg.cards_limit > 0)
                        n = Math.min(n, cfg.cards_limit)
                    var st = (cfg.sequence && cfg.sequence.stagger_ms) || 60
                    var delay = (cfg.sequence && cfg.sequence.start_delay_ms) || 260
                    var auto = cfg.auto_advance !== false
                    var hold = auto ? ((cfg.sequence && cfg.sequence.hold_after_ms) || 3800) : 0
                    var sw = cfg.swarm || {}
                    var cardsS = n > 0 ? delay / 1000 + Math.max(0, n - 1) * st / 1000 + hold / 1000 : 0
                    var swarmS = 0
                    if (sw.enabled !== false) {
                        // Low-motion mode raises the stagger to >=30ms at runtime.
                        var swSt = Math.max(4, Math.min(60, sw.stagger_ms !== undefined ? sw.stagger_ms : 14))
                        swarmS = ((sw.count !== undefined ? sw.count : 320) * swSt
                                  + (sw.fade_in_ms !== undefined ? sw.fade_in_ms : 120)) / 1000
                    }
                    if (n === 0 && sw.enabled === false)
                        dur = auto ? 0.4 : 0
                    else if (n === 0)
                        dur = swarmS + hold / 1000
                    else if (sw.enabled === false)
                        dur = cardsS
                    else if (sw.cards_delay_after === false)
                        dur = Math.max(swarmS, cardsS)
                    else
                        dur = swarmS + cardsS
                    break
                }
                case "confirm": dur = 2.6; break
                case "dissolve": dur = (cfg.duration_ms || 560) / 1000; break
                case "cake": dur = 14; break
                case "finale": dur = 8; break
                }
            }
            out.push({ id: id, label: labels[i], color: colors[i], enabled: enabled, duration: dur, start: t, cfg: cfg })
            if (enabled)
                t += dur
        }
        return { lanes: out, total: Math.max(0.1, t) }
    }

    readonly property real laneH: 18
    readonly property real laneGap: 3
    readonly property real labelW: 108
    readonly property real timelineW: Math.max(200, width - labelW - 40)

    height: 188

    Rectangle { anchors.fill: parent; color: (ui.panel ? ui.panel : "#171020"); opacity: 0.98 }
    Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: root.borderColor }

    // header
    Row {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        height: 34
        spacing: 10
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "时间轴 · 七幕编排"
            color: root.ink
            font.family: theme.hanFamily
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "总时长约 " + Math.round(root.lanes.total) + "s"
            color: root.muted
            font.family: theme.hanFamily
            font.pixelSize: 10
        }
        EdButton {
            anchors.verticalCenter: parent.verticalCenter
            text: "从选中幕试演"
            small: true
            onClicked: root.playFrom(root.selectedAct)
        }
    }

    // lanes
    Item {
        id: lanesArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.bottom: audioTrack.top
        anchors.leftMargin: 10
        anchors.rightMargin: 12

        Repeater {
            model: root.lanes.lanes
            Item {
                width: lanesArea.width
                height: root.laneH
                y: index * (root.laneH + root.laneGap) + 2

                readonly property bool selected: root.selectedAct === modelData.id
                readonly property bool playingThis: root.playingAct === modelData.id

                // label toggle dot
                Rectangle {
                    x: 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14
                    height: 14
                    radius: 7
                    color: modelData.enabled ? modelData.color : "transparent"
                    border.width: 1
                    border.color: modelData.enabled ? Qt.rgba(255, 255, 255, 0.4) : Qt.rgba(1, 1, 1, 0.2)
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: session.setField("acts." + modelData.id + ".enabled", !modelData.enabled)
                    }
                }
                Text {
                    x: 24
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.label
                    color: modelData.enabled ? (parent.selected ? root.ink : root.muted) : Qt.rgba(0.6, 0.6, 0.6, 0.45)
                    font.family: theme.hanFamily
                    font.pixelSize: 11
                    font.weight: parent.selected ? Font.DemiBold : Font.Normal
                }
                Text {
                    x: 66
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.enabled ? (Math.round(modelData.duration) + "s") : "跳过"
                    color: root.muted
                    opacity: 0.55
                    font.family: "Consolas"
                    font.pixelSize: 9
                }
                MouseArea {
                    x: 0
                    width: root.labelW
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectAct(modelData.id)
                    onDoubleClicked: root.playFrom(modelData.id)
                }

                // bar
                Rectangle {
                    x: root.labelW + (modelData.enabled ? (modelData.start / root.lanes.total) * root.timelineW : 0)
                    width: modelData.enabled ? Math.max(4, (modelData.duration / root.lanes.total) * root.timelineW) : 0
                    height: root.laneH
                    radius: 6
                    visible: modelData.enabled
                    color: modelData.color
                    opacity: parent.selected ? 0.92 : 0.56
                    border.width: parent.selected ? 1.5 : 0
                    border.color: Qt.rgba(1, 1, 1, 0.7)
                    Behavior on opacity { NumberAnimation { duration: 140 } }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 7
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label + "  " + Math.round(modelData.duration) + "s"
                        color: "#2a1410"
                        font.family: theme.hanFamily
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        width: parent.width - 14
                        visible: parent.width > 64
                    }
                }

                MouseArea {
                    x: root.labelW
                    width: root.timelineW
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    onClicked: root.selectAct(modelData.id)
                    onDoubleClicked: root.playFrom(modelData.id)
                }

            }
        }

        // popup card dots
        Repeater {
            model: root.popupDots()
            Rectangle {
                width: 5
                height: 5
                radius: 2.5
                color: modelData.color
                opacity: 0.9
                x: root.labelW + (modelData.t / root.lanes.total) * root.timelineW
                y: 1 + 2 * (root.laneH + root.laneGap) + root.laneH + 2 + (modelData.i % 2) * 5
            }
        }

        // playhead global
        Rectangle {
            visible: root.playing
            x: root.labelW + (root.playingStart() / root.lanes.total) * root.timelineW
            width: 2
            height: lanesArea.height
            color: "#fff5ee"
            opacity: 0.9
        }
    }

    // audio waveform strip
    Item {
        id: audioTrack
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 10
        anchors.rightMargin: 12
        height: 26

        Text {
            x: 2
            anchors.verticalCenter: parent.verticalCenter
            text: "BGM"
            color: root.muted
            font.family: theme.hanFamily
            font.pixelSize: 9
            opacity: 0.7
        }

        Canvas {
            x: root.labelW
            width: root.timelineW
            anchors.verticalCenter: parent.verticalCenter
            height: 18
            onWidthChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                var seed = 19
                function rnd() {
                    seed = (seed * 1664525 + 1013904223) % 4294967296
                    return seed / 4294967296
                }
                ctx.fillStyle = Qt.rgba(1, 0.69, 0.54, 0.32)
                var bars = Math.floor(width / 4)
                for (var i = 0; i < bars; i++) {
                    var h = (0.18 + rnd() * 0.82) * height
                    ctx.fillRect(i * 4, height - h, 2, h)
                }
            }
        }
    }

    function playingStart() {
        for (var i = 0; i < lanes.lanes.length; i++) {
            if (lanes.lanes[i].id === playingAct)
                return lanes.lanes[i].start
        }
        return 0
    }

    function popupDots() {
        var out = []
        var popups = actsCfg.popups
        if (!popups || popups.enabled === false || popups.cards_enabled === false)
            return out
        var lane = null
        for (var i = 0; i < lanes.lanes.length; i++) {
            if (lanes.lanes[i].id === "popups")
                lane = lanes.lanes[i]
        }
        if (!lane)
            return out
        var n = (popups.cards || []).length
        if (popups.cards_limit > 0)
            n = Math.min(n, popups.cards_limit)
        var st = (popups.sequence && popups.sequence.stagger_ms) || 60
        var delay = (popups.sequence && popups.sequence.start_delay_ms) || 260
        var sw = popups.swarm || {}
        var swarmLead = 0
        if (sw.enabled !== false && sw.cards_delay_after !== false)
            swarmLead = ((sw.count !== undefined ? sw.count : 320)
                         * Math.max(4, Math.min(60, sw.stagger_ms !== undefined ? sw.stagger_ms : 14))
                         + (sw.fade_in_ms !== undefined ? sw.fade_in_ms : 120)) / 1000
        var cs = (popups.color_strategy && popups.color_strategy.single_color) || null
        for (var k = 0; k < n; k++) {
            out.push({
                t: lane.start + swarmLead + (delay + k * st) / 1000,
                i: k,
                color: colors[(k + 2) % colors.length]
            })
        }
        return out
    }
}
