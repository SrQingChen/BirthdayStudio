import QtQuick

// Act 4 — "收下祝福". Press physics: scale down in 100–160 ms,
// release springs back; feedback starts immediately (F-12).
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
    focus: true

    readonly property bool cartoon: (cfg && cfg.style) === "cartoon"
    readonly property color accent: theme.palette["primary"] || "#ffb08a"
    readonly property color ink: theme.palette["on-surface"] || "#fff5ee"
    readonly property color surface: theme.palette["surface"] || "#1b1220"
    readonly property int cardW: cfg && cfg.width ? cfg.width : 440
    readonly property int cardH: cfg && cfg.height ? cfg.height : 230
    readonly property real pressScale: cfg && cfg.press_scale !== undefined ? cfg.press_scale : 0.96
    readonly property string mainText: cfg && cfg.text ? cfg.text : "收下祝福"
    readonly property string subText: cfg && cfg.subtext ? cfg.subtext : ""

    function withAlpha(c, a) {
        var q = Qt.color(c)
        return Qt.rgba(q.r, q.g, q.b, a)
    }

    // focus dim
    Rectangle {
        anchors.fill: parent
        color: theme.dark ? "#000000" : "#2a1512"
        opacity: 0
        Behavior on opacity { NumberAnimation { duration: 320 } }
        Component.onCompleted: opacity = root.highContrast ? 0 : 0.22
    }

    Item {
        id: cardWrap
        anchors.centerIn: parent
        width: Math.min(root.cardW, root.width * 0.7)
        height: Math.min(root.cardH, root.height * 0.42)
        opacity: 0
        scale: 0.82

        Rectangle {
            id: shadow
            x: 10
            y: 16
            width: parent.width - 20
            height: parent.height - 10
            radius: 26
            color: "#000000"
            opacity: root.highContrast ? 0 : 0.30
            Behavior on opacity { NumberAnimation { duration: 140 } }
            Behavior on y { NumberAnimation { duration: 140 } }
        }

        Rectangle {
            id: card
            anchors.fill: parent
            radius: root.cartoon ? 26 : 24
            color: root.highContrast
                   ? (theme.dark ? "#1b1220" : "#ffffff")
                   : root.cartoon
                     ? Qt.tint(root.surface, root.withAlpha(root.accent, 0.34))
                     : root.withAlpha(root.surface, theme.dark ? 0.66 : 0.72)
            border.width: root.cartoon ? 2 : (root.highContrast ? 2 : 1.5)
            border.color: root.cartoon ? (root.highContrast ? root.ink : "#4a2c2a")
                                       : root.withAlpha("#ffffff", theme.dark ? 0.42 : 0.7)
            clip: true

            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: root.highContrast ? card.color
                           : root.cartoon ? Qt.tint(root.surface, root.withAlpha(root.accent, 0.30))
                           : root.withAlpha(root.accent, theme.dark ? 0.28 : 0.34)
                }
                GradientStop {
                    position: 0.6
                    color: root.highContrast ? card.color
                           : root.cartoon ? Qt.tint(root.surface, root.withAlpha(root.accent, 0.22))
                           : root.withAlpha(root.surface, theme.dark ? 0.74 : 0.80)
                }
                GradientStop {
                    position: 1.0
                    color: root.highContrast ? card.color
                           : root.cartoon ? Qt.tint(root.surface, root.withAlpha(root.accent, 0.16))
                           : root.withAlpha(root.surface, theme.dark ? 0.84 : 0.88)
                }
            }

            Image {
                anchors.fill: parent
                source: showBridge.textureUrl("grain.png")
                fillMode: Image.Tile
                opacity: root.highContrast || root.cartoon ? 0 : 0.3
            }

            // top highlight
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: "#ffffff"
                opacity: root.highContrast ? 0 : 0.35
            }

            // cartoon bottom edge
            Rectangle {
                visible: root.cartoon && !root.highContrast
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 8
                color: Qt.darker(root.accent, 1.35)
            }

            Column {
                anchors.centerIn: parent
                spacing: 14
                width: parent.width - 64

                Text {
                    width: parent.width
                    text: root.mainText
                    color: root.ink
                    horizontalAlignment: Text.AlignHCenter
                    font.family: theme.serifFamily
                    font.pixelSize: Math.max(28, Math.min(40, root.cardH * 0.155))
                    font.weight: Font.DemiBold
                    wrapMode: Text.Wrap
                }

                Text {
                    width: parent.width
                    text: root.subText
                    visible: text !== ""
                    color: root.ink
                    opacity: 0.72
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    font.family: theme.hanFamily
                    font.pixelSize: 15
                    lineHeight: 1.4
                }

                Item { width: 1; height: 2 }

                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(180, parent.width)
                    height: 40

                    Rectangle {
                        id: defaultConfirmPill
                        anchors.fill: parent
                        visible: confirmSlot.status !== Loader.Ready
                        radius: 20
                        color: root.cartoon ? root.accent : root.withAlpha(root.accent, 0.22)
                        border.width: root.cartoon ? 0 : 1
                        border.color: root.withAlpha(root.accent, 0.55)
                        Text {
                            anchors.centerIn: parent
                            text: "轻触收下  ·  空格"
                            color: root.cartoon ? (theme.dark ? "#2a1512" : "#3a1a10") : root.ink
                            font.family: theme.hanFamily
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            opacity: 0.9
                        }
                    }

                    Loader {
                        id: confirmSlot
                        anchors.fill: parent
                        source: {
                            var rev = showBridge.pluginRevision
                            return showBridge.slotComponent("ConfirmButton")
                        }
                        visible: status === Loader.Ready
                        onLoaded: {
                            try {
                                item.text = "轻触收下  ·  空格"
                                item.tokens = theme.tokens
                                item.displayStyle = root.cartoon ? "cartoon" : "glass"
                                item.pressScale = root.pressScale
                                item.pressed = Qt.binding(function () { return press.pressed })
                            } catch (e) {
                                source = ""
                            }
                        }
                    }
                }
            }
        }

        MouseArea {
            id: press
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onPressed: {
                if (root.done)
                    return
                pressDown.start()
            }
            onReleased: {
                if (root.done)
                    return
                root.confirm()
            }
        }

        SequentialAnimation {
            id: pressDown
            NumberAnimation { target: cardWrap; property: "scale"; to: root.pressScale; duration: 120; easing.type: Easing.OutQuad }
            NumberAnimation { target: shadow; property: "opacity"; to: 0.14; duration: 120 }
            NumberAnimation { target: shadow; property: "y"; to: 12; duration: 120 }
        }

        ParallelAnimation {
            id: releaseSpring
            SpringAnimation { target: cardWrap; property: "scale"; to: 1.0; spring: 4.0; damping: 0.5; epsilon: 0.005 }
            NumberAnimation { target: shadow; property: "opacity"; to: 0.30; duration: 220 }
            NumberAnimation { target: shadow; property: "y"; to: 16; duration: 220 }
        }

        ParallelAnimation {
            id: appear
            NumberAnimation { target: cardWrap; property: "opacity"; from: 0; to: 1; duration: 240 }
            NumberAnimation {
                target: cardWrap; property: "scale"
                from: 0.82; to: 1
                duration: root.reducedMotion ? 200 : 420
                easing.type: Easing.OutBack
                easing.overshoot: 1.1
            }
        }
    }

    property bool done: false

    function confirm() {
        if (done)
            return
        done = true
        sfx("chime")
        releaseSpring.start()
        press.enabled = false
        finishTimer.start()
    }

    Timer {
        id: finishTimer
        interval: root.reducedMotion ? 140 : 340
        onTriggered: root.actFinished()
    }

    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            cardWrap.scale = root.pressScale
            root.confirm()
            event.accepted = true
        }
    }

    Component.onCompleted: {
        appear.start()
        forceActiveFocus()
    }
}
