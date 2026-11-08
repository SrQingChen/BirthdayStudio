import QtQuick

// Default PopupCard slot implementation (glass / cartoon variants).
// Contract v1 — see docs/plugin-sdk.md.
Item {
    id: root

    property var card: ({})
    property var tokens: ({})
    property real cardWidth: 320
    property real cardHeight: 196
    property color accentColor: "#ffb08a"
    property string displayStyle: "glass"
    property bool highContrast: false
    property bool reducedMotion: false

    implicitWidth: cardWidth
    implicitHeight: cardHeight

    // Named `paletteColors`: a `palette` property shadows QQuickItem's
    // attached palette and makes the engine log an override warning.
    readonly property var paletteColors: (tokens && tokens.color && tokens.color.palette) ? tokens.color.palette : ({})
    readonly property bool dark: !tokens || !tokens.ui || tokens.ui.mode !== "light"
    readonly property color ink: highContrast ? (dark ? "#ffffff" : "#000000") : (paletteColors["on-surface"] || "#fff5ee")
    readonly property color surface: paletteColors["surface"] || "#1b1220"
    readonly property bool cartoon: displayStyle === "cartoon"
    readonly property bool hasImage: card.image !== undefined && card.image !== ""
    readonly property int radius: cartoon ? 20 : ((tokens && tokens.shape && tokens.shape.l) || 16)

    function withAlpha(c, a) {
        var q = Qt.color(c)
        return Qt.rgba(q.r, q.g, q.b, a)
    }

    // Soft depth backing (V1.1.0 fix #2): both layers are fully contained in
    // the card bounds — the v1.0.0 offset rects leaked a 2-4px strip below
    // every card that read as a stray line outside the note.
    Rectangle {
        x: cartoon ? 8 : 5
        y: cartoon ? 12 : 14
        width: parent.width - (cartoon ? 16 : 10)
        height: parent.height - (cartoon ? 12 : 14)
        radius: root.radius + 4
        color: "#000000"
        opacity: cartoon ? (root.highContrast ? 0 : 0.26) : (root.highContrast ? 0 : 0.22)
    }
    Rectangle {
        x: cartoon ? 4 : 2
        y: cartoon ? 6 : 7
        width: parent.width - (cartoon ? 8 : 4)
        height: parent.height - (cartoon ? 6 : 7)
        radius: root.radius + 2
        color: "#000000"
        opacity: cartoon ? 0 : (root.highContrast ? 0 : 0.14)
    }

    Rectangle {
        id: shell
        anchors.fill: parent
        radius: root.radius
        clip: true
        color: {
            if (root.highContrast)
                return root.dark ? "#1b1220" : "#ffffff"
            if (root.cartoon)
                return Qt.tint(root.surface, root.withAlpha(root.accentColor, 0.42))
            // A slightly more opaque, accent-warmed pane: on the dark stage
            // the old 0.78 alpha read as a black hole rather than glass.
            return Qt.tint(root.withAlpha(root.surface, 0.92),
                           root.withAlpha(root.accentColor, 0.10))
        }
        border.width: root.cartoon ? 2 : (root.highContrast ? 2 : 1.4)
        border.color: root.cartoon
                      ? (root.highContrast ? root.ink : "#4a2c2a")
                      : (root.highContrast ? root.ink
                                           : root.withAlpha(root.accentColor, root.dark ? 0.55 : 0.62))

        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: root.highContrast ? (root.dark ? "#1b1220" : "#ffffff")
                       : root.cartoon ? Qt.tint(root.surface, root.withAlpha(root.accentColor, 0.30))
                       : root.withAlpha(root.accentColor, root.dark ? 0.38 : 0.42)
            }
            GradientStop {
                position: 0.55
                color: root.highContrast ? (root.dark ? "#1b1220" : "#ffffff")
                       : root.cartoon ? Qt.tint(root.surface, root.withAlpha(root.accentColor, 0.22))
                       : "transparent"
            }
            GradientStop {
                position: 1.0
                color: root.highContrast ? (root.dark ? "#140c1a" : "#ffffff")
                       : root.cartoon ? Qt.tint(root.surface, root.withAlpha(root.accentColor, 0.16))
                       : Qt.rgba(0, 0, 0, 0.16)
            }
        }

        // frosted inner blooms
        Canvas {
            anchors.fill: parent
            visible: !root.highContrast
            opacity: root.cartoon ? 0.5 : 0.9
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                var g1 = ctx.createRadialGradient(width * 0.22, height * 0.16, 0, width * 0.22, height * 0.16, width * 0.6)
                var c = Qt.color(root.accentColor)
                g1.addColorStop(0, Qt.rgba(1, 1, 1, root.cartoon ? 0.16 : 0.20))
                g1.addColorStop(0.5, Qt.rgba(c.r, c.g, c.b, 0.10))
                g1.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0))
                ctx.fillStyle = g1
                ctx.fillRect(0, 0, width, height)
                var g2 = ctx.createRadialGradient(width * 0.82, height * 0.86, 0, width * 0.82, height * 0.86, width * 0.5)
                g2.addColorStop(0, Qt.rgba(c.r, c.g, c.b, 0.16))
                g2.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0))
                ctx.fillStyle = g2
                ctx.fillRect(0, 0, width, height)
            }
        }

        Image {
            anchors.fill: parent
            source: showBridge.textureUrl("grain.png")
            fillMode: Image.Tile
            opacity: root.highContrast || root.cartoon ? 0 : 0.32
        }

        // ---- liquid-glass layers (V1.1.1) --------------------------- //
        // specular sheen across the top third: the "琉璃" highlight
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: parent.height * 0.38
            radius: root.radius
            visible: !root.highContrast
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, root.cartoon ? 0.22 : 0.26) }
                GradientStop { position: 0.55; color: Qt.rgba(1, 1, 1, 0.06) }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
            }
        }
        // diagonal light streak (clipped by the shell)
        Rectangle {
            x: parent.width * 0.06
            y: -parent.height * 0.25
            width: parent.width * 0.30
            height: parent.height * 1.5
            rotation: 18
            visible: !root.highContrast
            opacity: root.dark ? 0.10 : 0.16
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.5; color: "#ffffff" }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
        // inner rim light: a bright hairline just inside the border
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: root.radius - 1
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, root.highContrast ? 0 : (root.cartoon ? 0.30 : 0.24))
        }

        // top highlight
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: root.highContrast ? "transparent" : "#ffffff"
            opacity: root.dark ? 0.32 : 0.7
        }

        // cartoon bottom edge
        Rectangle {
            visible: root.cartoon && !root.highContrast
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 2.5
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 2.5
            anchors.rightMargin: 2.5
            height: 6
            radius: 3
            color: Qt.darker(root.accentColor, 1.35)
            opacity: 0.9
        }

        // contained inner bottom shade (glass): compensates the removed
        // overhanging shadow with a clipped-in depth cue
        Rectangle {
            visible: !root.cartoon && !root.highContrast
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 3
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.16) }
            }
        }

        // tape (cartoon) — fully inside the card (V1.1.0 fix #2)
        Rectangle {
            visible: root.cartoon && !root.highContrast
            x: parent.width * 0.5 - 34
            y: 3
            width: 68
            height: 16
            rotation: -4
            color: root.withAlpha("#fff4d6", 0.8)
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.08)
        }

        // emoji badge
        Rectangle {
            id: emojiBadge
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: 16
            anchors.topMargin: 14
            width: 42
            height: 42
            radius: root.cartoon ? 14 : 21
            color: root.highContrast ? "transparent" : root.withAlpha(root.accentColor, root.cartoon ? 0.55 : 0.30)
            border.width: root.cartoon && !root.highContrast ? 1.5 : 0
            border.color: Qt.darker(root.accentColor, 1.2)
            Text {
                anchors.centerIn: parent
                text: root.card.emoji || "✨"
                font.pixelSize: 22
            }
        }

        Text {
            id: title
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: 22
            anchors.right: emojiBadge.left
            anchors.rightMargin: 12
            anchors.topMargin: 20
            text: root.card.title || ""
            color: root.ink
            font.family: theme.hanFamily
            font.pixelSize: Math.max(17, Math.min(23, root.cardHeight * 0.105))
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
        }

        Rectangle {
            anchors.left: parent.left
            anchors.top: title.bottom
            anchors.leftMargin: 22
            anchors.topMargin: 9
            width: 46
            height: 3
            radius: 2
            color: root.accentColor
        }

        Text {
            id: body
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: title.bottom
            anchors.bottom: parent.bottom
            anchors.leftMargin: 22
            anchors.rightMargin: root.hasImage ? 88 : 22
            anchors.topMargin: 24
            anchors.bottomMargin: root.cartoon ? 24 : 18
            text: root.card.body || ""
            color: root.ink
            opacity: 0.92
            wrapMode: Text.WordWrap
            lineHeight: 1.5
            elide: Text.ElideRight
            maximumLineCount: Math.max(2, Math.floor((root.cardHeight - 96) / (Math.max(14, Math.min(18, root.cardHeight * 0.083)) * 1.5)))
            font.family: theme.hanFamily
            font.pixelSize: Math.max(14, Math.min(18, root.cardHeight * 0.085))
            verticalAlignment: Text.AlignTop
        }

        Image {
            visible: root.hasImage
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 16
            anchors.bottomMargin: root.cartoon ? 20 : 16
            width: 58
            height: 58
            source: root.hasImage ? showBridge.assetUrl(root.card.image) : ""
            fillMode: Image.PreserveAspectCrop
            layer.enabled: true
            Rectangle {
                anchors.fill: parent
                anchors.margins: -1
                radius: 10
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.28)
            }
        }

        // accent signature at the foot of the pane
        Rectangle {
            visible: !root.highContrast
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 9
            width: 26
            height: 2
            radius: 1
            color: root.withAlpha(root.accentColor, root.dark ? 0.55 : 0.65)
        }
    }

    // cartoon cards get a sticker-like outline; glass keeps its single accent
    // border so the pane does not read as a double frame
    Rectangle {
        anchors.fill: parent
        anchors.margins: -4
        radius: root.radius + 4
        color: "transparent"
        border.width: 1.5
        border.color: root.withAlpha(root.accentColor, root.dark ? 0.28 : 0.34)
        visible: !root.highContrast && root.cartoon
    }
}
