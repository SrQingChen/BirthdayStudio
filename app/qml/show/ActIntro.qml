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

    // whole-envelope hit target (larger than the wax seal)
    MouseArea {
        anchors.fill: envelope
        cursorShape: Qt.PointingHandCursor
        onClicked: root.advance()

    }

    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.advance()
            event.accepted = true
        }
    }

    function advance() {
        if (done)
            return
        done = true
        sfx("whoosh")
        envelope.opacity = 0
        envelope.scale = 0.96
        finishTimer.start()
    }

    property bool done: false

    Timer {
        id: finishTimer
        interval: root.reducedMotion ? 90 : 260
        onTriggered: root.actFinished()
    }

    Component.onCompleted: {
        envelope.opacity = 1
        forceActiveFocus()
    }
}
