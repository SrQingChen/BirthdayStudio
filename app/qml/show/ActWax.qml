import QtQuick

// Act 2 — break the wax seal, the letter rises (or skip the letter entirely).
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

    readonly property var globalCfg: profile.global || ({})
    readonly property var waxCfg: cfg || ({})
    readonly property string letterMode: waxCfg.letter_mode || "animated"
    readonly property var letterCfg: waxCfg.letter || ({})
    readonly property var introCfg: (profile.acts && profile.acts.intro) ? profile.acts.intro : ({})

    property bool opening: false
    property bool letterShown: false
    property bool done: false

    readonly property var envelopeCfg: ({
        envelope: introCfg.envelope || {},
        press_scale: waxCfg.press_scale !== undefined ? waxCfg.press_scale : 0.94
    })

    Envelope {
        id: envelope
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -14
        width: Math.min(parent.width * 0.84, parent.height * 1.1)
        height: width * 0.65
        cfg: root.envelopeCfg
        interactive: !root.opening
        showHint: !root.opening
        hint: root.letterMode === "none" ? "按下火漆，让祝福飞出来" : "按下火漆，拆开这封信"
        hintSize: 20
        hintColor: theme.palette["on-surface"] || "#fff5ee"
        opacity: 0

        Behavior on opacity { NumberAnimation { duration: 320 } }

        onSealClicked: {
            root.opening = true
            root.sfx("wax")
        }
        onOpened: root.revealLetter()
    }

    LetterView {
        id: letter
        anchors.fill: parent
        visible: false
        profile: root.profile
        cfg: root.letterCfg
        tokens: root.tokens
        reducedMotion: root.reducedMotion
        highContrast: root.highContrast
        onActFinished: {
            if (!root.done) {
                root.done = true
                root.actFinished()
            }
        }
    }

    function openSeal() {
        envelope.activate()
    }

    function revealLetter() {
        envelope.showHint = false
        if (letterMode === "none") {
            sfx("whoosh")
            envelope.opacity = 0
            waitTimer.start()
            return
        }
        letter.visible = true
        letterShown = true
        sfx("whoosh")
        letter.startPresentation()
        letter.forceActiveFocus()
    }

    Timer {
        id: waitTimer
        interval: root.reducedMotion ? 160 : 520
        onTriggered: {
            if (!root.done) {
                root.done = true
                root.actFinished()
            }
        }
    }

    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (letterShown)
                letter.advance()
            event.accepted = true
        }
    }

    Component.onCompleted: {
        envelope.opacity = 1
        forceActiveFocus()
    }
}
