// Stable slot: PopupCard  (contract v1)
// Inputs (all optional at runtime, defaults provided):
//   property var    card          { title, body, emoji, width, height, accent }
//   property var    tokens        resolved design tokens (object)
//   property real   cardWidth
//   property real   cardHeight
//   property color  accentColor
//   property string displayStyle  "glass" | "cartoon"
// A plugin component MUST NOT read files or network and MUST NOT contain
// Python. Health-red-line lint is applied to the host config, not here.
import QtQuick
import QtQuick.Effects

Item {
    id: root

    property var card: ({})
    property var tokens: ({})
    property real cardWidth: 320
    property real cardHeight: 196
    property color accentColor: "#9fd8cb"
    property string displayStyle: "glass"
    property bool highContrast: false
    property bool reducedMotion: false

    implicitWidth: cardWidth
    implicitHeight: cardHeight

    readonly property var palette: (tokens && tokens.color && tokens.color.palette) || {}
    readonly property bool dark: !tokens || !tokens.ui || tokens.ui.mode !== "light"
    readonly property color ink: palette["on-surface"] || "#fff5ee"
    readonly property color panel: palette["surface"] || "#1b1220"
    readonly property var hanStack: (tokens && tokens.type && tokens.type.stack && tokens.type.stack.han) || ["Microsoft YaHei UI"]
    readonly property var serifStack: (tokens && tokens.type && tokens.type.stack && tokens.type.stack.hanSerif) || hanStack
    readonly property int radius: (tokens && tokens.shape && tokens.shape.l) || 18

    function withAlpha(c, a) {
        var q = Qt.color(c)
        return Qt.rgba(q.r, q.g, q.b, a)
    }

    // soft layered shadow
    Rectangle {
        x: 6; y: 14; width: parent.width - 12; height: parent.height - 12
        radius: root.radius + 6
        color: "#000000"
        opacity: root.dark ? 0.22 : 0.12
    }
    Rectangle {
        x: 3; y: 8; width: parent.width - 6; height: parent.height - 6
        radius: root.radius + 3
        color: "#000000"
        opacity: root.dark ? 0.16 : 0.08
    }

    Rectangle {
        id: surface
        anchors.fill: parent
        radius: root.radius
        color: root.withAlpha(root.dark ? "#261b33" : "#fffdf7", root.dark ? 0.92 : 0.97)
        border.width: displayStyle === "cartoon" ? 2 : 1.4
        border.color: root.withAlpha(root.accentColor, displayStyle === "cartoon" ? 0.85 : 0.5)
        clip: true

        // aurora sheet
        Rectangle {
            id: aurora
            width: parent.width * 1.6
            height: parent.height * 1.2
            x: -parent.width * 0.3
            y: -parent.height * 0.55
            rotation: -12
            opacity: 0.34
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.25; color: root.withAlpha(root.accentColor, 0.85) }
                GradientStop { position: 0.55; color: root.withAlpha("#a78bfa", 0.55) }
                GradientStop { position: 0.85; color: root.withAlpha("#7ee0d0", 0.5) }
                GradientStop { position: 1.0; color: "transparent" }
            }
            SequentialAnimation on x {
                loops: Animation.Infinite
                NumberAnimation { to: -parent.parent.width * 0.45; duration: 5200; easing.type: Easing.InOutSine }
                NumberAnimation { to: -parent.parent.width * 0.3; duration: 5200; easing.type: Easing.InOutSine }
            }
        }

        // top inner highlight
        Rectangle {
            anchors.top: parent.top
            width: parent.width
            height: 1
            color: "#ffffff"
            opacity: root.dark ? 0.28 : 0.6
        }

        Text {
            id: emojiText
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: 18
            anchors.topMargin: 14
            text: root.card.emoji || "✨"
            font.pixelSize: 30
            opacity: 0.95
        }

        Text {
            id: title
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: 22
            anchors.rightMargin: 66
            anchors.topMargin: 20
            text: root.card.title || ""
            color: root.ink
            font.family: root.serifStack[0]
            font.pixelSize: Math.max(17, Math.min(23, root.cardHeight * 0.105))
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            width: parent.width - 88
        }

        Rectangle {
            anchors.left: parent.left
            anchors.top: title.bottom
            anchors.leftMargin: 22
            anchors.topMargin: 8
            width: 44
            height: 3
            radius: 2
            color: root.accentColor
        }

        Text {
            id: body
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: title.bottom
            anchors.leftMargin: 22
            anchors.rightMargin: 22
            anchors.bottom: parent.bottom
            anchors.topMargin: 22
            anchors.bottomMargin: 18
            text: root.card.body || ""
            color: root.ink
            opacity: 0.9
            wrapMode: Text.WordWrap
            lineHeight: 1.5
            font.family: root.hanStack[0]
            font.pixelSize: Math.max(14, Math.min(18, root.cardHeight * 0.083))
            verticalAlignment: Text.AlignTop
        }
    }
}
