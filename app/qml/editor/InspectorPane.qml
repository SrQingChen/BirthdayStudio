import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import "../components"

Item {
    id: root

    property string selectedAct: "intro"
    property string tab: "form"
    property int selectedCard: 0
    property int selectedLayer: 0
    property bool applyThemeStyling: false
    property string jsonText: ""
    property string jsonError: ""
    signal toast(string message)
    signal playFrom(string actId)
    signal actSelected(string id)
    signal drawTrajectory()

    readonly property var ui: (theme.tokens && theme.tokens.ui) ? theme.tokens.ui : ({})
    readonly property color ink: ui.text || "#f5ede8"
    readonly property color muted: ui.textMuted || "#b9a9b6"
    readonly property color accent: ui.accent || "#ffb08a"
    readonly property color borderColor: ui.panelBorder || "#ffffff14"
    readonly property color dangerColor: ui.danger || "#ff8a80"
    readonly property var draft: session.draft
    readonly property var actsCfg: (draft && draft.acts) ? draft.acts : ({})
    readonly property var stageCfg: (draft && draft.global && draft.global.stage) ? draft.global.stage : ({})
    readonly property var popupsCfg: actsCfg.popups || ({})
    readonly property var cards: popupsCfg.cards || []
    readonly property var cakeCfg: (actsCfg.cake && actsCfg.cake.cake) ? actsCfg.cake.cake : ({})
    readonly property var layers: cakeCfg.layers || []
    readonly property int cardsCount: cards.length
    readonly property int layersCount: layers.length
    readonly property var colorStrategy: popupsCfg.color_strategy || ({})
    readonly property var paletteList: colorStrategy.palette || []
    readonly property string colorMode: colorStrategy.mode || "harmony"

    // "0" keeps every configured card; 1..N plays only the visible prefix.
    readonly property var cardLimitOptions: {
        var out = [{ value: "0", label: "全部（" + root.cardsCount + " 只）" }]
        for (var i = 1; i <= root.cardsCount; i++)
            out.push({ value: String(i), label: "前 " + i + " 只" })
        return out
    }

    readonly property var actOptions: [
        { id: "global", label: "全局" },
        { id: "intro", label: "开场" },
        { id: "wax", label: "火漆" },
        { id: "popups", label: "祝福" },
        { id: "confirm", label: "收下" },
        { id: "dissolve", label: "揭幕" },
        { id: "cake", label: "蛋糕" },
        { id: "finale", label: "终幕" }
    ]

    readonly property var themeOptions: {
        var out = []
        var th = library.themes || []
        for (var i = 0; i < th.length; i++)
            out.push({ value: th[i].id, label: th[i].name })
        return out
    }

    readonly property var formComponent: {
        switch (selectedAct) {
        case "global": return globalComp
        case "intro": return introComp
        case "wax": return waxComp
        case "popups": return popupsComp
        case "confirm": return confirmComp
        case "dissolve": return dissolveComp
        case "cake": return cakeComp
        case "finale": return finaleComp
        default: return globalComp
        }
    }

    function actEnabled(id) {
        if (id === "global")
            return true
        var cfg = actsCfg[id]
        return !cfg || cfg.enabled !== false
    }

    function selectAct(id) {
        root.selectedAct = id
        root.jsonText = JSON.stringify(session.draft, null, 2)
        root.tab = "form"
        root.actSelected(id)
    }

    function cardsCountSafe() {
        return cards.length
    }

    function hasDecoration(name) {
        var d = (cakeCfg.decorations || [])
        return d.indexOf(name) >= 0
    }

    function toggleDecoration(name, on) {
        var d = (cakeCfg.decorations || []).slice()
        var idx = d.indexOf(name)
        if (on && idx < 0)
            d.push(name)
        if (!on && idx >= 0)
            d.splice(idx, 1)
        session.setField("acts.cake.cake.decorations", d)
    }

    function setPaletteColor(index, value) {
        var arr = (root.paletteList || []).slice()
        // Clearing a colour removes that palette entry; an empty string in
        // the array would be an invalid QML colour at show time.
        if (value === "")
            arr.splice(index, 1)
        else
            arr[index] = value
        session.setField("acts.popups.color_strategy.palette", arr)
    }

    function addPaletteColor() {
        var arr = (root.paletteList || []).slice()
        arr.push("#ffb08a")
        session.setField("acts.popups.color_strategy.palette", arr)
    }

    function removePaletteColor(index) {
        var arr = (root.paletteList || []).slice()
        arr.splice(index, 1)
        session.setField("acts.popups.color_strategy.palette", arr)
    }

    function refreshJson() {
        root.jsonText = JSON.stringify(session.draft, null, 2)
        root.jsonError = ""
    }

    width: parent ? parent.width : 340

    // tabs
    Item {
        id: tabs
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 40
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Repeater {
                model: [
                    { id: "form", label: "属性" },
                    { id: "json", label: "JSON" },
                    { id: "issues", label: "校验" }
                ]
                Item {
                    id: tabSlot
                    width: tabButton.width + 6
                    height: tabs.height
                    readonly property bool active: root.tab === modelData.id

                    EdButton {
                        id: tabButton
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 5
                        text: modelData.label
                        small: true
                        checked: tabSlot.active
                        onClicked: {
                            root.tab = modelData.id
                            if (modelData.id === "json")
                                root.refreshJson()
                        }
                    }

                    // Sliding underline: a clear, animated response instead of
                    // the old near-invisible 8% white fill.
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        width: tabSlot.active ? tabButton.width - 18 : 0
                        height: 2
                        radius: 1
                        color: root.accent
                        opacity: tabSlot.active ? 1 : 0
                        Behavior on width { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }
                }
            }
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Text {
                text: session.errorCount > 0 ? (session.errorCount + " 错误") : (session.warningCount > 0 ? (session.warningCount + " 警告") : "校验通过")
                color: session.errorCount > 0 ? root.dangerColor : (session.warningCount > 0 ? "#ffd166" : "#7ee0d0")
                font.family: theme.hanFamily
                font.pixelSize: 10
            }
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: root.borderColor }
    }

    // act chips
    Flow {
        id: chips
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: tabs.bottom
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 8
        spacing: 4
        visible: root.tab === "form" || opacity > 0.01
        enabled: root.tab === "form"
        opacity: root.tab === "form" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }
        Repeater {
            model: root.actOptions
            EdButton {
                text: modelData.label
                small: true
                checked: root.selectedAct === modelData.id
                opacity: root.actEnabled(modelData.id) ? 1.0 : 0.45
                onClicked: root.selectAct(modelData.id)
            }
        }
    }

    // form content
    ScrollView {
        id: scroll
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: chips.visible ? chips.bottom : tabs.bottom
        anchors.bottom: parent.bottom
        anchors.topMargin: 8
        clip: true
        visible: root.tab === "form" || opacity > 0.01
        enabled: root.tab === "form"
        opacity: root.tab === "form" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 130; easing.type: Easing.OutQuad } }
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        Column {
            width: scroll.availableWidth - 28
            x: 14
            y: 4
            spacing: 12
            Loader {
                width: parent.width
                sourceComponent: root.formComponent
            }
            Item { width: 1; height: 18 }
        }
    }

    // JSON tab
    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: tabs.bottom
        anchors.bottom: parent.bottom
        visible: root.tab === "json" || opacity > 0.01
        enabled: root.tab === "json"
        opacity: root.tab === "json" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 130; easing.type: Easing.OutQuad } }

        Row {
            id: jsonActions
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 8
            EdButton {
                text: "应用 JSON"
                small: true
                primary: true
                onClicked: {
                    if (session.replaceDraft(root.jsonText)) {
                        root.jsonError = ""
                        root.refreshJson()
                    } else {
                        root.jsonError = "应用失败：请检查 JSON 与字段类型"
                    }
                }
            }
            EdButton { text: "重新载入"; small: true; onClicked: root.refreshJson() }
            EdButton { text: "格式化"; small: true; onClicked: { try { root.jsonText = JSON.stringify(JSON.parse(root.jsonText), null, 2); root.jsonError = "" } catch (e) { root.jsonError = String(e) } } }
        }

        Text {
            id: jsonErrorText
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: jsonActions.bottom
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            anchors.topMargin: 4
            text: root.jsonError
            visible: text !== ""
            color: root.dangerColor
            font.family: theme.hanFamily
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: jsonActions.bottom
            anchors.topMargin: root.jsonError !== "" ? 28 : 10
            anchors.bottom: parent.bottom
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            anchors.bottomMargin: 12
            radius: 10
            color: Qt.rgba(0, 0, 0, 0.18)
            border.width: 1
            border.color: root.borderColor

            ScrollView {
                anchors.fill: parent
                anchors.margins: 8
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AsNeeded
                TextArea {
                    id: jsonArea
                    text: root.jsonText
                    color: root.ink
                    font.family: "Consolas"
                    font.pixelSize: 11
                    wrapMode: TextEdit.NoWrap
                    selectByMouse: true
                    onTextChanged: if (root.jsonText !== text) root.jsonText = text
                    background: null
                }
            }
        }
    }

    // validation tab
    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: tabs.bottom
        anchors.bottom: parent.bottom
        visible: root.tab === "issues" || opacity > 0.01
        enabled: root.tab === "issues"
        opacity: root.tab === "issues" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 130; easing.type: Easing.OutQuad } }

        ScrollView {
            anchors.fill: parent
            anchors.margins: 12
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            Column {
                width: parent.width
                spacing: 8

                Rectangle {
                    width: parent.width
                    height: 54
                    radius: 10
                    color: Qt.rgba(0, 0, 0, 0.14)
                    border.width: 1
                    border.color: session.canExport ? Qt.rgba(0.49, 0.88, 0.82, 0.4) : Qt.rgba(1, 0.54, 0.5, 0.4)
                    Column {
                        anchors.centerIn: parent
                        spacing: 3
                        Text {
                            text: session.canExport ? "可以导出" : "存在阻止导出的错误"
                            color: session.canExport ? "#7ee0d0" : root.dangerColor
                            font.family: theme.hanFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: session.errorCount + " 错误 · " + session.warningCount + " 警告 · 点击条目跳转"
                            color: root.muted
                            font.family: theme.hanFamily
                            font.pixelSize: 10
                        }
                    }
                }

                Repeater {
                    model: session.issues
                    Rectangle {
                        width: parent.width
                        height: issueColumn.height + 16
                        radius: 9
                        color: Qt.rgba(0, 0, 0, 0.12)
                        border.width: 1
                        border.color: modelData.severity === "error" ? Qt.rgba(1, 0.54, 0.5, 0.35) : Qt.rgba(1, 0.82, 0.4, 0.28)
                        Column {
                            id: issueColumn
                            x: 10
                            y: 8
                            width: parent.width - 20
                            spacing: 3
                            Text {
                                width: parent.width
                                text: (modelData.severity === "error" ? "✕ " : "⚠ ") + modelData.message
                                color: modelData.severity === "error" ? "#ffb3ac" : "#ffe0a3"
                                font.family: theme.hanFamily
                                font.pixelSize: 11
                                wrapMode: Text.Wrap
                            }
                            Text {
                                text: modelData.path
                                color: root.muted
                                opacity: 0.6
                                font.family: "Consolas"
                                font.pixelSize: 9
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var p = modelData.path || ""
                                if (p.indexOf("acts.") === 0) {
                                    var act = p.split(".")[1]
                                    if (act)
                                        root.selectAct(act)
                                } else {
                                    root.selectAct("global")
                                }
                            }
                        }
                    }
                }

                Item { width: 1; height: 8 }
                Text {
                    width: parent.width
                    text: "健康红线（编辑器强制）：闪烁 ≤3 次/秒且亮度变化 <10%；默认音量 ≤50%；文字对比 ≥4.5:1；一切可点目标 ≥24×24px。"
                    color: root.muted
                    font.family: theme.hanFamily
                    font.pixelSize: 10
                    wrapMode: Text.Wrap
                    opacity: 0.7
                }
            }
        }
    }

    // ------------------------------------------------------------------ //
    // Form components
    // ------------------------------------------------------------------ //
    Component {
        id: globalComp
        Column {
            width: parent.width
            spacing: 12

            Section {
                title: "配置档"
                subtitle: "作品身份"
                InspectorField { label: "显示名"; path: "meta.name"; type: "text" }
                InspectorField { label: "寿星"; path: "meta.honoree"; type: "text" }
                InspectorField { label: "作者"; path: "meta.author"; type: "text" }
                InspectorField { label: "描述"; path: "meta.description"; type: "textarea"; hint: "仅编辑器内可见" }
            }

            Section {
                title: "主题"
                subtitle: "令牌与出厂模板"
                EdCombo {
                    width: parent.width
                    value: (session.draft.meta && session.draft.meta.theme) ? session.draft.meta.theme : "glass-celebration"
                    options: root.themeOptions
                    onPicked: function (v) {
                        if (root.applyThemeStyling)
                            session.applyTheme(v, true)
                        else
                            session.setField("meta.theme", v)
                    }
                }
                Row {
                    width: parent.width
                    spacing: 8
                    EdSwitch {
                        checked: root.applyThemeStyling
                        onToggled: function (value) { root.applyThemeStyling = value }
                    }
                    Text {
                        text: "同时套用主题默认配色（会覆盖当前的蜡烛/蛋糕/信封颜色）"
                        color: root.muted
                        font.family: theme.hanFamily
                        font.pixelSize: 10
                        width: parent.width - 60
                        wrapMode: Text.Wrap
                    }
                }
                Row {
                    spacing: 6
                    Repeater {
                        model: (theme.palette && theme.palette.primary) ? ["primary", "secondary", "tertiary", "surface", "on-surface"] : []
                        Rectangle {
                            width: 24
                            height: 24
                            radius: 12
                            color: theme.palette[modelData] || "#888"
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.3)
                        }
                    }
                }
            }

            Section {
                title: "舞台与画面"
                subtitle: "画幅、背景与环境光"
                InspectorField {
                    label: "画幅"
                    path: "global.stage.aspect"
                    type: "combo"
                    options: [
                        { value: "16:9", label: "16:9" },
                        { value: "full", label: "铺满全屏" }
                    ]
                }
                InspectorField {
                    label: "背景来源"
                    path: "global.stage.background"
                    type: "combo"
                    options: [
                        { value: "theme", label: "跟随主题" },
                        { value: "custom", label: "自定义纯色" }
                    ]
                }
                InspectorField {
                    visible: (root.stageCfg.background || "theme") === "custom"
                    label: "背景色"
                    path: "global.stage.background_color"
                    type: "color"
                }
                InspectorField { label: "暗角"; path: "global.stage.vignette"; type: "switch" }
                InspectorField {
                    label: "环境模式"
                    path: "global.environment.mode"
                    type: "combo"
                    options: [
                        { value: "dark", label: "暗室" },
                        { value: "light", label: "明亮" },
                        { value: "auto", label: "自动" }
                    ]
                }
                InspectorField { label: "环境亮度"; path: "global.environment.ambient_brightness"; type: "slider"; min: 0.4; max: 1.2; step: 0.05 }
            }

            Section {
                title: "声音"
                subtitle: "背景音乐与音效"
                InspectorField { label: "主音量"; path: "global.audio.master_volume_pct"; type: "slider"; min: 0; max: 100; step: 1; unit: "%" }
                InspectorField { label: "BGM"; path: "global.audio.bgm.path"; type: "path"; assetKind: "audio" }
                InspectorField { label: "BGM 音量"; path: "global.audio.bgm.volume_pct"; type: "slider"; min: 0; max: 100; step: 1; unit: "%" }
                InspectorField { label: "循环"; path: "global.audio.bgm.loop"; type: "switch" }
                InspectorField { label: "淡入"; path: "global.audio.bgm.fade_in_ms"; type: "number"; min: 0; max: 3000; unit: "ms" }
                InspectorField { label: "淡出"; path: "global.audio.bgm.fade_out_ms"; type: "number"; min: 0; max: 3000; unit: "ms" }
                InspectorField { label: "音效音量"; path: "global.audio.sfx_volume_pct"; type: "slider"; min: 0; max: 100; step: 1; unit: "%" }
                InspectorField { label: "Ducking"; path: "global.audio.ducking_enabled"; type: "switch"; hint: "人声/朗读出现时自动压低音乐" }
            }

            Section {
                title: "动效"
                subtitle: "播放速度与系统偏好"
                InspectorField {
                    label: "低动效"
                    path: "global.motion.reduced_motion"
                    type: "combo"
                    options: [
                        { value: "auto", label: "跟随系统" },
                        { value: "on", label: "始终开启" },
                        { value: "off", label: "始终关闭" }
                    ]
                }
                InspectorField { label: "演出速度"; path: "global.motion.speed_scale"; type: "slider"; min: 0.25; max: 2.0; step: 0.05; unit: "×"; hint: "0.5× 适合逐幕调试" }
            }

            Section {
                title: "无障碍"
                subtitle: "对比度、透明度与跳过"
                InspectorField { label: "高对比度"; path: "global.accessibility.high_contrast"; type: "switch" }
                InspectorField { label: "降低透明度"; path: "global.accessibility.reduced_transparency"; type: "switch" }
                InspectorField { label: "常驻音频条"; path: "global.accessibility.always_show_audio_bar"; type: "switch" }
                InspectorField { label: "允许跳过"; path: "global.skip.enabled"; type: "switch" }
                InspectorField { label: "显示跳过键"; path: "global.skip.show_button"; type: "switch" }
            }

            Section {
                title: "资源库"
                subtitle: (session.draft.assets ? session.draft.assets.length : 0) + " 个素材"
                Repeater {
                    model: session.draft.assets || []
                    Rectangle {
                        width: parent.width
                        height: 40
                        radius: 8
                        color: Qt.rgba(0, 0, 0, 0.10)
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 86
                            text: modelData.filename + "  ·  " + (modelData.license || "unknown")
                            color: root.ink
                            font.family: theme.hanFamily
                            font.pixelSize: 10
                            elide: Text.ElideMiddle
                        }
                        EdButton {
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            text: "打开"
                            small: true
                            onClicked: app.openPath(session.profileDir + "/assets/" + modelData.filename)
                        }
                    }
                }
                Text {
                    width: parent.width
                    visible: !session.draft.assets || session.draft.assets.length === 0
                    text: "还没有素材。导入的音乐/图片会按内容 hash 去重。"
                    color: root.muted
                    font.family: theme.hanFamily
                    font.pixelSize: 10
                    wrapMode: Text.Wrap
                    opacity: 0.65
                }
                EdButton {
                    text: "导入素材…"
                    small: true
                    onClicked: assetPicker.open()
                }
                FileDialog {
                    id: assetPicker
                    title: "导入素材"
                    fileMode: FileDialog.OpenFile
                    onAccepted: {
                        var rel = session.importAsset(selectedFile, "other", "unknown")
                        if (rel !== "")
                            root.toast.emit("已导入素材")
                    }
                }
            }
        }
    }

    Component {
        id: introComp
        Column {
            width: parent.width
            spacing: 12

            Section {
                title: "本幕"
                subtitle: "开启方式与门禁"
                InspectorField { label: "启用"; path: "acts.intro.enabled"; type: "switch" }
                InspectorField { label: "可跳过"; path: "acts.intro.skippable"; type: "switch" }
                InspectorField {
                    label: "进入方式"
                    path: "acts.intro.enter"
                    type: "combo"
                    options: [
                        { value: "on-tap", label: "点击开始（推荐，获得音频授权）" },
                        { value: "auto:0", label: "立即开始" },
                        { value: "auto:1500", label: "延迟 1.5s" }
                    ]
                }
                InspectorField {
                    label: "退出方式"
                    path: "acts.intro.exit"
                    type: "combo"
                    options: [
                        { value: "on-tap:envelope", label: "点击信封" },
                        { value: "auto:4000", label: "4 秒后自动" },
                        { value: "auto:8000", label: "8 秒后自动" }
                    ]
                }
                EdButton { text: "恢复本幕默认"; small: true; onClicked: session.resetAct("intro") }
            }

            Section {
                title: "门禁"
                subtitle: "全屏开启按钮"
                InspectorField { label: "开场门禁"; path: "acts.intro.gate"; type: "switch"; hint: "暗色幕布 + 开启按钮，点击后才亮出信封" }
                InspectorField { label: "按钮文案"; path: "acts.intro.gate_text"; type: "text" }
                InspectorField { label: "副标题"; path: "acts.intro.gate_subtext"; type: "text" }
            }

            Section {
                title: "提示文案"
                subtitle: "信封下方的引导"
                InspectorField { label: "提示文字"; path: "acts.intro.hint"; type: "text" }
                InspectorField { label: "字号"; path: "acts.intro.hint_size"; type: "slider"; min: 14; max: 40; step: 1; unit: "px" }
                InspectorField { label: "颜色"; path: "acts.intro.hint_color"; type: "color"; hint: "留空则跟随主题" }
            }

            Section {
                title: "信封外观"
                subtitle: "纸张、火漆与丝带"
                InspectorField { label: "信封缩放"; path: "acts.intro.envelope_scale"; type: "slider"; min: 0.6; max: 1.4; step: 0.02 }
                InspectorField { label: "信纸"; path: "acts.intro.envelope.paper_color"; type: "color" }
                InspectorField { label: "翻盖"; path: "acts.intro.envelope.flap_color"; type: "color" }
                InspectorField { label: "火漆"; path: "acts.intro.envelope.seal_color"; type: "color" }
                InspectorField { label: "火漆高光"; path: "acts.intro.envelope.seal_highlight"; type: "color" }
                InspectorField { label: "丝带"; path: "acts.intro.envelope.ribbon_color"; type: "color" }
                InspectorField { label: "封蜡线"; path: "acts.intro.envelope.thread_color"; type: "color" }
            }
        }
    }

    Component {
        id: waxComp
        Column {
            width: parent.width
            spacing: 12

            Section {
                title: "本幕"
                subtitle: "信件模式与火漆"
                InspectorField { label: "启用"; path: "acts.wax.enabled"; type: "switch" }
                InspectorField { label: "可跳过"; path: "acts.wax.skippable"; type: "switch" }
                InspectorField {
                    label: "信件模式"
                    path: "acts.wax.letter_mode"
                    type: "combo"
                    options: [
                        { value: "animated", label: "信纸展开" },
                        { value: "none", label: "无信件（直接进入祝福）" }
                    ]
                }
                Text {
                    width: parent.width
                    visible: (actsCfg.wax && actsCfg.wax.letter_mode === "none")
                    text: "当前为「无信件」：下方的正文与排版不会播放，但仍会保留在配置里。"
                    color: root.muted
                    font.family: theme.hanFamily
                    font.pixelSize: 10
                    wrapMode: Text.Wrap
                    opacity: 0.7
                }
                EdButton { text: "恢复本幕默认"; small: true; onClicked: session.resetAct("wax") }
            }

            Section {
                title: "信件内容"
                subtitle: "正文与阅读节奏"
                InspectorField { label: "信件正文"; path: "acts.wax.letter.text"; type: "textarea"; hint: "支持 {honoree} {author} 占位符" }
                InspectorField {
                    label: "读完后"
                    path: "acts.wax.letter.advance"
                    type: "combo"
                    options: [
                        { value: "click", label: "点击推进" },
                        { value: "auto", label: "自动推进" }
                    ]
                    hint: "自动推进会在正文呈现完后等待约 2.6s"
                }
            }

            Section {
                title: "信纸外观"
                subtitle: "纸张与墨水"
                InspectorField { label: "纸张"; path: "acts.wax.letter.paper_color"; type: "color" }
                InspectorField { label: "墨色"; path: "acts.wax.letter.ink_color"; type: "color" }
                InspectorField { label: "强调色"; path: "acts.wax.letter.accent_color"; type: "color" }
            }

            Section {
                title: "文字排版"
                subtitle: "字体、行距与呈现方式"
                InspectorField {
                    label: "字体"
                    path: "acts.wax.letter.font_family"
                    type: "combo"
                    options: [
                        { value: "hanSerif", label: "宋体（衬线）" },
                        { value: "han", label: "黑体（无衬线）" }
                    ]
                }
                InspectorField { label: "字号"; path: "acts.wax.letter.font_size_px"; type: "slider"; min: 12; max: 32; step: 1; unit: "px" }
                InspectorField { label: "行高"; path: "acts.wax.letter.line_height"; type: "slider"; min: 1.2; max: 2.2; step: 0.05 }
                InspectorField {
                    label: "呈现方式"
                    path: "acts.wax.letter.presentation"
                    type: "combo"
                    options: [
                        { value: "typewriter", label: "打字机" },
                        { value: "lines", label: "逐句浮现" },
                        { value: "static", label: "静态显示" }
                    ]
                }
                InspectorField { label: "打字速度"; path: "acts.wax.letter.chars_per_second"; type: "slider"; min: 6; max: 60; step: 1; unit: "字/秒" }
                InspectorField { label: "逐句间隔"; path: "acts.wax.letter.line_stagger_ms"; type: "number"; min: 60; max: 2000; unit: "ms" }
            }

            Section {
                title: "火漆动效"
                subtitle: "按压与碎裂"
                InspectorField { label: "火漆按压"; path: "acts.wax.press_scale"; type: "slider"; min: 0.88; max: 0.99; step: 0.01 }
                InspectorField { label: "碎裂时长"; path: "acts.wax.crack_ms"; type: "number"; min: 100; max: 800; unit: "ms" }
            }
        }
    }

    Component {
        id: popupsComp
        Column {
            width: parent.width
            spacing: 12

            Section {
                title: "本幕"
                subtitle: "播放与推进"
                InspectorField { label: "启用"; path: "acts.popups.enabled"; type: "switch" }
                InspectorField { label: "可跳过"; path: "acts.popups.skippable"; type: "switch"; hint: "允许播放器右下角的跳过键略过本幕" }
                InspectorField {
                    label: "自动推进"
                    path: "acts.popups.auto_advance"
                    type: "switch"
                    hint: "关闭后，蜂群与祝福卡播放完会停住，轻触画面继续"
                }
                InspectorField {
                    label: "收尾停留"
                    path: "acts.popups.sequence.hold_after_ms"
                    type: "slider"
                    min: 400
                    max: 12000
                    step: 100
                    unit: "ms"
                    hint: "仅自动推进时生效；从最后一张卡出现后开始计时"
                }
                Text {
                    width: parent.width
                    visible: {
                        var swarmOn = popupsCfg.swarm && popupsCfg.swarm.enabled !== false
                        return popupsCfg.cards_enabled === false && !swarmOn
                    }
                    text: "祝福卡与蜂群便签都已关闭，这一幕没有可显示内容，播放时会直接跳过。"
                    color: "#ffd166"
                    font.family: theme.hanFamily
                    font.pixelSize: 10
                    wrapMode: Text.Wrap
                }
                EdButton { text: "恢复本幕默认"; small: true; onClicked: session.resetAct("popups") }
            }

            Section {
                title: "祝福卡"
                subtitle: root.cardsCount + " 只 · 列表顺序即出场顺序"
                InspectorField {
                    label: "随后弹出"
                    path: "acts.popups.cards_enabled"
                    type: "switch"
                    hint: "关闭后只保留蜂群便签，不再飞入可读卡"
                }
                InspectorField {
                    label: "弹出数量"
                    path: "acts.popups.cards_limit"
                    type: "combo"
                    coerce: "int"
                    options: root.cardLimitOptions
                    hint: "只播放前 N 只；其余卡片保留在列表里，便于随时恢复"
                }
                Row {
                    spacing: 6
                    EdButton { text: "+ 添加"; small: true; onClicked: { session.addCard(); root.selectedCard = root.cardsCount - 1 } }
                    EdButton { text: "上移"; small: true; enabled: root.selectedCard > 0; onClicked: { session.moveCard(root.selectedCard, root.selectedCard - 1); root.selectedCard = Math.max(0, root.selectedCard - 1) } }
                    EdButton { text: "下移"; small: true; enabled: root.selectedCard < root.cardsCount - 1; onClicked: { session.moveCard(root.selectedCard, root.selectedCard + 1); root.selectedCard = Math.min(root.cardsCount - 1, root.selectedCard + 1) } }
                    EdButton { text: "删除"; small: true; danger: true; enabled: root.cardsCount > 1; onClicked: { session.removeCard(root.selectedCard); root.selectedCard = Math.max(0, Math.min(root.selectedCard, root.cardsCount - 1)) } }
                }
                Column {
                    width: parent.width
                    spacing: 4
                    Repeater {
                        model: root.cardsCount
                        Rectangle {
                            width: parent.width
                            height: 34
                            radius: 8
                            color: root.selectedCard === index ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.10)
                            border.width: 1
                            border.color: root.selectedCard === index ? root.accent : root.borderColor
                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8
                                Text {
                                    text: root.cards[index] ? (root.cards[index].emoji || "✨") : "✨"
                                    font.pixelSize: 13
                                }
                                Text {
                                    text: root.cards[index] ? (root.cards[index].title || "未命名") : ""
                                    color: root.ink
                                    font.family: theme.hanFamily
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                    width: parent.parent.width - 80
                                }
                            }
                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: "#" + (index + 1)
                                color: root.muted
                                font.family: "Consolas"
                                font.pixelSize: 9
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectedCard = index
                            }
                        }
                    }
                }
            }

            Section {
                title: "卡片 " + (root.selectedCard + 1) + " 详情"
                visible: root.cardsCount > 0
                InspectorField { label: "标题"; path: "acts.popups.cards[" + root.selectedCard + "].title"; type: "text" }
                InspectorField { label: "正文"; path: "acts.popups.cards[" + root.selectedCard + "].body"; type: "textarea" }
                InspectorField { label: "符号"; path: "acts.popups.cards[" + root.selectedCard + "].emoji"; type: "text" }
                InspectorField { label: "宽度"; path: "acts.popups.cards[" + root.selectedCard + "].width"; type: "slider"; min: 240; max: 640; step: 4; unit: "px" }
                InspectorField { label: "高度"; path: "acts.popups.cards[" + root.selectedCard + "].height"; type: "slider"; min: 140; max: 480; step: 4; unit: "px" }
                InspectorField { label: "强调色"; path: "acts.popups.cards[" + root.selectedCard + "].accent"; type: "color"; hint: "留空则使用本幕的色彩策略" }
                InspectorField {
                    label: "覆盖样式"
                    path: "acts.popups.cards[" + root.selectedCard + "].style"
                    type: "combo"
                    options: [
                        { value: "", label: "跟随本幕" },
                        { value: "glass", label: "毛玻璃" },
                        { value: "cartoon", label: "卡通立体" }
                    ]
                }
                InspectorField { label: "配图"; path: "acts.popups.cards[" + root.selectedCard + "].image"; type: "path"; assetKind: "image" }
            }

            Section {
                title: "蜂群便签"
                subtitle: "沿轨迹铺满整条曲线"
                InspectorField {
                    label: "启用蜂群"
                    path: "acts.popups.swarm.enabled"
                    type: "switch"
                    hint: "数百枚小便签连成轨迹曲线；低动效模式下出现节奏会放缓"
                }
                InspectorField { label: "数量"; path: "acts.popups.swarm.count"; type: "slider"; min: 40; max: 400; step: 10 }
                InspectorField { label: "便签宽度"; path: "acts.popups.swarm.note_size"; type: "slider"; min: 20; max: 90; step: 2; unit: "px" }
                InspectorField {
                    label: "宽高比"
                    path: "acts.popups.swarm.note_aspect"
                    type: "combo"
                    options: [
                        { value: "1:1", label: "1:1 方形" },
                        { value: "4:3", label: "4:3 横版" },
                        { value: "3:4", label: "3:4 竖版" },
                        { value: "16:9", label: "16:9 宽幅" }
                    ]
                    hint: "所有便签统一使用这一比例，高度由宽度自动换算"
                }
                InspectorField { label: "重叠度"; path: "acts.popups.swarm.overlap_pct"; type: "slider"; min: 50; max: 98; step: 1; unit: "%" }
                InspectorField { label: "出现间隔"; path: "acts.popups.swarm.stagger_ms"; type: "slider"; min: 4; max: 60; step: 1; unit: "ms" }
                InspectorField { label: "淡入时长"; path: "acts.popups.swarm.fade_in_ms"; type: "slider"; min: 40; max: 600; step: 10; unit: "ms" }
                InspectorField { label: "位置抖动"; path: "acts.popups.swarm.jitter_px"; type: "slider"; min: 0; max: 30; step: 1; unit: "px" }
                InspectorField { label: "卡片随后出场"; path: "acts.popups.swarm.cards_delay_after"; type: "switch"; hint: "曲线成形后，可读祝福卡再飞入" }
                InspectorField { label: "便签文字"; path: "acts.popups.swarm.text_block"; type: "textarea"; hint: "每行一条，沿曲线循环显示；留空则不显示文字" }
                InspectorField { label: "文字大小"; path: "acts.popups.swarm.text_size"; type: "slider"; min: 6; max: 22; step: 1; unit: "px" }
                InspectorField { label: "每隔几枚显示"; path: "acts.popups.swarm.text_every"; type: "slider"; min: 1; max: 40; step: 1 }
                Text {
                    width: parent.width
                    text: "便签使用独立的糖果淡彩色带（粉红、粉蓝、丁香、薄荷），不继承卡片色板；「外观与色彩」里的单色模式仍会生效。"
                    color: root.muted
                    font.family: theme.hanFamily
                    font.pixelSize: 10
                    wrapMode: Text.Wrap
                    opacity: 0.65
                }
            }

            Section {
                title: "外观与色彩"
                subtitle: "卡片样式与配色"
                InspectorField {
                    label: "卡片样式"
                    path: "acts.popups.style"
                    type: "combo"
                    options: [
                        { value: "glass", label: "毛玻璃" },
                        { value: "cartoon", label: "卡通立体" }
                    ]
                }
                InspectorField {
                    label: "配色模式"
                    path: "acts.popups.color_strategy.mode"
                    type: "combo"
                    options: [
                        { value: "harmony", label: "谐和色板（推荐）" },
                        { value: "palette", label: "自定义色板" },
                        { value: "single", label: "单色" }
                    ]
                }

                InspectorField {
                    visible: root.colorMode === "harmony"
                    label: "和声"
                    path: "acts.popups.color_strategy.harmony"
                    type: "combo"
                    options: [
                        { value: "analogous", label: "邻近色" },
                        { value: "triadic", label: "三角色" },
                        { value: "complementary", label: "互补色" }
                    ]
                }
                InspectorField { visible: root.colorMode === "harmony"; label: "基准色相"; path: "acts.popups.color_strategy.base_hue"; type: "slider"; min: 0; max: 360; step: 1; unit: "°" }
                InspectorField { visible: root.colorMode === "harmony"; label: "最低饱和"; path: "acts.popups.color_strategy.saturation_bucket[0]"; type: "slider"; min: 0; max: 1; step: 0.01 }
                InspectorField { visible: root.colorMode === "harmony"; label: "最高饱和"; path: "acts.popups.color_strategy.saturation_bucket[1]"; type: "slider"; min: 0; max: 1; step: 0.01 }
                InspectorField { visible: root.colorMode === "harmony"; label: "最低亮度"; path: "acts.popups.color_strategy.lightness_bucket[0]"; type: "slider"; min: 0; max: 1; step: 0.01 }
                InspectorField { visible: root.colorMode === "harmony"; label: "最高亮度"; path: "acts.popups.color_strategy.lightness_bucket[1]"; type: "slider"; min: 0; max: 1; step: 0.01 }

                Row {
                    visible: root.colorMode === "harmony"
                    spacing: 5
                    Repeater {
                        model: colors.harmony(
                                   root.colorStrategy.base_hue !== undefined ? root.colorStrategy.base_hue : 14,
                                   root.colorStrategy.harmony || "analogous",
                                   0.46, 0.68, 0.64, 0.78, 6)
                        Rectangle {
                            width: 22
                            height: 22
                            radius: 11
                            color: modelData
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.25)
                        }
                    }
                }

                InspectorField { visible: root.colorMode === "single"; label: "单色"; path: "acts.popups.color_strategy.single_color"; type: "color" }

                Column {
                    visible: root.colorMode === "palette"
                    width: parent.width
                    spacing: 6
                    Repeater {
                        model: root.paletteList
                        Row {
                            width: parent.width
                            spacing: 6
                            EdColor {
                                width: parent.width - 54
                                value: modelData
                                onPicked: function (v) { root.setPaletteColor(index, v) }
                            }
                            EdButton {
                                y: 3
                                width: 46
                                text: "移除"
                                small: true
                                danger: true
                                onClicked: root.removePaletteColor(index)
                            }
                        }
                    }
                    Text {
                        width: parent.width
                        visible: root.paletteList.length === 0
                        text: "还没有色板颜色。至少添加一种，否则会自动回退到谐和色板。"
                        color: root.muted
                        font.family: theme.hanFamily
                        font.pixelSize: 10
                        wrapMode: Text.Wrap
                        opacity: 0.7
                    }
                    EdButton { text: "+ 添加颜色"; small: true; onClicked: root.addPaletteColor() }
                }
            }

            Section {
                title: "轨迹与出场"
                subtitle: "卡片飞入的路径"
                InspectorField {
                    label: "轨迹预设"
                    path: "acts.popups.trajectory.preset"
                    type: "combo"
                    options: [
                        { value: "heart", label: "爱心" },
                        { value: "arc", label: "圆弧" },
                        { value: "circle", label: "环形" },
                        { value: "wave", label: "波浪" },
                        { value: "spiral", label: "螺旋" },
                        { value: "diagonal", label: "对角线" }
                    ]
                }
                InspectorField { label: "展开幅度"; path: "acts.popups.trajectory.span"; type: "slider"; min: 0.3; max: 0.95; step: 0.01 }
                InspectorField { label: "飞行时长"; path: "acts.popups.trajectory.duration_ms"; type: "slider"; min: 300; max: 6000; step: 50; unit: "ms" }
                InspectorField {
                    label: "轨迹缓动"
                    path: "acts.popups.trajectory.easing"
                    type: "combo"
                    options: [
                        { value: "outCubic", label: "缓出" },
                        { value: "outBack", label: "回弹" },
                        { value: "inOutCubic", label: "缓入缓出" },
                        { value: "linear", label: "线性" }
                    ]
                }
                InspectorField {
                    label: "卡片起点"
                    path: "acts.popups.sequence.appear_from"
                    type: "combo"
                    options: [
                        { value: "letter", label: "从信封方向飞出" },
                        { value: "trajectory", label: "从轨迹位置弹出" },
                        { value: "center", label: "从画面中心飞出" }
                    ]
                }
                EdButton { text: "手动绘制轨迹…"; small: true; onClicked: root.drawTrajectory() }
            }

            Section {
                title: "节奏"
                subtitle: "逐张出现的速度"
                InspectorField { label: "起始延迟"; path: "acts.popups.sequence.start_delay_ms"; type: "number"; min: 0; max: 4000; unit: "ms" }
                InspectorField { label: "出现间隔"; path: "acts.popups.sequence.stagger_ms"; type: "slider"; min: 0; max: 300; step: 5; unit: "ms" }
                InspectorField { label: "同屏上限"; path: "acts.popups.sequence.max_living"; type: "slider"; min: 1; max: 12; step: 1; hint: "超过上限后，最早的一张开始淡出" }
                InspectorField { label: "单卡停留"; path: "acts.popups.sequence.lifetime_ms"; type: "number"; min: 1000; max: 30000; unit: "ms" }
                InspectorField { label: "渐隐时长"; path: "acts.popups.sequence.fade_ms"; type: "number"; min: 80; max: 1000; unit: "ms" }
                InspectorField { label: "最终透明度"; path: "acts.popups.sequence.opacity_final"; type: "slider"; min: 0; max: 1; step: 0.05 }
                InspectorField { label: "浮动幅度"; path: "acts.popups.sequence.float_amplitude"; type: "slider"; min: 0; max: 24; step: 1 }
            }
        }
    }

    Component {
        id: confirmComp
        Column {
            width: parent.width
            spacing: 12

            Section {
                title: "本幕"
                subtitle: "轻触确认卡后继续"
                InspectorField { label: "启用"; path: "acts.confirm.enabled"; type: "switch" }
                InspectorField { label: "可跳过"; path: "acts.confirm.skippable"; type: "switch" }
                Text {
                    width: parent.width
                    text: "本幕不参与自动推进：需要轻触确认卡（或按空格）才会进入揭幕。"
                    color: root.muted
                    font.family: theme.hanFamily
                    font.pixelSize: 10
                    wrapMode: Text.Wrap
                    opacity: 0.7
                }
                EdButton { text: "恢复本幕默认"; small: true; onClicked: session.resetAct("confirm") }
            }

            Section {
                title: "卡片文案"
                subtitle: "主提示与补充说明"
                InspectorField { label: "主文案"; path: "acts.confirm.text"; type: "text" }
                InspectorField { label: "副文案"; path: "acts.confirm.subtext"; type: "text" }
            }

            Section {
                title: "卡片外观"
                subtitle: "样式、尺寸与按压手感"
                InspectorField {
                    label: "样式"
                    path: "acts.confirm.style"
                    type: "combo"
                    options: [
                        { value: "glass", label: "毛玻璃" },
                        { value: "cartoon", label: "卡通立体" }
                    ]
                }
                InspectorField { label: "宽度"; path: "acts.confirm.width"; type: "slider"; min: 320; max: 820; step: 4; unit: "px" }
                InspectorField { label: "高度"; path: "acts.confirm.height"; type: "slider"; min: 160; max: 480; step: 4; unit: "px" }
                InspectorField { label: "按压缩放"; path: "acts.confirm.press_scale"; type: "slider"; min: 0.90; max: 0.99; step: 0.01 }
            }
        }
    }

    Component {
        id: dissolveComp
        Column {
            width: parent.width
            spacing: 12

            Section {
                title: "本幕"
                subtitle: "从纸面世界揭开 3D 蛋糕"
                InspectorField { label: "启用"; path: "acts.dissolve.enabled"; type: "switch" }
                InspectorField { label: "可跳过"; path: "acts.dissolve.skippable"; type: "switch" }
                EdButton { text: "恢复本幕默认"; small: true; onClicked: session.resetAct("dissolve") }
            }

            Section {
                title: "溶解转场"
                subtitle: "噪声边缘与暖光"
                InspectorField { label: "转场时长"; path: "acts.dissolve.duration_ms"; type: "slider"; min: 300; max: 900; step: 10; unit: "ms" }
                InspectorField { label: "噪声尺度"; path: "acts.dissolve.noise_scale"; type: "slider"; min: 4; max: 80; step: 1 }
                InspectorField { label: "边缘暖光"; path: "acts.dissolve.edge_glow"; type: "slider"; min: 0; max: 1; step: 0.05 }
            }

            Text {
                width: parent.width
                text: "消融会把纸面世界冻结成纹理，从中心向外揭开 3D 蛋糕；低动效模式下退化为透明度溶解。关闭蛋糕幕时，本幕会自动跳过。"
                color: root.muted
                font.family: theme.hanFamily
                font.pixelSize: 10
                wrapMode: Text.Wrap
                opacity: 0.7
            }
        }
    }

    Component {
        id: cakeComp
        Column {
            width: parent.width
            spacing: 12

            Section {
                title: "本幕"
                subtitle: "点亮蜡烛并许愿"
                InspectorField { label: "启用"; path: "acts.cake.enabled"; type: "switch" }
                InspectorField { label: "提示文字"; path: "acts.cake.hint"; type: "text" }
                InspectorField { label: "操作提示"; path: "acts.cake.interaction_hint"; type: "text"; hint: "旋转/点击引导，留空隐藏" }
                EdButton { text: "恢复本幕默认"; small: true; onClicked: session.resetAct("cake") }
            }

            Section {
                title: "蛋糕层"
                subtitle: root.layersCount + " 层 · 第 1 层在底部、尺寸最大"
                Row {
                    spacing: 6
                    EdButton { text: "+ 加一层"; small: true; enabled: root.layersCount < 5; onClicked: { session.addCakeLayer(); root.selectedLayer = root.layersCount } }
                    EdButton { text: "删除"; small: true; danger: true; enabled: root.layersCount > 1; onClicked: { session.removeCakeLayer(root.selectedLayer); root.selectedLayer = Math.max(0, Math.min(root.selectedLayer, root.layersCount - 1)) } }
                }
                Column {
                    width: parent.width
                    spacing: 4
                    Repeater {
                        model: root.layersCount
                        Rectangle {
                            width: parent.width
                            height: 32
                            radius: 8
                            color: root.selectedLayer === index ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.10)
                            border.width: 1
                            border.color: root.selectedLayer === index ? root.accent : root.borderColor
                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8
                                Rectangle {
                                    width: 18; height: 18; radius: 9
                                    color: root.layers[index] ? (root.layers[index].color || "#f6d3c3") : "#f6d3c3"
                                    border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.3)
                                }
                                Text {
                                    text: "第 " + (index + 1) + " 层" + (index === 0 ? "（底）" : (index === root.layersCount - 1 ? "（顶）" : ""))
                                    color: root.ink
                                    font.family: theme.hanFamily
                                    font.pixelSize: 11
                                }
                                Text {
                                    text: root.layers[index] ? (Math.round(root.layers[index].radius) + " × " + Math.round(root.layers[index].height)) : ""
                                    color: root.muted
                                    font.family: "Consolas"
                                    font.pixelSize: 9
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectedLayer = index
                            }
                        }
                    }
                }
                InspectorField { label: "半径"; path: "acts.cake.cake.layers[" + root.selectedLayer + "].radius"; type: "slider"; min: 40; max: 320; step: 2 }
                InspectorField { label: "高度"; path: "acts.cake.cake.layers[" + root.selectedLayer + "].height"; type: "slider"; min: 20; max: 200; step: 2 }
                InspectorField { label: "蛋糕色"; path: "acts.cake.cake.layers[" + root.selectedLayer + "].color"; type: "color" }
                InspectorField { label: "奶油色"; path: "acts.cake.cake.layers[" + root.selectedLayer + "].frosting"; type: "color" }
                InspectorField { label: "粗糙度"; path: "acts.cake.cake.layers[" + root.selectedLayer + "].roughness"; type: "slider"; min: 0; max: 1; step: 0.05 }
                InspectorField { label: "底座颜色"; path: "acts.cake.cake.plate_color"; type: "color"; hint: "盘子与整体台面" }
            }

            Section {
                title: "装饰"
                subtitle: "可多选"
                LabeledSwitch { label: "插牌"; on: root.hasDecoration("namePlague"); onToggled: function (v) { root.toggleDecoration("namePlague", v) } }
                LabeledSwitch { label: "水果"; on: root.hasDecoration("fruit"); onToggled: function (v) { root.toggleDecoration("fruit", v) } }
                LabeledSwitch { label: "奶油花边"; on: root.hasDecoration("piping"); onToggled: function (v) { root.toggleDecoration("piping", v) } }
                LabeledSwitch { label: "糖针"; on: root.hasDecoration("sprinkles"); onToggled: function (v) { root.toggleDecoration("sprinkles", v) } }
            }

            Section {
                title: "蜡烛"
                subtitle: "数量、排布与吹灭方式"
                InspectorField { label: "数量"; path: "acts.cake.candles.count"; type: "slider"; min: 1; max: 12; step: 1 }
                InspectorField {
                    label: "排布"
                    path: "acts.cake.candles.arrangement"
                    type: "combo"
                    options: [
                        { value: "arc", label: "弧形" },
                        { value: "circle", label: "环形" },
                        { value: "line", label: "一排" }
                    ]
                }
                InspectorField { label: "间距"; path: "acts.cake.candles.spacing"; type: "slider"; min: 14; max: 90; step: 1 }
                InspectorField { label: "高度"; path: "acts.cake.candles.height"; type: "slider"; min: 24; max: 120; step: 1 }
                InspectorField { label: "粗细"; path: "acts.cake.candles.radius"; type: "slider"; min: 2; max: 14; step: 1 }
                InspectorField { label: "火焰强度"; path: "acts.cake.candles.flame_intensity"; type: "slider"; min: 0.3; max: 2.0; step: 0.05 }
                InspectorField { label: "麦克风吹气"; path: "acts.cake.candles.mic_enabled"; type: "switch"; hint: "失败自动回退点击" }
                InspectorField { label: "麦克风阈值"; path: "acts.cake.candles.mic_threshold"; type: "slider"; min: 0.02; max: 0.95; step: 0.01 }
                Text {
                    text: "蜡烛配色（按顺序循环）"
                    color: root.muted
                    font.family: theme.hanFamily
                    font.pixelSize: 11
                }
                InspectorField { label: "蜡烛 1"; path: "acts.cake.candles.colors[0]"; type: "color" }
                InspectorField { label: "蜡烛 2"; path: "acts.cake.candles.colors[1]"; type: "color" }
                InspectorField { label: "蜡烛 3"; path: "acts.cake.candles.colors[2]"; type: "color" }
                InspectorField { label: "蜡烛 4"; path: "acts.cake.candles.colors[3]"; type: "color" }
                InspectorField { label: "蜡烛 5"; path: "acts.cake.candles.colors[4]"; type: "color" }
            }

            Section {
                title: "相机"
                subtitle: "观看蛋糕的角度"
                InspectorField { label: "俯仰角"; path: "acts.cake.camera.pitch"; type: "slider"; min: -5; max: 70; step: 1; unit: "°" }
                InspectorField { label: "偏航角"; path: "acts.cake.camera.yaw"; type: "slider"; min: -60; max: 60; step: 1; unit: "°" }
                InspectorField { label: "距离"; path: "acts.cake.camera.distance"; type: "slider"; min: 780; max: 1100; step: 10 }
            }

            Section {
                title: "许愿"
                subtitle: "吹灭蜡烛后的留白与揭示"
                InspectorField { label: "压暗时长"; path: "acts.cake.wish.darken_ms"; type: "number"; min: 150; max: 1500; unit: "ms" }
                InspectorField { label: "留白时长"; path: "acts.cake.wish.silence_ms"; type: "number"; min: 800; max: 6000; unit: "ms" }
                InspectorField { label: "揭示文字"; path: "acts.cake.wish.reveal_text"; type: "text" }
                InspectorField { label: "揭示时长"; path: "acts.cake.wish.reveal_duration_ms"; type: "number"; min: 300; max: 2500; unit: "ms" }
            }

            Section {
                title: "交互手感"
                subtitle: "拖动与点击时的弹性"
                InspectorField { label: "弹性"; path: "acts.cake.jelly.spring"; type: "slider"; min: 1; max: 6; step: 0.1 }
                InspectorField { label: "阻尼"; path: "acts.cake.jelly.damping"; type: "slider"; min: 0.1; max: 0.9; step: 0.02 }
                Text {
                    width: parent.width
                    text: "弹性越高，拖动蛋糕回弹越活泼；阻尼越高，晃动收得越快。"
                    color: root.muted
                    font.family: theme.hanFamily
                    font.pixelSize: 10
                    wrapMode: Text.Wrap
                    opacity: 0.7
                }
            }
        }
    }

    Component {
        id: finaleComp
        Column {
            width: parent.width
            spacing: 12

            Section {
                title: "本幕"
                subtitle: "彩带、祝福与收尾"
                InspectorField { label: "启用"; path: "acts.finale.enabled"; type: "switch" }
                EdButton { text: "恢复本幕默认"; small: true; onClicked: session.resetAct("finale") }
            }

            Section {
                title: "文案"
                subtitle: "终幕标题"
                InspectorField { label: "主标题"; path: "acts.finale.headline"; type: "text" }
                InspectorField { label: "副标题"; path: "acts.finale.subline"; type: "text"; hint: "支持 {honoree}" }
            }

            Section {
                title: "按钮"
                subtitle: "重播与关闭"
                InspectorField { label: "重播按钮"; path: "acts.finale.buttons.replay"; type: "text" }
                InspectorField { label: "合上按钮"; path: "acts.finale.buttons.close"; type: "text" }
            }

            Section {
                title: "彩带"
                subtitle: "爆发次数与粒子"
                InspectorField { label: "爆发次数"; path: "acts.finale.confetti.bursts"; type: "slider"; min: 1; max: 3; step: 1 }
                InspectorField { label: "每次粒子"; path: "acts.finale.confetti.particles_per_burst"; type: "slider"; min: 20; max: 180; step: 5 }
                InspectorField { label: "粒子上限"; path: "acts.finale.confetti.max_particles"; type: "slider"; min: 60; max: 900; step: 10; hint: "低性能设备建议 300 以下" }
                InspectorField { label: "重力"; path: "acts.finale.confetti.gravity"; type: "slider"; min: 100; max: 2400; step: 20 }
                InspectorField { label: "阻力"; path: "acts.finale.confetti.drag"; type: "slider"; min: 0.95; max: 0.999; step: 0.001 }
                InspectorField { label: "起点 X"; path: "acts.finale.confetti.origin_x"; type: "slider"; min: 0; max: 1; step: 0.01 }
                InspectorField { label: "起点 Y"; path: "acts.finale.confetti.origin_y"; type: "slider"; min: 0; max: 1; step: 0.01 }
                InspectorField { label: "扩散角"; path: "acts.finale.confetti.spread"; type: "slider"; min: 10; max: 120; step: 1; unit: "°" }
                Text {
                    text: "彩带配色（按顺序循环）"
                    color: root.muted
                    font.family: theme.hanFamily
                    font.pixelSize: 11
                }
                InspectorField { label: "彩带 1"; path: "acts.finale.confetti.colors[0]"; type: "color" }
                InspectorField { label: "彩带 2"; path: "acts.finale.confetti.colors[1]"; type: "color" }
                InspectorField { label: "彩带 3"; path: "acts.finale.confetti.colors[2]"; type: "color" }
                InspectorField { label: "彩带 4"; path: "acts.finale.confetti.colors[3]"; type: "color" }
                InspectorField { label: "彩带 5"; path: "acts.finale.confetti.colors[4]"; type: "color" }
            }
        }
    }
}
