import QtQuick
import QtQuick.Controls

// The letter. Supports static / typewriter / per-line reveal (F-28).
Item {
    id: root

    property var profile: ({})
    property var cfg: ({})
    property var tokens: ({})
    property bool reducedMotion: false
    property bool highContrast: false
    signal actFinished()

    property int charCount: 0
    property int lineCount: 0
    property bool allRevealed: false
    property bool started: false
    property bool caretOn: true

    readonly property var letterCfg: cfg || ({})
    readonly property string rawText: letterCfg.text || ""
    readonly property string bodyText: format(rawText)
    readonly property var lines: bodyText.split("\n")
    readonly property string presentation: letterCfg.presentation || "typewriter"
    readonly property int fontSize: letterCfg.font_size_px || 19
    readonly property real lineHeight: letterCfg.line_height || 1.75
    readonly property color paper: letterCfg.paper_color || "#f8f0e1"
    readonly property color ink: letterCfg.ink_color || "#3a2e28"
    readonly property color accent: letterCfg.accent_color || "#b0563a"
    readonly property string family: theme.fontFamily(letterCfg.font_family || "hanSerif")
    readonly property string honoree: profile && profile.meta ? profile.meta.honoree : ""
    readonly property string author: profile && profile.meta ? profile.meta.author : ""
    readonly property int advanceMs: (letterCfg.advance === "auto") ? 2600 : 0
    readonly property real estimatedHeight: {
        var cw = Math.min(1040, parent.width * 0.72, parent.height * 0.98)
        var margins = Math.max(44, cw * 0.075) * 2
        var textWidth = Math.max(120, cw - margins)
        var charsPerLine = Math.max(10, Math.floor(textWidth / (fontSize * 0.98)))
        var lineTotal = 0
        var segments = bodyText.split("
")
        for (var i = 0; i < segments.length; i++)
            lineTotal += Math.max(1, Math.ceil(segments[i].length / charsPerLine))
        var h = 40 + 1 + 26 + lineTotal * fontSize * lineHeight + 26 + 20 + 72
        return Math.min(parent.height * 0.84, Math.max(380, h))
    }

    function format(t) {
        return String(t || "")
            .replace(/\{honoree\}/g, honoree)
            .replace(/\{author\}/g, author)
            .replace(/\{name\}/g, profile && profile.meta ? profile.meta.name : "")
    }

    function reset() {
        charCount = 0
        lineCount = 0
        allRevealed = false
        started = false
        caretOn = true
        appearAnim.restart()
    }

    function startPresentation() {
        if (started)
            return
        started = true
        appearAnim.start()
        if (presentation === "typewriter") {
            typeTimer.start()
        } else if (presentation === "lines") {
            lineTimer.start()
        } else {
            revealAll()
        }
    }

    function revealAll() {
        typeTimer.stop()
        lineTimer.stop()
        charCount = bodyText.length
        lineCount = lines.length
        allRevealed = true
        if (root.presentation === "lines")
            lineCount = lines.length
        caretTimer.stop()
        if (advanceMs > 0)
            autoTimer.restart()
    }

    function advance() {
        if (!started)
            return
        if (!allRevealed) {
            revealAll()
            return
        }
        completed()
    }

    anchors.fill: parent

    // click-to-advance layer (behind the card so Flickable wins on the card)
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: root.advance()
    }

    Item {
        id: cardWrap
        anchors.centerIn: parent
        width: Math.min(1040, parent.width * 0.72, parent.height * 0.98)
        height: root.estimatedHeight
        scale: 0.94
        opacity: 0

        TapHandler { onTapped: root.advance() }

        // soft shadow
        Image {
            x: -parent.width * 0.01
            y: 12
            width: parent.width * 1.02
            height: parent.height * 1.04
            source: showBridge.textureUrl("shadow.png")
            fillMode: Image.Stretch
            opacity: 0.85
        }

        Rectangle {
            id: paperCard
            anchors.fill: parent
            radius: 18
            color: paperSlot.status === Loader.Ready ? "transparent" : root.paper
            border.width: paperSlot.status === Loader.Ready ? 0 : (root.highContrast ? 2 : 1)
            border.color: root.highContrast ? root.accent : Qt.rgba(0, 0, 0, 0.14)
            clip: true

            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: paperSlot.status === Loader.Ready ? "transparent" : Qt.lighter(root.paper, 1.02)
                }
                GradientStop {
                    position: 1.0
                    color: paperSlot.status === Loader.Ready ? "transparent" : Qt.darker(root.paper, 1.03)
                }
            }

            Loader {
                id: paperSlot
                anchors.fill: parent
                z: -1
                source: {
                    var rev = showBridge.pluginRevision
                    return showBridge.slotComponent("LetterPaper")
                }
                visible: status === Loader.Ready
                onLoaded: {
                    try {
                        item.paperColor = root.paper
                        item.inkColor = root.ink
                        item.accentColor = root.accent
                    } catch (e) {
                        source = ""
                    }
                }
            }

            Image {
                anchors.fill: parent
                visible: paperSlot.status !== Loader.Ready
                source: showBridge.textureUrl("grain.png")
                fillMode: Image.Tile
                opacity: root.highContrast ? 0 : 0.5
            }

            // faint deckled edge lines
            Canvas {
                anchors.fill: parent
                visible: paperSlot.status !== Loader.Ready
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    var seed = 9
                    function rnd() {
                        seed = (seed * 1664525 + 1013904223) % 4294967296
                        return seed / 4294967296
                    }
                    ctx.strokeStyle = Qt.rgba(0.35, 0.25, 0.18, 0.055)
                    ctx.lineWidth = 0.8
                    for (var i = 0; i < 26; i++) {
                        var y = rnd() * height
                        ctx.beginPath()
                        ctx.moveTo(0, y)
                        ctx.bezierCurveTo(width * 0.3, y + (rnd() - 0.5) * 8, width * 0.7, y + (rnd() - 0.5) * 8, width, y + (rnd() - 0.5) * 4)
                        ctx.stroke()
                    }
                }
            }

            Column {
                anchors.fill: parent
                anchors.leftMargin: Math.max(44, paperCard.width * 0.075)
                anchors.rightMargin: Math.max(44, paperCard.width * 0.075)
                anchors.topMargin: 40
                anchors.bottomMargin: 32
                spacing: 0

                Item {
                    width: parent.width
                    height: 40
                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.honoree ? "TO · " + root.honoree : "TO YOU"
                        color: root.accent
                        font.family: theme.hanFamily
                        font.pixelSize: 12
                        font.letterSpacing: 2
                        font.weight: Font.DemiBold
                    }
                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 64
                        height: 1
                        color: root.accent
                        opacity: 0.45
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: root.accent
                    opacity: 0.32
                }

                Item { width: 1; height: 26 }

                Flickable {
                    id: scroller
                    width: parent.width
                    height: Math.max(120, parent.height - 113)
                    clip: true
                    contentWidth: width
                    contentHeight: root.presentation === "lines" ? lineColumn.height : bodyTextItem.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AlwaysOff }

                    Text {
                        id: bodyTextItem
                        width: scroller.width
                        text: root.presentation === "lines"
                              ? ""
                              : (root.presentation === "typewriter"
                                 ? root.bodyText.substring(0, root.charCount) + (root.allRevealed ? "" : (root.caretOn ? "▍" : " "))
                                 : root.bodyText)
                        visible: root.presentation !== "lines"
                        color: root.ink
                        font.family: root.family
                        font.pixelSize: root.fontSize
                        lineHeight: root.fontSize * root.lineHeight
                        lineHeightMode: Text.FixedHeight
                        wrapMode: Text.Wrap
                        textFormat: Text.PlainText
                    }

                    Column {
                        id: lineColumn
                        visible: root.presentation === "lines"
                        width: scroller.width
                        spacing: 0
                        Repeater {
                            model: root.lines.length
                            Text {
                                width: lineColumn.width
                                text: root.lines[index] || " "
                                color: root.ink
                                font.family: root.family
                                font.pixelSize: root.fontSize
                                lineHeight: root.fontSize * root.lineHeight
                                lineHeightMode: Text.FixedHeight
                                wrapMode: Text.Wrap
                                opacity: index < root.lineCount ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: root.reducedMotion ? 120 : 420 } }
                            }
                        }
                    }
                }

                Item { width: 1; height: 26 }

                Item {
                    width: parent.width
                    height: 20
                    Text {
                        anchors.centerIn: parent
                        text: root.allRevealed ? "轻触继续" : "轻触展开全文"
                        color: root.accent
                        font.family: theme.hanFamily
                        font.pixelSize: 13
                        opacity: root.allRevealed ? parent.pulse : 0.55
                    }
                    property real pulse: 0.45
                    SequentialAnimation on pulse {
                        id: hintPulse
                        running: root.allRevealed && !root.reducedMotion
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.45; to: 0.95; duration: 1400; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 0.95; to: 0.45; duration: 1400; easing.type: Easing.InOutSine }
                    }
                }
            }
        }

    }

    ParallelAnimation {
        id: appearAnim
        NumberAnimation { target: cardWrap; property: "opacity"; from: 0; to: 1; duration: 380 }
        NumberAnimation { target: cardWrap; property: "scale"; from: 0.94; to: 1; duration: root.reducedMotion ? 200 : 520; easing.type: Easing.OutCubic }
    }

    Timer {
        id: typeTimer
        interval: Math.max(16, 1000 / Math.max(6, root.letterCfg.chars_per_second || 24))
        repeat: true
        onTriggered: {
            root.charCount = Math.min(root.bodyText.length, root.charCount + 1)
            if (root.charCount >= root.bodyText.length) {
                root.revealAll()
            }
        }
    }

    Timer {
        id: lineTimer
        interval: Math.max(60, root.letterCfg.line_stagger_ms || 420)
        repeat: true
        onTriggered: {
            root.lineCount = Math.min(root.lines.length, root.lineCount + 1)
            if (root.lineCount >= root.lines.length)
                root.revealAll()
        }
    }

    Timer {
        id: caretTimer
        interval: 520
        running: root.presentation === "typewriter" && !root.allRevealed && root.started
        repeat: true
        onTriggered: root.caretOn = !root.caretOn
    }

    Timer {
        id: autoTimer
        interval: root.advanceMs
        onTriggered: root.actFinished()
    }

}
