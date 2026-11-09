import QtQuick
import QtQuick.Effects

// The seven-act ritual controller. Paper world (acts 1–5) dissolves from the
// centre to reveal the 3D cake, then the finale.
Item {
    id: stage

    property var profile: ({})
    property var tokens: ({})
    property bool previewMode: false
    property bool forceReducedMotion: false
    property bool forceHighContrast: false
    property real speedScale: 1.0
    property bool autoStart: false

    property bool running: false
    property bool started: false
    property string currentActId: ""
    property int actIndex: -1
    property int pendingEnterIndex: -1
    property bool dissolving: false
    property bool dissolveTextureReady: false
    property real dissolveProgress: 0
    property int dissolveMs: 560
    property bool paperVisible: true
    property bool cakeActive: false

    signal actChanged(string actId)
    signal finished()
    signal closeRequested()
    signal toast(string message)

    readonly property var acts: (profile && profile.acts) ? profile.acts : ({})
    readonly property var motionCfg: (profile && profile.global && profile.global.motion) ? profile.global.motion : ({})
    readonly property var accessCfg: (profile && profile.global && profile.global.accessibility) ? profile.global.accessibility : ({})
    readonly property bool systemReduced: app.systemReducedMotion === true
    readonly property bool reducedMotion: forceReducedMotion
                                         || motionCfg.reduced_motion === "on"
                                         || (motionCfg.reduced_motion !== "off" && systemReduced)
    readonly property bool highContrast: forceHighContrast || accessCfg.high_contrast === true
    readonly property bool cakeEnabled: acts.cake ? acts.cake.enabled !== false : false
    readonly property var order: computeOrder()
    readonly property bool canSkip: running
                                     && currentActId !== ""
                                     && currentActId !== "finale"
                                     && order.indexOf(currentActId) >= 0
                                     && (profile.global && profile.global.skip ? profile.global.skip.enabled !== false : true)
                                     && (acts[currentActId] ? acts[currentActId].skippable !== false : true)
    readonly property string currentLabel: labelFor(currentActId)

    function labelFor(id) {
        var map = {
            "intro": "开场", "wax": "火漆", "popups": "祝福", "confirm": "收下", "dissolve": "揭幕", "cake": "蛋糕", "finale": "终幕"
        }
        return map[id] || ""
    }

    function computeOrder() {
        var keys = ["intro", "wax", "popups", "confirm", "dissolve", "cake", "finale"]
        var out = []
        for (var i = 0; i < keys.length; i++) {
            var k = keys[i]
            var cfg = acts[k]
            if (!cfg || cfg.enabled === false)
                continue
            if (k === "dissolve" && !cakeEnabled)
                continue
            out.push(k)
        }
        return out
    }

    function profileTheme() {
        return profile && profile.meta ? profile.meta.theme : "glass-celebration"
    }

    function playSfx(kind) {
        var scale = 1.0
        switch (kind) {
        case "pop": scale = 0.30; break
        case "blow": scale = 0.5; break
        case "wax": scale = 0.7; break
        case "whoosh": scale = 0.55; break
        case "chime": scale = 0.65; break
        case "sparkle": scale = 0.6; break
        case "boom": scale = 0.85; break
        default: scale = 0.6
        }
        showBridge.playSfx(kind, scale)
    }

    function startBgm() {
        var audio = profile && profile.global ? profile.global.audio : ({})
        if (!audio)
            return
        try {
            showBridge.setMasterVolume(audio.master_volume_pct !== undefined ? audio.master_volume_pct : 50)
            showBridge.setSfxVolume(audio.sfx_volume_pct !== undefined ? audio.sfx_volume_pct : 60)
            showBridge.setDucking(audio.ducking_enabled !== false)
        } catch (e) { }
        if (!audio.bgm || !audio.bgm.path)
            return
        showBridge.playBgm(audio.bgm.path, audio.bgm.loop !== false, audio.bgm.volume_pct || 50, audio.bgm.fade_in_ms || 600)
    }

    function stopBgm() {
        var audio = profile && profile.global ? profile.global.audio : ({})
        var fade = audio && audio.bgm && audio.bgm.fade_out_ms !== undefined ? audio.bgm.fade_out_ms : 800
        showBridge.stopBgm(fade)
    }

    function playVoice() {
        var audio = profile && profile.global ? profile.global.audio : ({})
        var voice = audio && audio.voice ? audio.voice : ({})
        if (!voice.path)
            return
        showBridge.setDucking(audio.ducking_enabled !== false)
        showBridge.playVoice(voice.path, voice.volume_pct !== undefined ? voice.volume_pct : 85, true)
    }

    function stopVoice() {
        showBridge.stopVoice()
    }

    function start(fromAct) {
        resetAll()
        started = true
        running = true
        var first = fromAct || (order.length ? order[0] : "")
        if (first === "dissolve")
            first = "cake"
        var idx = order.indexOf(first)
        if (idx < 0)
            idx = 0
        startBgm()
        enterIndex(idx, true)
    }

    function resetAll() {
        paperSwap.stop()
        dissolveAnim.stop()
        paperFadeAnim.stop()
        enterDelayTimer.stop()
        exitAutoTimer.stop()
        pendingEnterIndex = -1
        paperLoader.sourceComponent = undefined
        confirmLoader.sourceComponent = undefined
        bigLoader.sourceComponent = undefined
        paperLayer.visible = true
        paperLayer.opacity = 1
        dissolving = false
        dissolveTextureReady = false
        dissolveProgress = 0
        paperVisible = true
        paperLayer.visible = true
        paperSource.live = false
        cakeActive = false
        if (cakeScene) {
            cakeScene.resetAll()
            // Drop the activation edge so a replay (stop -> start, or the
            // finale "再看一次") re-runs the cake entrance; onActiveChanged
            // is edge-triggered and would otherwise never fire again.
            cakeScene.active = false
        }
        currentActId = ""
        actIndex = -1
        started = false
        running = false
        showBridge.stopVoice()
    }

    function stop() {
        stopBgm()
        resetAll()
    }

    function restart() {
        stopBgm()
        resetAll()
        start("")
    }

    function enterIndex(index, direct) {
        if (index >= order.length) {
            finishShow()
            return
        }
        var id = order[index]
        var cfg = acts[id] || ({})
        var enterSpec = cfg.enter || "after-prev"
        var m = /^auto:(\d+)$/.exec(enterSpec)
        if (!direct && id !== "intro" && m && parseInt(m[1]) > 0) {
            pendingEnterIndex = index
            enterDelayTimer.interval = parseInt(m[1])
            enterDelayTimer.restart()
            return
        }
        enterNow(index)
    }

    function enterNow(index) {
        if (index < 0 || index >= order.length) {
            finishShow()
            return
        }
        exitAutoTimer.stop()
        actIndex = index
        var id = order[index]
        currentActId = id
        actChanged(id)
        pendingEnterIndex = -1
        var cfg = acts[id] || ({})
        var exitSpec = cfg.exit || ""
        var em = /^auto:(\d+)$/.exec(exitSpec)
        if (em && id !== "popups" && id !== "dissolve" && id !== "cake") {
            exitAutoTimer.interval = parseInt(em[1])
            exitAutoTimer.restart()
        }

        if (id === "dissolve") {
            beginDissolve()
            return
        }
        if (id === "cake") {
            paperVisible = false
            paperLayer.visible = false
            cakeActive = true
            if (cakeScene) cakeScene.active = true
            loadBig("cake")
            return
        }
        if (id === "finale") {
            paperVisible = false
            paperLayer.visible = false
            if (cakeEnabled) {
                cakeActive = true
                if (cakeScene) cakeScene.active = true
            }
            loadBig("finale")
            return
        }

        // paper world
        paperVisible = true
        paperLayer.visible = true
        paperLayer.opacity = 1
        if (id === "confirm") {
            confirmLoader.sourceComponent = confirmComp
            confirmLoader.opacity = 0
            confirmIn.start()
            return
        }
        // intro / wax / popups
        if (id === "intro") {
            paperLoader.sourceComponent = undefined
            paperLoader.sourceComponent = introComp
            paperLoader.opacity = 1
        } else if (id === "wax") {
            if (paperLoader.sourceComponent === introComp || paperLoader.item === null) {
                paperLoader.sourceComponent = undefined
                paperLoader.sourceComponent = waxComp
                paperLoader.opacity = 1
            } else {
                paperSwap.nextComp = waxComp
                paperSwap.start()
            }
        } else if (id === "popups") {
            if (paperLoader.sourceComponent === waxComp) {
                paperSwap.nextComp = popupsComp
                paperSwap.start()
            } else {
                paperLoader.sourceComponent = undefined
                paperLoader.sourceComponent = popupsComp
                paperLoader.opacity = 1
            }
        }
    }

    function advance() {
        if (!running || dissolving)
            return
        exitAutoTimer.stop()
        enterIndex(actIndex + 1, false)
    }

    function finishShow() {
        running = false
        stopVoice()
        finished()
    }

    function loadBig(kind) {
        bigLoader.sourceComponent = undefined
        bigLoader.sourceComponent = kind === "cake" ? cakeComp : finaleComp
    }

    // ------------------------------------------------------------------ //
    // Dissolve
    // ------------------------------------------------------------------ //
    function beginDissolve() {
        if (dissolving)
            return
        dissolving = true
        dissolveTextureReady = false
        dissolveProgress = 0
        cakeActive = cakeEnabled
        if (cakeScene) cakeScene.active = cakeEnabled
        var cfg = acts.dissolve || ({})
        dissolveMs = Math.max(250, (cfg.duration_ms || 560) / Math.max(0.25, speedScale))
        if (reducedMotion) {
            paperFadeAnim.duration = Math.min(360, dissolveMs)
            paperFadeAnim.start()
        } else {
            // Freeze the paper world into the effect source first, then hide
            // the live tree. This makes the whole layer (cards included)
            // dissolve, instead of only the backdrop.
            paperSource.live = true
            paperSource.hideSource = false
            dissolvePrepTimer.interval = 80
            dissolvePrepTimer.restart()
        }
    }

    function beginDissolveAnimation() {
        if (!dissolving)
            return
        dissolveTextureReady = true
        paperLayer.visible = false
        paperSource.live = false
        dissolveAnim.duration = dissolveMs
        dissolveAnim.restart()
    }

    function finishDissolve() {
        if (!dissolving)
            return
        dissolveAnim.stop()
        paperFadeAnim.stop()
        dissolvePrepTimer.stop()
        paperSource.live = false
        paperSource.hideSource = false
        dissolving = false
        dissolveTextureReady = false
        dissolveProgress = 0
        paperVisible = false
        paperLayer.visible = false
        enterIndex(actIndex + 1, false)
    }

    function skipCurrent() {
        if (!running || !canSkip)
            return
        if (pendingEnterIndex >= 0) {
            enterDelayTimer.stop()
            enterNow(pendingEnterIndex)
            return
        }
        if (dissolving) {
            dissolveAnim.stop()
            paperFadeAnim.stop()
            finishDissolve()
            return
        }
        if (currentActId === "finale")
            return
        var item = currentItem()
        if (item && typeof item.skip === "function") {
            item.skip()
            return
        }
        advance()
    }

    function currentItem() {
        if (currentActId === "confirm")
            return confirmLoader.item
        if (currentActId === "cake" || currentActId === "finale")
            return bigLoader.item
        if (currentActId === "dissolve")
            return null
        return paperLoader.item
    }

    // ------------------------------------------------------------------ //
    // Layers
    // ------------------------------------------------------------------ //
    property var cakeScene: cakeLoader.item

    Loader {
        id: cakeLoader
        anchors.fill: parent
        visible: stage.cakeEnabled && (stage.cakeActive || stage.currentActId === "dissolve" || stage.currentActId === "cake" || stage.currentActId === "finale")
        sourceComponent: app.force2d ? cake2DComp : cake3DComp
        onStatusChanged: {
            if (status === Loader.Error && sourceComponent !== cake2DComp)
                sourceComponent = cake2DComp
        }
        onLoaded: {
            if (item) {
                try {
                    item.sfx.connect(function (kind) { stage.playSfx(kind) })
                } catch (e) { }
            }
        }
    }

    Item {
        id: paperLayer
        anchors.fill: parent
        visible: stage.paperVisible

        Loader {
            id: backgroundSlot
            anchors.fill: parent
            source: {
                var rev = showBridge.pluginRevision
                return showBridge.slotComponent("Background")
            }
            visible: status === Loader.Ready
            onLoaded: {
                try {
                    item.tokens = stage.tokens
                    item.variant = "paper"
                    item.reducedMotion = stage.reducedMotion
                    item.highContrast = stage.highContrast
                } catch (e) {
                    source = ""
                }
            }
        }

        BackgroundStage {
            anchors.fill: parent
            visible: backgroundSlot.status !== Loader.Ready
            tokens: stage.tokens
            variant: "paper"
            reducedMotion: stage.reducedMotion
            highContrast: stage.highContrast
        }

        Loader {
            id: paperLoader
            anchors.fill: parent
            asynchronous: false
        }

        Loader {
            id: confirmLoader
            anchors.fill: parent
            opacity: 0
        }
    }

    ShaderEffectSource {
        id: paperSource
        sourceItem: paperLayer
        hideSource: stage.dissolving && !stage.reducedMotion
        live: stage.dissolving && !stage.reducedMotion
        recursive: true
        visible: false
    }

    Item {
        id: dissolveLayer
        anchors.fill: parent
        visible: stage.dissolving && stage.dissolveTextureReady && !stage.reducedMotion
        MultiEffect {
            anchors.fill: parent
            source: paperSource
            autoPaddingEnabled: false
            maskEnabled: true
            maskSource: maskImage
            maskThresholdMin: -0.12 + stage.dissolveProgress * 1.26
            maskThresholdMax: 0.02 + stage.dissolveProgress * 1.22
            maskSpreadAtMin: 0.22
            maskSpreadAtMax: 0.22
        }
        Image {
            id: ringImage
            anchors.centerIn: parent
            width: parent.width * (0.16 + stage.dissolveProgress * 1.05)
            height: width
            source: showBridge.textureUrl("dissolve_ring.png")
            fillMode: Image.PreserveAspectFit
            opacity: stage.dissolving ? Math.sin(Math.min(1, stage.dissolveProgress) * Math.PI) * 0.55 : 0
            visible: !stage.highContrast
        }

        Loader {
            id: dissolveSlot
            anchors.fill: parent
            source: {
                var rev = showBridge.pluginRevision
                return showBridge.slotComponent("DissolveEffect")
            }
            visible: status === Loader.Ready
            onLoaded: {
                try {
                    item.progress = Qt.binding(function () { return stage.dissolveProgress })
                    item.active = Qt.binding(function () { return stage.dissolving })
                } catch (e) {
                    source = ""
                }
            }
        }
    }

    Image {
        id: maskImage
        anchors.fill: parent
        source: showBridge.textureUrl("dissolve_mask.png")
        fillMode: Image.Stretch
        visible: false
        layer.enabled: true
        smooth: true
    }

    Item {
        id: bigLayer
        anchors.fill: parent
        Loader {
            id: bigLoader
            anchors.fill: parent
        }
    }

    // ------------------------------------------------------------------ //
    // Animations / timers
    // ------------------------------------------------------------------ //
    Timer {
        id: dissolvePrepTimer
        interval: 80
        onTriggered: stage.beginDissolveAnimation()
    }

    Timer {
        id: enterDelayTimer
        interval: 1000
        onTriggered: stage.enterNow(stage.pendingEnterIndex)
    }

    Timer {
        id: exitAutoTimer
        interval: 1000
        onTriggered: stage.advance()
    }

    NumberAnimation {
        id: dissolveAnim
        target: stage
        property: "dissolveProgress"
        from: 0
        to: 1
        duration: 560
        easing.type: Easing.InOutQuad
        onFinished: stage.finishDissolve()
    }

    NumberAnimation {
        id: paperFadeAnim
        target: paperLayer
        property: "opacity"
        from: 1
        to: 0
        duration: 300
        onFinished: stage.finishDissolve()
    }

    SequentialAnimation {
        id: paperSwap
        property var nextComp: null
        NumberAnimation { target: paperLoader; property: "opacity"; to: 0; duration: stage.reducedMotion ? 60 : 150 }
        ScriptAction {
            script: {
                paperLoader.sourceComponent = undefined
                paperLoader.sourceComponent = paperSwap.nextComp
            }
        }
        NumberAnimation { target: paperLoader; property: "opacity"; to: 1; duration: stage.reducedMotion ? 80 : 240 }
    }

    NumberAnimation {
        id: confirmIn
        target: confirmLoader
        property: "opacity"
        from: 0
        to: 1
        duration: stage.reducedMotion ? 160 : 360
        easing.type: Easing.OutCubic
    }

    Component {
        id: cake3DComp
        Cake3DStage {
            anchors.fill: parent
            profile: stage.profile
            tokens: stage.tokens
            reducedMotion: stage.reducedMotion
            highContrast: stage.highContrast
            active: stage.cakeActive
        }
    }

    Component {
        id: cake2DComp
        Cake2DStage {
            anchors.fill: parent
            profile: stage.profile
            tokens: stage.tokens
            reducedMotion: stage.reducedMotion
            highContrast: stage.highContrast
            active: stage.cakeActive
        }
    }

    // ------------------------------------------------------------------ //
    // Act components
    // ------------------------------------------------------------------ //
    Component {
        id: introComp
        ActIntro {
            profile: stage.profile
            tokens: stage.tokens
            cfg: stage.acts.intro || ({})
            reducedMotion: stage.reducedMotion
            highContrast: stage.highContrast
            speedScale: stage.speedScale
            onActFinished: stage.advance()
            onSfx: function (kind) { stage.playSfx(kind) }
        }
    }

    Component {
        id: waxComp
        ActWax {
            profile: stage.profile
            tokens: stage.tokens
            cfg: stage.acts.wax || ({})
            reducedMotion: stage.reducedMotion
            highContrast: stage.highContrast
            speedScale: stage.speedScale
            onActFinished: stage.advance()
            onSfx: function (kind) { stage.playSfx(kind) }
            onVoiceRequested: stage.playVoice()
        }
    }

    Component {
        id: popupsComp
        ActPopups {
            profile: stage.profile
            tokens: stage.tokens
            cfg: stage.acts.popups || ({})
            reducedMotion: stage.reducedMotion
            highContrast: stage.highContrast
            speedScale: stage.speedScale
            onActFinished: stage.advance()
            onSfx: function (kind) { stage.playSfx(kind) }
        }
    }

    Component {
        id: confirmComp
        ActConfirm {
            profile: stage.profile
            tokens: stage.tokens
            cfg: stage.acts.confirm || ({})
            reducedMotion: stage.reducedMotion
            highContrast: stage.highContrast
            speedScale: stage.speedScale
            onActFinished: stage.advance()
            onSfx: function (kind) { stage.playSfx(kind) }
        }
    }

    Component {
        id: cakeComp
        ActCake {
            profile: stage.profile
            tokens: stage.tokens
            cfg: stage.acts.cake || ({})
            reducedMotion: stage.reducedMotion
            highContrast: stage.highContrast
            speedScale: stage.speedScale
            cakeStage: cakeScene
            onActFinished: stage.advance()
            onSfx: function (kind) { stage.playSfx(kind) }
        }
    }

    Component {
        id: finaleComp
        ActFinale {
            profile: stage.profile
            tokens: stage.tokens
            cfg: stage.acts.finale || ({})
            reducedMotion: stage.reducedMotion
            highContrast: stage.highContrast
            speedScale: stage.speedScale
            onActFinished: stage.finishShow()
            onReplay: stage.restart()
            onCloseShow: stage.closeRequested()
            onSfx: function (kind) { stage.playSfx(kind) }
        }
    }

    Component.onCompleted: {
        if (autoStart)
            start("")
    }

    Component.onDestruction: {
        if (running)
            stopBgm()
        stopVoice()
    }
}
