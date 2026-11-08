import QtQuick
import "../components"
import "../show"

Item {
    id: root

    property bool hasProfile: false
    property string selectedAct: "intro"
    property bool running: false
    property string playingAct: ""
    property bool lowMotion: false
    property bool highContrast: false
    property bool slowmo: false
    property bool muted: false
    property bool audit: false
    property string resolution: "1080p"
    property int zoom: 100
    signal newRequested()
    signal importRequested()
    signal toast(string message)

    readonly property var ui: (theme.tokens && theme.tokens.ui) ? theme.tokens.ui : ({})
    readonly property color ink: ui.text || "#f5ede8"
    readonly property color mutedColor: ui.textMuted || "#b9a9b6"
    readonly property color accent: ui.accent || "#ffb08a"
    readonly property color borderColor: ui.panelBorder || "#ffffff14"
    readonly property int logicalWidth: resolution === "4K" ? 3840 : (resolution === "1440p" ? 2560 : 1920)
    readonly property int logicalHeight: Math.round(logicalWidth * 9 / 16)
    readonly property var profileData: session.preview

    function actLabel(id) {
        var m = { "intro": "开场", "wax": "火漆", "popups": "祝福", "confirm": "收下", "dissolve": "揭幕", "cake": "蛋糕", "finale": "终幕", "global": "开场" }
        return m[id] || "开场"
    }

    function startAll() {
        start("")
    }
    function startAct() {
        start(root.selectedAct)
    }
    function start(act) {
        if (!hasProfile)
            return
        // Assets/BGM resolve against the profile dir — sync it before the
        // show starts, otherwise the first act may look up the previous dir.
        showBridge.setProfileDir(session.profileDir)
        showBridge.setPluginIds(session.draft.plugins || [])
        root.running = true
        stage.start(act || "")
    }
    function stop() {
        stage.stop()
        root.running = false
        root.playingAct = ""
    }
    function skip() {
        stage.skipCurrent()
    }

    onMutedChanged: audioBridge.setMuted(muted)

    // toolbar
    Item {
        id: toolbar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 44

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            EdButton {
                text: "▶ 从头"
                small: true
                enabled: root.hasProfile
                primary: !root.running
                onClicked: root.startAll()
            }
            EdButton {
                text: "▶ 当前幕"
                small: true
                enabled: root.hasProfile
                onClicked: root.startAct()
            }
            EdButton {
                text: "■"
                small: true
                width: 36
                enabled: root.running
                onClicked: root.stop()
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: 6
                text: root.running ? ("正在演出 · " + (stage.currentLabel || "")) : "预览已停止"
                color: root.mutedColor
                font.family: theme.hanFamily
                font.pixelSize: 11
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            EdCombo {
                width: 92
                value: root.resolution
                options: [
                    { value: "1080p", label: "1080p" },
                    { value: "1440p", label: "1440p" },
                    { value: "4K", label: "4K" }
                ]
                onPicked: function (v) { root.resolution = v }
            }
            EdCombo {
                width: 78
                value: String(root.zoom)
                options: [
                    { value: "50", label: "50%" },
                    { value: "75", label: "75%" },
                    { value: "100", label: "100%" },
                    { value: "125", label: "125%" },
                    { value: "150", label: "150%" },
                    { value: "200", label: "200%" }
                ]
                onPicked: function (v) { root.zoom = parseInt(v) || 100 }
            }
            EdButton { text: "低动效"; small: true; checkable: true; checked: root.lowMotion; onClicked: root.lowMotion = !root.lowMotion }
            EdButton { text: "高对比"; small: true; checkable: true; checked: root.highContrast; onClicked: root.highContrast = !root.highContrast }
            EdButton { text: "0.5×"; small: true; checkable: true; checked: root.slowmo; onClicked: root.slowmo = !root.slowmo }
            EdButton { text: "静音"; small: true; checkable: true; checked: root.muted; onClicked: root.muted = !root.muted }
            EdButton { text: "审计"; small: true; checkable: true; checked: root.audit; onClicked: root.audit = !root.audit }
        }
    }

    // stage frame
    Item {
        id: stageArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: toolbar.bottom
        anchors.bottom: parent.bottom
        anchors.margins: 0

        Rectangle {
            id: frame
            anchors.centerIn: parent
            width: Math.min(parent.width - 28, (parent.height - 20) * 16 / 9)
            height: width * 9 / 16
            radius: 14
            color: "#0a0610"
            border.width: 1
            border.color: root.borderColor
            clip: true

            Item {
                id: viewport
                anchors.fill: parent
                clip: true

                Item {
                    id: logical
                    width: root.logicalWidth
                    height: root.logicalHeight
                    anchors.centerIn: parent
                    // Clamp the zoom factor so no persisted/invalid value can
                    // ever collapse the whole stage into an invisible speck.
                    scale: (viewport.width / width) * Math.max(0.5, Math.min(2.0, root.zoom / 100))
                    transformOrigin: Item.Center

                    ShowStage {
                        id: stage
                        anchors.fill: parent
                        profile: root.profileData
                        tokens: theme.tokens
                        previewMode: true
                        forceReducedMotion: root.lowMotion
                        forceHighContrast: root.highContrast
                        speedScale: root.slowmo ? 0.5 : 1.0
                        autoStart: false
                        onActChanged: function (actId) { root.playingAct = actId }
                        onFinished: { root.running = false }
                        onCloseRequested: root.stop()
                        onToast: function (message) { root.toast.emit(message) }
                    }

                    // poster when stopped
                    Item {
                        id: poster
                        anchors.fill: parent
                        visible: !root.running

                        BackgroundStage {
                            anchors.fill: parent
                            tokens: theme.tokens
                            variant: "paper"
                            reducedMotion: true
                            highContrast: root.highContrast
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: Math.min(parent.width * 0.66, 1180)
                            height: Math.min(parent.height * 0.54, 560)
                            radius: 30
                            color: Qt.rgba(0, 0, 0, 0.25)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.18)

                            Column {
                                anchors.centerIn: parent
                                spacing: 16
                                width: parent.width * 0.84

                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 6
                                    Repeater {
                                        model: theme.palette && theme.palette.primary ? ["primary", "secondary", "tertiary"] : []
                                        Rectangle {
                                            width: 9
                                            height: 9
                                            radius: 4.5
                                            color: theme.palette[modelData] || "#888"
                                            opacity: 0.9
                                        }
                                    }
                                    Text {
                                        text: (theme.tokens.theme ? theme.tokens.theme.name : "") + " · 七幕仪式"
                                        color: "#ffd9b8"
                                        font.family: theme.hanFamily
                                        font.pixelSize: 17
                                        font.letterSpacing: 2
                                    }
                                }

                                Text {
                                    width: parent.width
                                    text: root.hasProfile && session.draft.meta ? session.draft.meta.name : "尚未打开配置档"
                                    color: "#fff8ee"
                                    font.family: theme.serifFamily
                                    font.pixelSize: Math.min(88, width * 0.082)
                                    font.weight: Font.DemiBold
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text: root.hasProfile && session.draft.meta ? ("致 " + session.draft.meta.honoree + " · 一封会自己展开的祝福") : "新建或打开一个配置档开始"
                                    color: "#ffe9df"
                                    opacity: 0.8
                                    font.family: theme.hanFamily
                                    font.pixelSize: 24
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 10
                                    Repeater {
                                        model: ["开场", "火漆", "祝福", "收下", "揭幕", "蛋糕", "终幕"]
                                        Row {
                                            spacing: 5
                                            Rectangle {
                                                width: 6; height: 6; radius: 3
                                                anchors.verticalCenter: parent.verticalCenter
                                                color: index <= 6 ? ((theme.palette && theme.palette.primary) || "#ffb08a") : "#666"
                                                opacity: index < 7 ? 0.9 : 0.4
                                            }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: modelData
                                                color: "#ffe9df"
                                                opacity: 0.62
                                                font.family: theme.hanFamily
                                                font.pixelSize: 15
                                            }
                                        }
                                    }
                                }

                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 18
                                    EdButton {
                                        text: "▶ 试演整场"
                                        primary: true
                                        large: true
                                        onClicked: root.startAll()
                                    }
                                    EdButton {
                                        text: "从「" + root.actLabel(root.selectedAct) + "」开始"
                                        large: true
                                        onClicked: root.startAct()
                                    }
                                }
                            }
                        }
                    }

                    AudioBar {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.rightMargin: 16
                        anchors.topMargin: 14
                        tokens: theme.tokens
                        compact: true
                        z: 50
                    }

                    SkipButton {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.rightMargin: 18
                        anchors.bottomMargin: 16
                        tokens: theme.tokens
                        visibleHint: root.running && stage.canSkip && (session.draft.global && session.draft.global.skip ? session.draft.global.skip.show_button !== false : true)
                        onClicked: root.skip()
                        z: 50
                    }

                    // audit overlay
                    Rectangle {
                        visible: root.audit
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 14
                        anchors.bottomMargin: 14
                        width: Math.min(parent.width * 0.42, 520)
                        height: auditColumn.height + 20
                        radius: 12
                        color: Qt.rgba(0.05, 0.03, 0.08, 0.86)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.16)
                        z: 60

                        Column {
                            id: auditColumn
                            x: 12
                            y: 10
                            width: parent.width - 24
                            spacing: 5
                            Text {
                                text: "设计审计 · " + session.errorCount + " 错误 / " + session.warningCount + " 警告"
                                color: session.errorCount > 0 ? "#ff8a80" : "#7ee0d0"
                                font.family: theme.hanFamily
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }
                            Repeater {
                                model: Math.min(3, session.issues.length)
                                Text {
                                    width: parent.width
                                    text: (session.issues[index].severity === "error" ? "✕ " : "⚠ ") + session.issues[index].message
                                    color: session.issues[index].severity === "error" ? "#ffb3ac" : "#ffe0a3"
                                    font.family: theme.hanFamily
                                    font.pixelSize: 10
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                    opacity: 0.9
                                }
                            }
                            Text {
                                visible: session.issues.length === 0
                                text: "两套出厂主题零错误零警告"
                                color: "#7ee0d0"
                                font.family: theme.hanFamily
                                font.pixelSize: 10
                                opacity: 0.8
                            }
                        }
                    }
                }

                // welcome (no profile)
                Rectangle {
                    anchors.fill: parent
                    color: "#0f0a16"
                    visible: !root.hasProfile

                    Column {
                        anchors.centerIn: parent
                        spacing: 16
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "把祝福做成一场仪式"
                            color: "#fff5ee"
                            font.family: theme.serifFamily
                            font.pixelSize: 30
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "七幕演出 · 实时预览 · 一键导出独立播放器"
                            color: "#b9a9b6"
                            font.family: theme.hanFamily
                            font.pixelSize: 13
                        }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 10
                            EdButton { text: "新建配置档"; primary: true; onClicked: root.newRequested() }
                            EdButton { text: "导入 .bbp"; onClicked: root.importRequested() }
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: session
        function onPreviewChanged() {
            showBridge.setProfileDir(session.profileDir)
            showBridge.setPluginIds(session.draft.plugins || [])
        }
        function onOpened() {
            showBridge.setProfileDir(session.profileDir)
            showBridge.setPluginIds(session.draft.plugins || [])
        }
    }
}
