import QtQuick

// The closed envelope with a wax seal. Used by act 1 (open the envelope)
// and act 2 (break the seal). The seal has a 96px hit target even though the
// visual is ~72px, per Fitts' law (V1.0 F-03).
Item {
    id: root

    property var cfg: ({})
    property bool interactive: true
    property bool busy: false
    property bool cracking: false
    property bool showHint: true
    property string hint: "轻触信封，开启祝福"
    property color hintColor: "#ffe9df"
    property int hintSize: 20
    signal sealClicked()
    signal opened()
    signal sfx(string kind)

    implicitWidth: 520
    implicitHeight: 340

    readonly property var env: cfg && cfg.envelope ? cfg.envelope : ({})
    readonly property color paperColor: env.paper_color || "#f4e8d8"
    readonly property color flapColor: env.flap_color || "#eadcc8"
    readonly property color sealColor: env.seal_color || "#b3393f"
    readonly property color sealHi: env.seal_highlight || "#d9575c"
    readonly property color ribbonColor: env.ribbon_color || "#e9c46a"
    readonly property color threadColor: env.thread_color || "#7a2a2f"
    readonly property real pressScale: cfg && cfg.press_scale !== undefined ? cfg.press_scale : 0.94
    readonly property bool cartoon: theme.style === "cartoon"

    function reset() {
        busy = false
        cracking = false
        sealItem.opacity = 1
        sealItem.scale = 1
        sealItem.rotation = 0
        flapScale.yScale = 1
        body.opacity = 1
    }

    function activate() {
        if (!interactive || busy)
            return
        busy = true
        pressAnim.start()
    }

    function doCrack() {
        cracking = true
        sfx("wax")
        sealItem.opacity = 0
        flapScale.yScale = 1
        flapFold.opacity = 1
        flapAnim.start()
        sealClicked()
        openTimer.start()
    }

    Item {
        id: stack
        anchors.centerIn: parent
        width: Math.min(720, root.width * 0.92, root.height * 1.5)
        height: width * 0.64

        // soft contact shadow
        Image {
            visible: !root.cartoon
            x: parent.width * 0.04
            y: parent.height - parent.height * 0.075
            width: parent.width * 0.92
            height: parent.height * 0.32
            source: showBridge.textureUrl("shadow.png")
            fillMode: Image.Stretch
            opacity: 0.9
        }

        // toy-style hard shadow
        Rectangle {
            visible: root.cartoon
            x: 10
            y: 12
            width: parent.width
            height: parent.height
            radius: width * 0.035
            color: "#4a2c2a"
            opacity: 0.24
        }

        Rectangle {
            id: body
            anchors.fill: parent
            radius: width * 0.035
            color: root.paperColor
            border.width: root.cartoon ? 3 : 1
            border.color: root.cartoon ? "#4a2c2a" : Qt.rgba(0, 0, 0, 0.12)
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.lighter(root.paperColor, 1.04) }
                GradientStop { position: 1.0; color: Qt.darker(root.paperColor, 1.04) }
            }
            clip: true

            // paper grain
            Image {
                anchors.fill: parent
                source: showBridge.textureUrl("grain.png")
                fillMode: Image.Tile
                opacity: 0.4
            }

            // ribbon under the seal
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: -2
                width: parent.width * 0.07
                height: parent.height + 4
                color: root.ribbonColor
                opacity: 0.92
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: -2
                width: parent.width * 0.072
                height: parent.height + 4
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.12)
            }

            // bottom folds
            Canvas {
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    ctx.strokeStyle = root.cartoon ? Qt.rgba(0.29, 0.17, 0.16, 0.35) : Qt.rgba(0, 0, 0, 0.10)
                    ctx.lineWidth = root.cartoon ? 2 : 1
                    ctx.beginPath()
                    ctx.moveTo(0, height)
                    ctx.lineTo(width * 0.5, height * 0.52)
                    ctx.lineTo(width, height)
                    ctx.stroke()
                    ctx.strokeStyle = Qt.rgba(255, 255, 255, 0.35)
                    ctx.beginPath()
                    ctx.moveTo(0, height - 2)
                    ctx.lineTo(width * 0.5, height * 0.52 - 2)
                    ctx.lineTo(width, height - 2)
                    ctx.stroke()
                }
            }

            // flap (closed: a triangle pointing down)
            Item {
                id: flapFold
                width: parent.width
                height: parent.height * 0.62
                transformOrigin: Item.Top
                transform: Scale { id: flapScale; origin.y: 0; yScale: 1 }
                Canvas {
                    anchors.fill: parent
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        var g = ctx.createLinearGradient(0, 0, 0, height)
                        g.addColorStop(0, Qt.lighter(root.flapColor, 1.04))
                        g.addColorStop(1, Qt.darker(root.flapColor, 1.08))
                        ctx.fillStyle = g
                        ctx.beginPath()
                        ctx.moveTo(0, 0)
                        ctx.lineTo(width * 0.5, height)
                        ctx.lineTo(width, 0)
                        ctx.closePath()
                        ctx.fill()
                        ctx.strokeStyle = root.cartoon ? "#4a2c2a" : Qt.rgba(0, 0, 0, 0.13)
                        ctx.lineWidth = root.cartoon ? 2.5 : 1
                        ctx.stroke()
                        // embossed inner line
                        ctx.strokeStyle = Qt.rgba(255, 255, 255, 0.26)
                        ctx.beginPath()
                        ctx.moveTo(3, 2)
                        ctx.lineTo(width * 0.5, height - 5)
                        ctx.lineTo(width - 3, 2)
                        ctx.stroke()
                    }
                }
            }

            // opening flap (drawn after crack; folds up)
            Canvas {
                id: flapInner
                anchors.fill: parent
                readonly property real t: flapAnim.running ? flapFold.scaleY : 1
                visible: false
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                }
            }
        }

        // seal assembly
        Item {
            id: sealItem
            x: parent.width * 0.5 - width / 2
            y: parent.height * 0.55 - height / 2
            width: 128
            height: 128

            Loader {
                id: sealSlot
                anchors.fill: parent
                source: {
                    var rev = showBridge.pluginRevision
                    return showBridge.slotComponent("WaxSeal")
                }
                visible: status === Loader.Ready
                onLoaded: {
                    try {
                        item.sealColor = root.sealColor
                        item.sealHighlight = root.sealHi
                        item.pressScale = root.pressScale
                        item.activated.connect(root.activate)
                    } catch (e) {
                        source = ""
                    }
                }
            }

            Canvas {
                id: wax
                visible: sealSlot.status !== Loader.Ready
                anchors.centerIn: parent
                width: 112
                height: 112
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    var cx = width / 2, cy = height / 2
                    ctx.beginPath()
                    var pts = 72
                    for (var i = 0; i <= pts; i++) {
                        var a = i / pts * Math.PI * 2
                        var wobble = Math.sin(a * 5 + 1.2) * 1.4 + Math.sin(a * 9 + 0.4) * 0.7
                        var r = width * 0.434 + wobble
                        var x = cx + Math.cos(a) * r
                        var y = cy + Math.sin(a) * r * 0.97
                        if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                    }
                    ctx.closePath()
                    var g = ctx.createRadialGradient(cx - 14, cy - 16, 4, cx, cy, width * 0.52)
                    g.addColorStop(0, Qt.lighter(root.sealHi, 1.12))
                    g.addColorStop(0.45, root.sealColor)
                    g.addColorStop(1, Qt.darker(root.sealColor, 1.45))
                    ctx.fillStyle = g
                    ctx.fill()
                    ctx.strokeStyle = Qt.rgba(0, 0, 0, 0.28)
                    ctx.lineWidth = 1.2
                    ctx.stroke()
                    // inner rim
                    ctx.beginPath()
                    ctx.arc(cx, cy, width * 0.34, 0, Math.PI * 2)
                    ctx.strokeStyle = Qt.rgba(255, 255, 255, 0.22)
                    ctx.lineWidth = 2
                    ctx.stroke()
                    // tiny wax speckles
                    for (var s = 0; s < 14; s++) {
                        var ang = s / 14 * Math.PI * 2 + 0.3
                        var rad = width * (0.38 + (s % 3) * 0.02)
                        ctx.beginPath()
                        ctx.arc(cx + Math.cos(ang) * rad, cy + Math.sin(ang) * rad, 0.9, 0, Math.PI * 2)
                        ctx.fillStyle = Qt.rgba(255, 255, 255, 0.18)
                        ctx.fill()
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: sealSlot.status !== Loader.Ready
                text: "寿"
                color: root.sealHi
                opacity: 0.92
                font.family: theme.serifFamily
                font.pixelSize: 38
                font.weight: Font.DemiBold
            }

            // Fitts' law: 96px hit target, larger than the 72px visual
            MouseArea {
                anchors.fill: parent
                enabled: sealSlot.status !== Loader.Ready
                cursorShape: root.interactive && !root.busy ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.activate()
            }
        }

        // shards
        Item {
            id: shardLayer
            anchors.centerIn: parent
            width: 1
            height: 1
            visible: root.cracking
            Repeater {
                model: 14
                Rectangle {
                    id: shard
                    width: 7 + (index % 3) * 3
                    height: width
                    radius: 2
                    color: index % 2 ? root.sealColor : root.sealHi
                    opacity: 0
                    property real ang: index / 14 * Math.PI * 2 + (index % 4) * 0.09
                    x: -width / 2
                    y: -height / 2
                    SequentialAnimation {
                        running: root.cracking
                        PauseAnimation { duration: index * 9 }
                        ScriptAction { script: { shard.opacity = 1 } }
                        ParallelAnimation {
                            NumberAnimation {
                                target: shard; property: "x"
                                to: Math.cos(shard.ang) * (86 + (index % 4) * 16)
                                duration: 460 + (index % 3) * 90
                                easing.type: Easing.OutCubic
                            }
                            NumberAnimation {
                                target: shard; property: "y"
                                to: Math.sin(shard.ang) * (76 + (index % 5) * 13) + 30
                                duration: 520 + (index % 4) * 80
                                easing.type: Easing.OutCubic
                            }
                            NumberAnimation { target: shard; property: "rotation"; to: 160 + index * 24; duration: 600 }
                            NumberAnimation { target: shard; property: "opacity"; to: 0; duration: 650; easing.type: Easing.InQuad }
                        }
                    }
                }
            }
        }
    }

    Item {
        id: hintWrap
        anchors.top: stack.bottom
        anchors.topMargin: root.cartoon ? 18 : 26
        anchors.horizontalCenter: parent.horizontalCenter
        width: hintLabel.implicitWidth + (root.cartoon ? 44 : 0)
        height: root.cartoon ? 42 : hintLabel.implicitHeight
        opacity: root.showHint ? 0.92 : 0
        visible: root.showHint
        Behavior on opacity { NumberAnimation { duration: 220 } }

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: "#fffdf7"
            border.width: 2
            border.color: "#4a2c2a"
            visible: root.cartoon
        }
        Text {
            id: hintLabel
            anchors.centerIn: parent
            text: root.hint
            color: root.hintColor
            font.family: theme.hanFamily
            font.pixelSize: root.hintSize
        }
    }

    SequentialAnimation {
        id: pressAnim
        NumberAnimation { target: sealItem; property: "scale"; to: root.pressScale; duration: 130; easing.type: Easing.OutQuad }
        NumberAnimation { target: sealItem; property: "scale"; to: 1.05; duration: 110; easing.type: Easing.OutCubic }
        ScriptAction { script: root.doCrack() }
    }

    NumberAnimation {
        id: flapAnim
        target: flapScale
        property: "yScale"
        from: 1
        to: 0.08
        duration: 420
        easing.type: Easing.InOutCubic
    }

    Timer {
        id: openTimer
        interval: 560
        onTriggered: {
            root.opened()
            foldDown.start()
        }
    }

    NumberAnimation {
        id: foldDown
        target: stack
        property: "opacity"
        from: 1
        to: 0
        duration: 320
        easing.type: Easing.OutQuad
    }
}
