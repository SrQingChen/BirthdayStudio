import QtQuick

// Act 1 — the sealed envelope on the table.
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

    readonly property string hint: cfg && cfg.hint ? cfg.hint : "轻触信封，开启祝福"
    readonly property int hintSize: cfg && cfg.hint_size ? cfg.hint_size : 20

    // V1.1.0 fix #6 — opening gate: dim screen + one button; the envelope
    // stays hidden until the tap.
    readonly property bool gateEnabled: !(cfg && cfg.gate === false)
    readonly property string gateText: (cfg && cfg.gate_text) || "开启这份祝福"
    readonly property string gateSubtext: (cfg && cfg.gate_subtext) || "一份心意，正在等你点开"
    property bool gateOpened: !gateEnabled

    function openGate() {
        if (gateOpened)
            return
        gateOpened = true
        sfx("chime")
    }

    onGateOpenedChanged: {
        if (gateOpened && !done)
            envelope.opacity = 1
    }

    // warm spotlight behind the envelope
    Image {
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height * 1.4) * 0.9
        height: width
        source: showBridge.textureUrl("bokeh_cream.png")
        opacity: 0.16
        visible: !root.highContrast
    }

    Envelope {
        id: envelope
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -14
        width: Math.min(parent.width * 0.84, parent.height * 1.1)
        height: width * 0.65
        cfg: root.cfg
        interactive: false
        showHint: true
        hint: root.hint
        hintSize: root.hintSize
        hintColor: theme.palette["on-surface"] || "#fff5ee"
        scale: 0.98
        opacity: 0

        Behavior on opacity { NumberAnimation { duration: 420 } }
    }

    // whole-envelope hit target (larger than the wax seal); only active
    // once the gate has opened
    MouseArea {
        anchors.fill: envelope
        enabled: root.gateOpened && !root.done
        cursorShape: Qt.PointingHandCursor
        onClicked: root.advance()

    }

    // ------------------------------------------------------------------ //
    // Opening gate: dim screen, one breathing glass button (V1.1.0 fix #6)
    // ------------------------------------------------------------------ //
    Rectangle {
        id: gateDim
        anchors.fill: parent
        color: "#0a0714"
        opacity: root.gateOpened ? 0 : 0.96
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.InOutQuad } }

        Column {
            anchors.centerIn: parent
            spacing: 22

            // halo: scale breathing only — luminance never changes (F-27)
            Item {
                id: gateHalo
                width: 210; height: 210
                anchors.horizontalCenter: parent.horizontalCenter
                Image {
                    anchors.centerIn: parent
                    width: parent.width; height: parent.height
                    source: showBridge.textureUrl("bokeh_cream.png")
                    opacity: 0.34
                }
                SequentialAnimation on scale {
                    running: !root.reducedMotion && !root.gateOpened
                    loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 1.025; duration: 1600; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 1.025; to: 1.0; duration: 1600; easing.type: Easing.InOutSine }
                }
            }

            Rectangle {
                id: gateButton
                width: Math.max(220, gateLabel.implicitWidth + 88)
                height: 64
                radius: 32
                anchors.horizontalCenter: parent.horizontalCenter
                color: Qt.rgba(1, 1, 1, 0.15)
                border.width: 1.5
                border.color: Qt.rgba(1, 1, 1, 0.58)
                // >=96px effective hit target (F-03 spec) via the MouseArea below
                Text {
                    id: gateLabel
                    anchors.centerIn: parent
                    text: root.gateText
                    color: "#fff6e8"
                    font.family: theme.serifFamily
                    font.pixelSize: 26
                    font.letterSpacing: 4
                }
                // soft outer ring so the pill reads clearly on the dimmer
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -7
                    radius: parent.radius + 7
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.16)
                    visible: !root.highContrast
                }
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.10) }
                        GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.02) }
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.gateSubtext
                color: "#ffe9df"
                opacity: 0.6
                font.family: theme.hanFamily
                font.pixelSize: 16
                font.letterSpacing: 2
            }
        }

        MouseArea {
            anchors.centerIn: parent
            width: Math.max(320, gateButton.width + 40)
            height: 260   // button + halo + subtext zone, >=96px target
            enabled: !root.gateOpened
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openGate()
        }
    }

    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.gateOpened)
                root.advance()
            else
                root.openGate()
            event.accepted = true
        }
    }

    // Advancing means "open the envelope" — it requires the gate to be open,
    // so no stray path (keyboard, future wiring) can slip past the gate.
    function advance() {
        if (done || !gateOpened)
            return
        done = true
        sfx("whoosh")
        envelope.opacity = 0
        envelope.scale = 0.96
        finishTimer.start()
    }

    // F-29 skip: every act may be skipped; skipping the gate skips act 1 as a
    // whole (ShowStage.skipCurrent calls this instead of advance()).
    function skip() {
        if (done)
            return
        gateOpened = true
        done = true
        sfx("whoosh")
        envelope.opacity = 0
        finishTimer.interval = root.reducedMotion ? 60 : 140
        finishTimer.start()
    }

    property bool done: false

    Timer {
        id: finishTimer
        interval: root.reducedMotion ? 90 : 260
        onTriggered: root.actFinished()
    }

    Component.onCompleted: {
        // Without the gate the envelope shows immediately (v1.0.0 behavior).
        if (!gateEnabled)
            envelope.opacity = 1
        forceActiveFocus()
    }
}
