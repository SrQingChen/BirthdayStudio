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
    property real dragStartYaw: 0
    // V1.1.0 fix #3: free rotation with inertia + stackable jelly spring.
    property real dragVel: 0          // deg/s, estimated during the drag
    property real lastDragYaw: 0
    property real lastDragT: 0
    property real windTilt: 0         // bounded flame lean while spinning
    // Damped-oscillator state for the jelly squash (V1.1.0 fix #3c):
    // each tap injects velocity, so taps during the wobble stack energy.
    property real jellyX: 0
    property real jellyV: 0

    readonly property var cakeCfg: (profile.acts && profile.acts.cake && profile.acts.cake.cake) ? profile.acts.cake.cake : ({})
    readonly property var candleCfg: (profile.acts && profile.acts.cake && profile.acts.cake.candles) ? profile.acts.cake.candles : ({})
    readonly property var camCfg: (profile.acts && profile.acts.cake && profile.acts.cake.camera) ? profile.acts.cake.camera : ({})
    readonly property var jellyCfg: (profile.acts && profile.acts.cake && profile.acts.cake.jelly) ? profile.acts.cake.jelly : ({})
    // Spring mapping for the jelly oscillator (schema jelly.spring 1..6,
    // jelly.damping 0.1..0.9 -> k/c; defaults 4.2/0.42 give ~0.9s settle
    // with 2-3 overshoots, matching the v1.0.0 feel).
    readonly property real jellyK: (jellyCfg.spring || 4.2) * 14
    readonly property real jellyC: (jellyCfg.damping || 0.42) * 6

    readonly property var layers: cakeCfg.layers || []
    readonly property int layerCount: layers.length
    readonly property int candleCount: candleCfg.count !== undefined ? candleCfg.count : 5
    readonly property real plateTop: 16
    readonly property var decorationList: cakeCfg.decorations || []
    readonly property bool decorPiping: decorationList.indexOf("piping") >= 0
    readonly property bool decorFruit: decorationList.indexOf("fruit") >= 0
    readonly property bool decorSprinkles: decorationList.indexOf("sprinkles") >= 0
    readonly property bool decorPlaque: decorationList.indexOf("namePlague") >= 0
    readonly property string topFrosting: layerCount > 0
        ? (layers[layerCount - 1].frosting || "#fff4ec") : "#fff4ec"
    // A whisper of the theme's primary in the piped cream, so the swirls
    // separate from the white frosting without looking like another flavour.
    readonly property color rosetteColor: {
        var pal = (tokens && tokens.color && tokens.color.palette) ? tokens.color.palette : ({})
        if (!pal.primary)
            return topFrosting
        var q = Qt.color(pal.primary)
        return Qt.tint(topFrosting, Qt.rgba(q.r, q.g, q.b, 0.13))
    }
    // Trim colour follows the theme's secondary (gold/cream) so the ribbon
    // belongs to the same palette as the candles and cards.
    readonly property color ribbonColor: {
        if (cakeCfg.ribbon_color)
            return cakeCfg.ribbon_color
        var pal = (tokens && tokens.color && tokens.color.palette) ? tokens.color.palette : ({})
        return Qt.darker(pal.secondary || "#ffd5a6", 1.10)
    }
    readonly property var sprinkleColors: {
        var pal = (tokens && tokens.color && tokens.color.palette) ? tokens.color.palette : ({})
        return [pal.primary || "#ffb08a", pal.secondary || "#ffd5a6",
                pal.tertiary || "#9fd8cb", "#fff8ee"]
    }
    readonly property var fruitColors: ["#c9333f", "#e8543f", "#d93a52", "#f2a04b"]

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
        entrance.stop()
        entered = false
        resetCandles()
        view.opacity = 0
        cakeRoot.scale = Qt.vector3d(0.92, 0.92, 0.92)
        cakeRoot.position = Qt.vector3d(0, -6, 0)
        root.dragYaw = 0
        root.dragVel = 0
        root.windTilt = 0
        root.jellyX = 0
        root.jellyV = 0
        jellyAnim.running = false
        spinAnim.running = false
    }

    function wrapYaw(y) {
        var w = y
        while (w > 180)
            w -= 360
        while (w <= -180)
            w += 360
        return w
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
        // V1.1.0 fix #3c: velocity impulse into the damped oscillator. A
        // plain SequentialAnimation.start() is a no-op while running, which
        // is why taps during the wobble used to be swallowed.
        if (entrance.running) {
            entrance.stop()
            view.opacity = 1
            cakeRoot.position = Qt.vector3d(0, 0, 0)
            cakeRoot.scale = Qt.vector3d(1, 1, 1)
            root.jellyX = 0
        }
        root.jellyV = Math.min(8, root.jellyV + 2.0)
        jellyAnim.running = true
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
        camera: cam
        opacity: 0

        // Offscreen: the 3D scene renders into its own FBO and is composited
        // as a regular texture. The default Underlay pass cannot follow the
        // ancestor transforms of the editor preview stage (PreviewStage scales
        // the whole 1920x1080 ShowStage), which mis-composited the cake into
        // a sliver at the bottom of the preview. (V1.1.0 fix #1)
        renderMode: View3D.Offscreen

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
                // V1.1.1: vertical drag is disabled — the camera pitch stays at
                // the configured value, only the horizontal spin remains.
                eulerRotation.x: -(root.camCfg.pitch || 26)
                fieldOfViewOrientation: PerspectiveCamera.Vertical
                fieldOfView: 44
                clipNear: 10
                clipFar: 4000
            }

            // The lights live under the yawing rig so they turn with the
            // camera. Dragging orbits the view; a world-fixed key light made
            // the lit side jump to the other edge of the cake on every spin.
            // Keeping the rig camera-relative gives a stable studio light.
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
                // local y compensates the rig's +170 so the candle glow sits
                // at the same world height as before (topY + 150).
                position: Qt.vector3d(0, root.topY - 20, 140)
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
        }

        Node {
            id: cakeRoot
            scale: Qt.vector3d(0.92, 0.92, 0.92)
            position: Qt.vector3d(0, -6, 0)

            // Soft contact shadow so the stand sits on the stage instead of
            // floating in the dark.
            Model {
                source: "#Rectangle"
                eulerRotation.x: -90
                position: Qt.vector3d(0, 0.6, 0)
                scale: Qt.vector3d(7.2, 4.2, 1)
                castsShadows: false
                materials: PrincipledMaterial {
                    baseColor: "#ffffff"
                    baseColorMap: Texture { source: showBridge.textureUrl("shadow.png") }
                    lighting: PrincipledMaterial.NoLighting
                    alphaMode: PrincipledMaterial.Blend
                    opacity: 0.9
                }
            }

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

                    // piping drips — alternating lengths read as a drip cake
                    Repeater3D {
                        model: root.decorPiping ? (root.reducedMotion ? 12 : 20) : 0
                        delegate: Model {
                            source: "#Sphere"
                            position: {
                                var a = index / 20 * Math.PI * 2
                                return Qt.vector3d(
                                    Math.cos(a) * layerNode.radius * 1.005,
                                    layerNode.topAt - 9 - (index % 4) * 4,
                                    Math.sin(a) * layerNode.radius * 1.005)
                            }
                            scale: {
                                var w = 0.062 + (index % 3) * 0.006
                                var h = 0.16 + (index % 4) * 0.022
                                return Qt.vector3d(w, h, w)
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

            // cream rosettes around the top rim — the tier no longer reads as
            // a bare disc between the sprinkles and the candles
            Repeater3D {
                model: root.decorPiping ? (root.reducedMotion ? 6 : 9) : 0
                delegate: Node {
                    property real a: index / (root.reducedMotion ? 6 : 9) * Math.PI * 2 + 0.18
                    position: Qt.vector3d(Math.cos(a) * root.topRadius * 0.78,
                                          root.topY + 1,
                                          Math.sin(a) * root.topRadius * 0.78)

                    Model {
                        source: "#Sphere"
                        position: Qt.vector3d(0, 3.0, 0)
                        scale: Qt.vector3d(0.112, 0.068, 0.112)
                        castsShadows: false
                        materials: PrincipledMaterial {
                            baseColor: root.rosetteColor
                            roughness: 0.46
                        }
                    }
                    Model {
                        source: "#Sphere"
                        position: Qt.vector3d(0.012, 6.6, 0.008)
                        scale: Qt.vector3d(0.078, 0.055, 0.078)
                        castsShadows: false
                        materials: PrincipledMaterial {
                            baseColor: root.rosetteColor
                            roughness: 0.46
                        }
                    }
                    Model {
                        source: "#Sphere"
                        position: Qt.vector3d(0.020, 9.4, 0.012)
                        scale: Qt.vector3d(0.040, 0.040, 0.040)
                        castsShadows: false
                        materials: PrincipledMaterial {
                            baseColor: root.rosetteColor
                            roughness: 0.46
                        }
                    }
                    // a berry on every third swirl
                    Model {
                        visible: index % 3 === 0
                        source: "#Sphere"
                        position: Qt.vector3d(0.022, 11.6, 0.012)
                        scale: Qt.vector3d(0.040, 0.040, 0.040)
                        castsShadows: false
                        materials: PrincipledMaterial {
                            baseColor: "#c9333f"
                            roughness: 0.24
                        }
                    }
                }
            }

            // satin ribbon around the bottom tier + a bow at the front
            Node {
                id: ribbonNode
                visible: root.layerCount > 0 && root.decorPiping
                property real r0: root.layerCount > 0 ? (root.layers[0].radius || 200) : 200
                property real h0: root.layerCount > 0 ? (root.layers[0].height || 92) : 92
                property real bandY: root.plateTop + h0 * 0.34

                Model {
                    source: "#Cylinder"
                    position: Qt.vector3d(0, ribbonNode.bandY, 0)
                    scale: Qt.vector3d(ribbonNode.r0 / 50 * 1.012, 0.14, ribbonNode.r0 / 50 * 1.012)
                    castsShadows: false
                    materials: PrincipledMaterial {
                        baseColor: root.ribbonColor
                        roughness: 0.38
                        metalness: 0.04
                    }
                }
                // bow loops
                Repeater3D {
                    model: 2
                    delegate: Model {
                        source: "#Sphere"
                        position: Qt.vector3d(index === 0 ? -0.15 : 0.15,
                                              ribbonNode.bandY,
                                              ribbonNode.r0 * 1.008)
                        eulerRotation.z: index === 0 ? 24 : -24
                        scale: Qt.vector3d(0.17, 0.10, 0.055)
                        castsShadows: false
                        materials: PrincipledMaterial {
                            baseColor: root.ribbonColor
                            roughness: 0.34
                        }
                    }
                }
                Model {
                    source: "#Sphere"
                    position: Qt.vector3d(0, ribbonNode.bandY, ribbonNode.r0 * 1.012)
                    scale: Qt.vector3d(0.065, 0.065, 0.05)
                    castsShadows: false
                    materials: PrincipledMaterial {
                        baseColor: Qt.darker(root.ribbonColor, 1.12)
                        roughness: 0.34
                    }
                }
                // bow tails
                Repeater3D {
                    model: 2
                    delegate: Model {
                        source: "#Cube"
                        position: Qt.vector3d(index === 0 ? -0.07 : 0.07,
                                              ribbonNode.bandY - 0.18,
                                              ribbonNode.r0 * 1.004)
                        eulerRotation.z: index === 0 ? 10 : -10
                        scale: Qt.vector3d(0.045, 0.30, 0.014)
                        castsShadows: false
                        materials: PrincipledMaterial {
                            baseColor: Qt.darker(root.ribbonColor, 1.06)
                            roughness: 0.40
                        }
                    }
                }
            }

            // pearl border where the bottom tier meets the plate
            Repeater3D {
                model: root.decorPiping ? (root.reducedMotion ? 18 : 30) : 0
                delegate: Model {
                    source: "#Sphere"
                    property real a: index / (root.reducedMotion ? 18 : 30) * Math.PI * 2
                    property real r0: root.layerCount > 0 ? (root.layers[0].radius || 200) : 200
                    position: Qt.vector3d(Math.cos(a) * r0 * 1.004,
                                          root.plateTop + 4.5,
                                          Math.sin(a) * r0 * 1.004)
                    scale: Qt.vector3d(0.055, 0.040, 0.055)
                    castsShadows: false
                    materials: PrincipledMaterial {
                        baseColor: root.topFrosting
                        roughness: 0.42
                    }
                }
            }

            // spilled sprinkles on the plate
            Repeater3D {
                model: root.decorSprinkles ? (root.reducedMotion ? 8 : 16) : 0
                delegate: Model {
                    source: "#Cube"
                    property real a: (index * 2.399963) % (Math.PI * 2)
                    property real r0: root.layerCount > 0 ? (root.layers[0].radius || 200) : 200
                    position: Qt.vector3d(Math.cos(a) * r0 * (1.10 + (index % 3) * 0.035),
                                          root.plateTop - 1.2,
                                          Math.sin(a) * r0 * (1.10 + (index % 3) * 0.035))
                    scale: Qt.vector3d(0.05, 0.014, 0.018)
                    eulerRotation.y: index * 47
                    castsShadows: false
                    materials: PrincipledMaterial {
                        baseColor: root.sprinkleColors[index % root.sprinkleColors.length]
                        roughness: 0.6
                    }
                }
            }

            // fruit on top: glossy cherries with stems and leaves
            Repeater3D {
                model: root.decorFruit ? 7 : 0
                delegate: Node {
                    property real a: index / 7 * Math.PI * 2 + 0.35
                    position: Qt.vector3d(Math.cos(a) * root.topRadius * 0.62,
                                          root.topY + 8,
                                          Math.sin(a) * root.topRadius * 0.62)

                    Model {
                        source: "#Sphere"
                        scale: Qt.vector3d(0.135, 0.135, 0.135)
                        castsShadows: false
                        materials: PrincipledMaterial {
                            baseColor: root.fruitColors[index % root.fruitColors.length]
                            roughness: 0.22
                            metalness: 0.02
                        }
                    }
                    Model {
                        source: "#Cylinder"
                        position: Qt.vector3d(0.012, 10.5, 0.008)
                        eulerRotation.z: 12
                        scale: Qt.vector3d(0.009, 0.13, 0.009)
                        castsShadows: false
                        materials: PrincipledMaterial {
                            baseColor: "#4a6b3a"
                            roughness: 0.7
                        }
                    }
                    Model {
                        visible: index % 2 === 0
                        source: "#Sphere"
                        position: Qt.vector3d(0.045, 12.0, 0.012)
                        eulerRotation.z: 28
                        scale: Qt.vector3d(0.055, 0.016, 0.032)
                        castsShadows: false
                        materials: PrincipledMaterial {
                            baseColor: "#6f9a54"
                            roughness: 0.6
                        }
                    }
                }
            }

            // sprinkles
            Repeater3D {
                model: root.decorSprinkles ? (root.reducedMotion ? 24 : 56) : 0
                delegate: Model {
                    source: "#Cube"
                    property real a: (index * 2.399963) % (Math.PI * 2)
                    property real r: root.topRadius * (0.2 + ((index * 37) % 100) / 140)
                    position: Qt.vector3d(Math.cos(a) * r, root.topY + 3, Math.sin(a) * r)
                    scale: Qt.vector3d(0.05, 0.015, 0.015)
                    eulerRotation.y: index * 41
                    castsShadows: false
                    materials: PrincipledMaterial {
                        baseColor: root.sprinkleColors[index % root.sprinkleColors.length]
                        roughness: 0.6
                    }
                }
            }

            // plaque on the front of the top tier
            Node {
                visible: root.decorPlaque
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

                    // cream candle holder grounds the stick on the frosting
                    Model {
                        source: "#Cylinder"
                        position: Qt.vector3d(candleNode.pt.x, root.topY + 1.4, candleNode.pt.z)
                        scale: Qt.vector3d(candleNode.cr * 2.3 / 50, 0.028, candleNode.cr * 2.3 / 50)
                        castsShadows: false
                        materials: PrincipledMaterial {
                            baseColor: root.topFrosting
                            roughness: 0.42
                        }
                    }

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
                        // Billboard compensation must include the user drag
                        // yaw now that the cake spins freely (V1.1.0 fix #3a).
                        eulerRotation.y: -((root.camCfg.yaw || -16) + root.dragYaw)

                        Node {
                            id: flameScale
                            SequentialAnimation on scale {
                                running: !root.reducedMotion && !candleNode.isOut
                                loops: Animation.Infinite
                                Vector3dAnimation { from: Qt.vector3d(1, 1, 1); to: Qt.vector3d(1.05, 1.12, 1.05); duration: 260 + index * 30; easing.type: Easing.InOutSine }
                                Vector3dAnimation { from: Qt.vector3d(1.05, 1.12, 1.05); to: Qt.vector3d(0.98, 0.94, 0.98); duration: 210 + index * 25; easing.type: Easing.InOutSine }
                                Vector3dAnimation { from: Qt.vector3d(0.98, 0.94, 0.98); to: Qt.vector3d(1, 1, 1); duration: 190; easing.type: Easing.InOutSine }
                            }
                            // Lean comes from the bounded `windTilt`, not the
                            // raw drag yaw — an unbounded yaw flipped flames
                            // over once rotation was freed.
                            SequentialAnimation on eulerRotation {
                                running: !root.reducedMotion && !candleNode.isOut
                                loops: Animation.Infinite
                                Vector3dAnimation { from: Qt.vector3d(0, 0, -3 - root.windTilt); to: Qt.vector3d(0, 0, 3 + root.windTilt); duration: 900 + index * 70; easing.type: Easing.InOutSine }
                                Vector3dAnimation { from: Qt.vector3d(0, 0, 3 + root.windTilt); to: Qt.vector3d(0, 0, -3 - root.windTilt); duration: 1000 + index * 60; easing.type: Easing.InOutSine }
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
                        eulerRotation.y: -((root.camCfg.yaw || -16) + root.dragYaw)
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

        // drag to spin the cake horizontally (V1.1.1: vertical drag removed —
        // the cake no longer tilts up/down). The yaw sign is flipped
        // so the front of the cake follows the finger, rotation accumulates
        // freely (wrapped to ±180°) and never springs back to centre; the
        // release keeps the flick momentum and decays with friction.
        DragHandler {
            id: drag
            target: null
            onActiveChanged: {
                if (active) {
                    root.dragStartYaw = root.dragYaw
                    root.dragVel = 0
                    root.lastDragYaw = root.dragYaw
                    root.lastDragT = Date.now()
                    spinAnim.running = false
                } else {
                    // If the pointer sat still before release, the last
                    // estimated velocity is stale — do not fling (S2 acc #1).
                    if (Date.now() - root.lastDragT > 120)
                        root.dragVel = 0
                    spinAnim.running = Math.abs(root.dragVel) > 2
                }
            }
            onTranslationChanged: {
                if (!active)
                    return
                root.dragYaw = root.wrapYaw(root.dragStartYaw - translation.x * 0.22)
                var now = Date.now()
                var dt = (now - root.lastDragT) / 1000
                if (dt > 0.012) {
                    var dyaw = root.dragYaw - root.lastDragYaw
                    if (dyaw > 180)
                        dyaw -= 360
                    if (dyaw < -180)
                        dyaw += 360
                    root.dragVel = dyaw / dt
                    root.lastDragYaw = root.dragYaw
                    root.lastDragT = now
                }
            }
        }

        TapHandler {
            id: tap
            onTapped: function (eventPoint, button) {
                var p = view.mapFromItem(null, eventPoint.scenePosition.x, eventPoint.scenePosition.y)
                // Nearest-candle match first (F-22 / targets.min ≥24px): the
                // bare sticks are ~14px on screen and rays aimed at a flame
                // hit the cake body behind it, so a pure 3D pick feels dead.
                var best = -1
                var bestDist = 48
                for (var i = 0; i < root.candleCount; i++) {
                    if (root.outFlags.length > i && root.outFlags[i])
                        continue
                    var cp = root.candlePoint(i)
                    var sp = view.mapFrom3DScene(Qt.vector3d(cp.x, root.topY + (root.candleCfg.height || 54), cp.z))
                    var d = Math.sqrt((sp.x - p.x) * (sp.x - p.x) + (sp.y - p.y) * (sp.y - p.y))
                    if (d < bestDist) {
                        bestDist = d
                        best = i
                    }
                }
                if (best >= 0) {
                    root.blowOut(best)
                    return
                }
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

    // V1.1.0 fix #3c: the jelly wobble as a damped oscillator integrated per
    // frame. Taps inject velocity (see jelly()), so tapping again mid-wobble
    // stacks instead of being ignored. Volume-preserving squash & stretch.
    FrameAnimation {
        id: jellyAnim
        running: false
        // This Qt build exposes FrameAnimation via currentFrame/frameTime
        // properties (no frameDelta signal): currentFrame ticks once per
        // rendered frame, frameTime is the per-frame delta in seconds.
        onCurrentFrameChanged: {
            var step = Math.min(frameTime, 1 / 30)   // frameTime is in seconds on this Qt build
            root.jellyV += (-root.jellyK * root.jellyX - root.jellyC * root.jellyV) * step
            root.jellyX = Math.max(-0.32, Math.min(0.32, root.jellyX + root.jellyV * step))
            cakeRoot.scale = Qt.vector3d(1 + root.jellyX * 0.6, 1 - root.jellyX, 1 + root.jellyX * 0.6)
            if (Math.abs(root.jellyX) < 0.008 && Math.abs(root.jellyV) < 0.10) {
                root.jellyX = 0
                root.jellyV = 0
                cakeRoot.scale = Qt.vector3d(1, 1, 1)
                jellyAnim.running = false
            }
        }
    }

    // V1.1.0 fix #3b: post-drag flick inertia — friction decay, no return to
    // the starting angle. Also eases the flame `windTilt` back to rest.
    FrameAnimation {
        id: spinAnim
        running: false
        onCurrentFrameChanged: {
            var step = Math.min(frameTime, 1 / 30)   // frameTime is in seconds on this Qt build
            root.dragYaw = root.wrapYaw(root.dragYaw + root.dragVel * step)
            root.dragVel *= Math.exp(-2.6 * step)
            var tiltTarget = Math.max(-8, Math.min(8, root.dragVel / 40))
            root.windTilt += (tiltTarget - root.windTilt) * Math.min(1, step * 8)
            if (Math.abs(root.dragVel) < 2 && Math.abs(root.windTilt) < 0.1) {
                root.dragVel = 0
                root.windTilt = 0
                spinAnim.running = false
            }
        }
    }

    // Keep the flame lean tracking the drag while the pointer is down.
    onDragYawChanged: {
        if (drag.active) {
            var tiltTarget = Math.max(-8, Math.min(8, root.dragVel / 40))
            root.windTilt += (tiltTarget - root.windTilt) * 0.25
        }
    }
}
