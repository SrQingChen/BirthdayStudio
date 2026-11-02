import QtQuick
import QtQuick3D
import QtQuick3D.Helpers

// The 3D cake, candles and wish-stage lighting. Kept alive beneath the paper
// layer so the centre-out dissolve can reveal the actual scene (F-13).
Item {
    id: root

    property var profile: ({})
    property var tokens: ({})
    property bool reducedMotion: false
    property bool highContrast: false
    property bool active: false

    signal candleBlownOut(int index)
    signal allCandlesOut()
    signal sfx(string kind)

    property var outFlags: []
    property int litCount: 0
    property bool entered: false
    property real dragYaw: 0
    property real dragPitch: 0
    property real dragStartYaw: 0
    property real dragStartPitch: 0

    readonly property var cakeCfg: (profile.acts && profile.acts.cake && profile.acts.cake.cake) ? profile.acts.cake.cake : ({})
    readonly property var candleCfg: (profile.acts && profile.acts.cake && profile.acts.cake.candles) ? profile.acts.cake.candles : ({})
    readonly property var camCfg: (profile.acts && profile.acts.cake && profile.acts.cake.camera) ? profile.acts.cake.camera : ({})
    readonly property var jellyCfg: (profile.acts && profile.acts.cake && profile.acts.cake.jelly) ? profile.acts.cake.jelly : ({})

    readonly property var layers: cakeCfg.layers || []
    readonly property int layerCount: layers.length
    readonly property int candleCount: candleCfg.count !== undefined ? candleCfg.count : 5
    readonly property real plateTop: 16

    function layerBaseY(i) {
        var y = plateTop
        for (var j = 0; j < i; j++)
            y += (layers[j].height || 80)
        return y
    }
    function layerTopY(i) {
        return layerBaseY(i) + (layers[i].height || 80)
    }
    readonly property real topY: layerCount > 0 ? layerTopY(layerCount - 1) : 200
    readonly property real topRadius: layerCount > 0 ? (layers[layerCount - 1].radius || 106) : 100

    function candlePoint(i) {
        var n = Math.max(1, candleCount)
        var R = topRadius * 0.56
        var arrangement = candleCfg.arrangement || "arc"
        if (arrangement === "circle") {
            var a = i / n * Math.PI * 2
            return { x: Math.cos(a) * R * 0.86, z: Math.sin(a) * R * 0.72 }
        }
        if (arrangement === "line") {
            var sp = candleCfg.spacing || 36
            return { x: (i - (n - 1) / 2) * sp, z: 0 }
        }
        var f = n <= 1 ? 0.5 : i / (n - 1)
        var ang = -Math.PI * 0.44 + f * Math.PI * 0.88
        return { x: Math.sin(ang) * R, z: -Math.cos(ang) * R * 0.42 }
    }

    function candleColor(i) {
        var list = candleCfg.colors || ["#f2a7b8"]
        return list[i % list.length]
    }

    function resetAll() {
        entered = false
        resetCandles()
        view.opacity = 0
        cakeRoot.scale = Qt.vector3d(0.92, 0.92, 0.92)
        cakeRoot.position = Qt.vector3d(0, -6, 0)
        root.dragYaw = 0
        root.dragPitch = 0
    }

    function resetCandles() {
        var flags = []
        for (var i = 0; i < candleCount; i++)
            flags.push(false)
        outFlags = flags
        litCount = candleCount
    }

    function blowOut(index) {
        if (index < 0 || index >= candleCount)
            return
        var flags = outFlags.slice()
        if (flags[index])
            return
        flags[index] = true
        outFlags = flags
        litCount = candleCount - flags.filter(function (v) { return v }).length
        sfx("blow")
        candleBlownOut(index)
        if (litCount <= 0)
            allCandlesOut()
    }

    function blowAll() {
        var flags = []
        for (var i = 0; i < candleCount; i++)
            flags.push(true)
        outFlags = flags
        litCount = 0
        allCandlesOut()
    }

    function jelly() {
        if (root.reducedMotion) {
            return
        }
        jellyDown.start()
    }

    onOutFlagsChanged: litCount = candleCount - outFlags.filter(function (v) { return v }).length

    Component.onCompleted: resetCandles()

    onActiveChanged: {
        if (active && !entered) {
            entered = true
            entrance.start()
        }
    }

    // ------------------------------------------------------------------ //
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
                item.tokens = root.tokens
                item.variant = "cake"
                item.reducedMotion = root.reducedMotion
                item.highContrast = root.highContrast
            } catch (e) {
                source = ""
            }
        }
    }

    BackgroundStage {
        anchors.fill: parent
        visible: backgroundSlot.status !== Loader.Ready
        tokens: root.tokens
        variant: "cake"
        reducedMotion: root.reducedMotion
        highContrast: root.highContrast
    }

    View3D {
        id: view
        anchors.fill: parent
        opacity: 0

        environment: SceneEnvironment {
            backgroundMode: SceneEnvironment.Transparent
            antialiasingMode: SceneEnvironment.MSAA
            antialiasingQuality: SceneEnvironment.High
        }

        Node {
            id: rig
            position: Qt.vector3d(0, 170, 0)
            eulerRotation.y: (root.camCfg.yaw || -16) + root.dragYaw

            PerspectiveCamera {
                id: cam
                property real dist: root.camCfg.distance || 980
                property real pitchRad: (root.camCfg.pitch || 26) * Math.PI / 180
                position: Qt.vector3d(0, dist * Math.sin(pitchRad), dist * Math.cos(pitchRad))
                eulerRotation.x: -(root.camCfg.pitch || 26) - root.dragPitch
                fieldOfViewOrientation: PerspectiveCamera.Vertical
                fieldOfView: 44
                clipNear: 10
                clipFar: 4000
            }
        }

        DirectionalLight {
            eulerRotation.x: -48
            eulerRotation.y: -32
            color: "#fff1e0"
            brightness: 1.55
            ambientColor: "#6a5a70"
            castsShadow: true
            shadowMapQuality: Light.ShadowMapQualityHigh
            shadowFactor: 55
            shadowMapFar: 2200
        }
        DirectionalLight {
            eulerRotation.x: -18
            eulerRotation.y: 135
            color: "#9fc7ff"
            brightness: 0.35
            castsShadow: false
        }
        PointLight {
            id: cakeLight
            position: Qt.vector3d(0, root.topY + 150, 140)
            color: "#ffb46e"
            brightness: 1.6
            quadraticFade: 1.2
            castsShadow: false
            SequentialAnimation on brightness {
                running: !root.reducedMotion
                loops: Animation.Infinite
                NumberAnimation { from: 0.78; to: 1.02; duration: 1700; easing.type: Easing.InOutSine }
                NumberAnimation { from: 1.02; to: 0.78; duration: 1500; easing.type: Easing.InOutSine }
            }
        }

        Node {
            id: cakeRoot
            scale: Qt.vector3d(0.92, 0.92, 0.92)
            position: Qt.vector3d(0, -6, 0)

            // plate
            Model {
                source: "#Cylinder"
                objectName: "cake_plate"
                pickable: true
                position: Qt.vector3d(0, root.plateTop / 2 - 2, 0)
                scale: Qt.vector3d(5.2, 0.14, 5.2)
                castsShadows: true
                materials: PrincipledMaterial {
                    baseColor: root.cakeCfg.plate_color || "#e9e2d6"
                    roughness: 0.34
                    metalness: 0.06
                }
            }

            Repeater3D {
                model: root.layerCount
                delegate: Node {
                    id: layerNode
                    property var layer: root.layers[index] || ({})
                    property real radius: layer.radius || 120
                    property real layerHeight: layer.height || 80
                    property real baseY: root.layerBaseY(index)
                    property real topAt: root.layerTopY(index)

                    Model {
                        source: "#Cylinder"
                        objectName: "cake_layer_" + index
                        pickable: true
                        position: Qt.vector3d(0, layerNode.baseY + layerNode.layerHeight / 2, 0)
                        scale: Qt.vector3d(layerNode.radius / 50, layerNode.layerHeight / 100, layerNode.radius / 50)
                        castsShadows: true
                        materials: PrincipledMaterial {
                            baseColor: layerNode.layer.color || "#f6d3c3"
                            roughness: layerNode.layer.roughness !== undefined ? layerNode.layer.roughness : 0.62
                            metalness: root.cakeCfg.metalness !== undefined ? root.cakeCfg.metalness : 0.02
                        }
                    }

                    // cream top / rim (a very flat disc; #Torus is not a
                    // built-in primitive on every Qt Quick 3D build)
                    Model {
                        source: "#Cylinder"
                        objectName: "cake_frosting_" + index
                        position: Qt.vector3d(0, layerNode.topAt + 1, 0)
                        scale: Qt.vector3d(layerNode.radius / 50 * 1.015, 0.035, layerNode.radius / 50 * 1.015)
                        castsShadows: false
                        materials: PrincipledMaterial {
                            baseColor: layerNode.layer.frosting || "#fff4ec"
                            roughness: 0.5
                        }
                    }

                    // piping drips
                    Repeater3D {
                        model: root.reducedMotion ? 10 : 18
                        delegate: Model {
                            source: "#Sphere"
                            position: {
                                var a = index / 18 * Math.PI * 2
                                return Qt.vector3d(
                                    Math.cos(a) * layerNode.radius * 0.96,
                                    layerNode.topAt - 8 - (index % 3) * 5,
                                    Math.sin(a) * layerNode.radius * 0.96)
                            }
                            scale: {
                                var s = 0.13 + (index % 3) * 0.025
                                return Qt.vector3d(s, s * 1.5, s)
                            }
                            castsShadows: false
                            materials: PrincipledMaterial {
                                baseColor: layerNode.layer.frosting || "#fff4ec"
                                roughness: 0.5
                            }
                        }
                    }
                }
            }

            // fruit on top
            Repeater3D {
                model: root.cakeCfg.decorations && root.cakeCfg.decorations.indexOf("fruit") >= 0 ? 7 : 0
                delegate: Model {
                    source: "#Sphere"
                    property real a: index / 7 * Math.PI * 2 + 0.35
                    position: Qt.vector3d(Math.cos(a) * root.topRadius * 0.62,
                                          root.topY + 8,
                                          Math.sin(a) * root.topRadius * 0.62)
                    scale: Qt.vector3d(0.14, 0.14, 0.14)
                    castsShadows: false
                    materials: PrincipledMaterial {
                        baseColor: ["#e8543f", "#f08a3c", "#d93a52", "#f2b134"][index % 4]
                        roughness: 0.35
                    }
                }
            }

            // sprinkles
            Repeater3D {
                model: !!(root.cakeCfg.decorations && root.cakeCfg.decorations.indexOf("sprinkles") >= 0) ? (root.reducedMotion ? 18 : 46) : 0
                delegate: Model {
                    source: "#Cube"
                    property real a: (index * 2.399963) % (Math.PI * 2)
                    property real r: root.topRadius * (0.2 + ((index * 37) % 100) / 140)
                    position: Qt.vector3d(Math.cos(a) * r, root.topY + 3, Math.sin(a) * r)
                    scale: Qt.vector3d(0.05, 0.015, 0.015)
                    eulerRotation.y: index * 41
                    castsShadows: false
                    materials: PrincipledMaterial {
                        baseColor: ["#ffffff", "#ffd166", "#ff8fab", "#8ecae6", "#b8e0d2"][index % 5]
                        roughness: 0.6
                    }
                }
            }

            // plaque on the front of the top tier
            Node {
                visible: !!(root.cakeCfg.decorations && root.cakeCfg.decorations.indexOf("namePlague") >= 0)
                position: Qt.vector3d(0, root.topY - 30, root.topRadius * 1.005)

                Model {
                    objectName: "cake"
                    source: "#Cube"
                    scale: Qt.vector3d(1.74, 0.50, 0.06)
                    castsShadows: false
                    materials: PrincipledMaterial {
                        baseColor: "#c98f6b"
                        roughness: 0.5
                    }
                }
                Model {
                    objectName: "cake"
                    source: "#Rectangle"
                    scale: Qt.vector3d(1.70, 0.46, 1)
                    position: Qt.vector3d(0, 0, 4)
                    castsShadows: false
                    materials: PrincipledMaterial {
                        baseColor: "#fff6e8"
                        baseColorMap: Texture {
                            source: showBridge.plaqueUrl("生日快乐", root.profile.meta ? root.profile.meta.honoree : "")
                        }
                        lighting: PrincipledMaterial.NoLighting
                        opacity: 1.0
                    }
                }
            }

            // candles
            Repeater3D {
                model: root.candleCount
                delegate: Node {
                    id: candleNode
                    property var pt: root.candlePoint(index)
                    property bool isOut: root.outFlags.length > index ? root.outFlags[index] : false
                    property real ch: root.candleCfg.height || 54
                    property real cr: root.candleCfg.radius || 6

                    Model {
                        source: "#Cylinder"
                        objectName: "candle_" + index
                        pickable: true
                        position: Qt.vector3d(candleNode.pt.x, root.topY + candleNode.ch / 2, candleNode.pt.z)
                        scale: Qt.vector3d(candleNode.cr / 50, candleNode.ch / 100, candleNode.cr / 50)
                        castsShadows: true
                        materials: PrincipledMaterial {
                            baseColor: root.candleColor(index)
                            roughness: 0.52
                        }
                    }

                    Model {
                        source: "#Cylinder"
                        objectName: "candle_" + index
                        pickable: true
                        position: Qt.vector3d(candleNode.pt.x, root.topY + candleNode.ch + 3, candleNode.pt.z)
                        scale: Qt.vector3d(0.012, 0.08, 0.012)
                        castsShadows: false
                        materials: PrincipledMaterial {
                            baseColor: "#3a2b26"
                            roughness: 0.9
                        }
                    }

                    // flame
                    Node {
                        id: flameNode
                        visible: !candleNode.isOut
                        position: Qt.vector3d(candleNode.pt.x, root.topY + candleNode.ch + 12, candleNode.pt.z)
                        eulerRotation.y: -(root.camCfg.yaw || -16)

                        Node {
                            id: flameScale
                            SequentialAnimation on scale {
                                running: !root.reducedMotion && !candleNode.isOut
                                loops: Animation.Infinite
                                Vector3dAnimation { from: Qt.vector3d(1, 1, 1); to: Qt.vector3d(1.05, 1.12, 1.05); duration: 260 + index * 30; easing.type: Easing.InOutSine }
                                Vector3dAnimation { from: Qt.vector3d(1.05, 1.12, 1.05); to: Qt.vector3d(0.98, 0.94, 0.98); duration: 210 + index * 25; easing.type: Easing.InOutSine }
                                Vector3dAnimation { from: Qt.vector3d(0.98, 0.94, 0.98); to: Qt.vector3d(1, 1, 1); duration: 190; easing.type: Easing.InOutSine }
                            }
                            SequentialAnimation on eulerRotation {
                                running: !root.reducedMotion && !candleNode.isOut
                                loops: Animation.Infinite
                                Vector3dAnimation { from: Qt.vector3d(0, 0, -3 - root.dragYaw); to: Qt.vector3d(0, 0, 3 + root.dragYaw); duration: 900 + index * 70; easing.type: Easing.InOutSine }
                                Vector3dAnimation { from: Qt.vector3d(0, 0, 3 + root.dragYaw); to: Qt.vector3d(0, 0, -3 - root.dragYaw); duration: 1000 + index * 60; easing.type: Easing.InOutSine }
                            }

                            Model {
                                objectName: "candle_" + index
                                pickable: true
                                source: "#Rectangle"
                                position: Qt.vector3d(0, 14, 0)
                                scale: Qt.vector3d(0.34 * (root.candleCfg.flame_intensity || 1), 0.56 * (root.candleCfg.flame_intensity || 1), 1)
                                materials: PrincipledMaterial {
                                    baseColor: "#ffffff"
                                    baseColorMap: Texture { source: showBridge.textureUrl("flame.png") }
                                    lighting: PrincipledMaterial.NoLighting
                                    alphaMode: PrincipledMaterial.Blend
                                    opacity: root.reducedMotion ? 0.85 : 0.95
                                }
                            }
                            Model {
                                objectName: "candle_" + index
                                pickable: true
                                source: "#Rectangle"
                                position: Qt.vector3d(0, 16, -1)
                                scale: Qt.vector3d(0.62, 0.9, 1)
                                materials: PrincipledMaterial {
                                    baseColor: "#ffffff"
                                    baseColorMap: Texture { source: showBridge.textureUrl("glow.png") }
                                    lighting: PrincipledMaterial.NoLighting
                                    alphaMode: PrincipledMaterial.Blend
                                    opacity: 0.28
                                }
                            }
                            Model {
                                source: "#Sphere"
                                position: Qt.vector3d(0, 3, 0)
                                scale: Qt.vector3d(0.065, 0.09, 0.065)
                                materials: PrincipledMaterial {
                                    baseColor: "#fff8e1"
                                    emissiveFactor: Qt.vector3d(2.2, 1.9, 1.2)
                                    lighting: PrincipledMaterial.NoLighting
                                }
                            }
                        }
                    }

                    // smoke puff after blowing out
                    Node {
                        id: smokeNode
                        position: Qt.vector3d(candleNode.pt.x, root.topY + candleNode.ch + 32, candleNode.pt.z)
                        eulerRotation.y: -(root.camCfg.yaw || -16)
                        visible: candleNode.isOut
                        opacity: 0

                        Model {
                            source: "#Rectangle"
                            scale: Qt.vector3d(0.72, 0.9, 1)
                            materials: PrincipledMaterial {
                                baseColor: "#c9c3c9"
                                baseColorMap: Texture { source: showBridge.textureUrl("smoke.png") }
                                lighting: PrincipledMaterial.NoLighting
                                opacity: smokeNode.opacity * 0.55
                                alphaMode: PrincipledMaterial.Blend
                            }
                        }
                        SequentialAnimation {
                            running: candleNode.isOut
                            PauseAnimation { duration: 60 + index * 60 }
                            NumberAnimation { target: smokeNode; property: "opacity"; from: 0.9; to: 0; duration: 1500; easing.type: Easing.OutQuad }
                            NumberAnimation { target: smokeNode; property: "y"; from: root.topY + candleNode.ch + 32; to: root.topY + candleNode.ch + 150; duration: 1500; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }
        }

        // drag to look around, click candles / cake
        DragHandler {
            id: drag
            target: null
            onActiveChanged: {
                if (active) {
                    root.dragStartYaw = root.dragYaw
                    root.dragStartPitch = root.dragPitch
                } else {
                    dragReturn.start()
                }
            }
            onTranslationChanged: {
                if (!active)
                    return
                root.dragYaw = Math.max(-14, Math.min(14, root.dragStartYaw + translation.x * 0.02))
                root.dragPitch = Math.max(-4, Math.min(4, root.dragStartPitch - translation.y * 0.012))
            }
        }

        TapHandler {
            id: tap
            onTapped: function (eventPoint, button) {
                var p = view.mapFromItem(null, eventPoint.scenePosition.x, eventPoint.scenePosition.y)
                var hit = view.pick(p.x, p.y)
                if (!hit || !hit.objectHit)
                    return
                var name = String(hit.objectHit.objectName || "")
                if (name.indexOf("candle_") === 0) {
                    var index = parseInt(name.substring(7))
                    if (!isNaN(index))
                        root.blowOut(index)
                    return
                }
                if (name === "cake" || name.indexOf("cake_") === 0) {
                    root.jelly()
                }
            }
        }
    }

    // CakeDecor slot: a 2D decoration overlay above the 3D scene (visual only)
    Loader {
        id: decorSlot
        anchors.fill: parent
        z: 6
        source: {
            var rev = showBridge.pluginRevision
            return showBridge.slotComponent("CakeDecor")
        }
        visible: status === Loader.Ready && root.active
        onLoaded: {
            try {
                item.tokens = root.tokens
                item.profile = root.profile
                item.active = Qt.binding(function () { return root.active })
            } catch (e) {
                source = ""
            }
        }
    }

    // subtle vignette over the 3D scene
    Image {
        anchors.fill: parent
        source: showBridge.textureUrl("vignette.png")
        fillMode: Image.Stretch
        opacity: root.reducedMotion ? 0.25 : 0.5
        visible: !root.highContrast
    }

    ParallelAnimation {
        id: entrance
        NumberAnimation { target: view; property: "opacity"; from: 0; to: 1; duration: 620 }
        Vector3dAnimation {
            target: cakeRoot; property: "scale"
            from: Qt.vector3d(0.86, 0.86, 0.86)
            to: Qt.vector3d(1, 1, 1)
            duration: 900
            easing.type: Easing.OutBack
            easing.overshoot: 1.05
        }
        NumberAnimation { target: cakeRoot; property: "y"; from: -40; to: 0; duration: 820; easing.type: Easing.OutCubic }
    }

    SequentialAnimation {
        id: jellyDown
        Vector3dAnimation {
            target: cakeRoot; property: "scale"
            to: Qt.vector3d(1.07, 0.93, 1.07)
            duration: 90
            easing.type: Easing.OutQuad
        }
        Vector3dAnimation {
            target: cakeRoot; property: "scale"
            to: Qt.vector3d(1, 1, 1)
            duration: 700
            easing.type: Easing.OutElastic
            easing.amplitude: 0.22
            easing.period: 0.35
        }
    }

    NumberAnimation {
        id: dragReturn
        target: root
        property: "dragYaw"
        to: 0
        duration: 420
        easing.type: Easing.OutCubic
    }
}
