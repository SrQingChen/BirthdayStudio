import QtQuick
import "../components"

ModalLayer {
    id: root
    title: "五步做一场生日仪式"
    subtitle: "选模板 → 写信 → 编弹窗 → 调蛋糕 → 预览导出"
    cardWidth: 860
    cardHeight: 660
    closeOnDim: false

    property int step: 0
    property string themeId: ""
    property string newName: ""
    property string newHonoree: "你"
    property bool applyColors: true
    property bool creating: false
    signal created(string id)
    signal playRequested()
    signal exportRequested()

    onOpenedChanged: {
        if (opened) {
            step = 0
            themeId = (session.draft.meta && session.draft.meta.theme) ? session.draft.meta.theme : (library.themes.length ? library.themes[0].id : "")
            newHonoree = session.draft.meta ? session.draft.meta.honoree : "你"
            newName = ""
        }
    }

    function next() {
        if (step === 0) {
            if (session.profileId === "") {
                root.creating = true
                var id = library.createProfile(root.themeId, root.newName, root.newHonoree || "你", "SrQingChen")
                root.creating = false
                if (!id)
                    return
                session.openProfile(id)
                root.created(id)
            } else if (root.themeId !== "" && root.themeId !== session.draft.meta.theme) {
                if (root.applyColors)
                    session.applyTheme(root.themeId, true)
                else
                    session.setField("meta.theme", root.themeId)
            }
        }
        if (step < 4)
            step += 1
    }

    function back() {
        if (step > 0)
            step -= 1
    }

    // step indicator
    Row {
        width: parent.width
        spacing: 8
        Repeater {
            model: ["模板", "写信", "弹窗", "蛋糕", "完成"]
            Row {
                spacing: 6
                Rectangle {
                    width: 22
                    height: 22
                    radius: 11
                    color: index <= root.step
                           ? ((theme.tokens && theme.tokens.ui && theme.tokens.ui.accent) || "#ffb08a")
                           : Qt.rgba(1, 1, 1, 0.12)
                    Text {
                        anchors.centerIn: parent
                        text: index + 1
                        color: index <= root.step ? "#2a1410" : ((theme.tokens && theme.tokens.ui && theme.tokens.ui.textMuted) || "#b9a9b6")
                        font.family: theme.hanFamily
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData
                    color: index <= root.step
                           ? ((theme.tokens && theme.tokens.ui && theme.tokens.ui.text) || "#f5ede8")
                           : ((theme.tokens && theme.tokens.ui && theme.tokens.ui.textMuted) || "#b9a9b6")
                    font.family: theme.hanFamily
                    font.pixelSize: 10
                }
                Item { width: 8; height: 1 }
            }
        }
    }

    // step 0
    Column {
        width: parent.width
        spacing: 10
        visible: root.step === 0
        Text {
            text: "选一个出厂主题模板"
            color: (theme.tokens && theme.tokens.ui && theme.tokens.ui.text) || "#f5ede8"
            font.family: theme.hanFamily
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }
        Flow {
            width: parent.width
            spacing: 10
            Repeater {
                model: library.themes
                Rectangle {
                    property var themeData: modelData
                    width: (parent.width - 10) / 2
                    height: 84
                    radius: 11
                    color: root.themeId === modelData.id ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.12)
                    border.width: root.themeId === modelData.id ? 1.5 : 1
                    border.color: root.themeId === modelData.id
                                  ? ((theme.tokens && theme.tokens.ui && theme.tokens.ui.accent) || "#ffb08a")
                                  : Qt.rgba(1, 1, 1, 0.10)
                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5
                        Repeater {
                            model: themeData.previewColors || []
                            Rectangle {
                                width: 18; height: 18; radius: 9
                                color: modelData
                                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.25)
                            }
                        }
                    }
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 8
                        text: modelData.name
                        color: (theme.tokens && theme.tokens.ui && theme.tokens.ui.text) || "#f5ede8"
                        font.family: theme.hanFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.themeId = modelData.id
                    }
                }
            }
        }

        Row {
            width: parent.width
            spacing: 10
            visible: session.profileId === ""
            EdText {
                width: (parent.width - 10) * 0.5
                text: root.newName
                placeholderText: "配置档名称（可留空）"
                onTextEdited: root.newName = text
            }
            EdText {
                width: (parent.width - 10) * 0.5
                text: root.newHonoree
                placeholderText: "寿星的名字"
                onTextEdited: root.newHonoree = text
            }
        }

        LabeledSwitch {
            width: parent.width
            label: "套用主题的默认配色（信封、蛋糕、彩带）"
            on: root.applyColors
            onToggled: function (v) { root.applyColors = v }
        }
    }

    // step 1
    Column {
        width: parent.width
        spacing: 8
        visible: root.step === 1
        InspectorField { label: "寿星"; path: "meta.honoree"; type: "text" }
        InspectorField { label: "信件正文"; path: "acts.wax.letter.text"; type: "textarea"; hint: "支持 {honoree} {author}；留空则跳过信件" }
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
        InspectorField { label: "纸张"; path: "acts.wax.letter.paper_color"; type: "color" }
        InspectorField { label: "墨色"; path: "acts.wax.letter.ink_color"; type: "color" }
    }

    // step 2
    Column {
        width: parent.width
        spacing: 8
        visible: root.step === 2
        Text {
            text: "编辑前 3 只弹窗；其余可在专家模式继续"
            color: (theme.tokens && theme.tokens.ui && theme.tokens.ui.textMuted) || "#b9a9b6"
            font.family: theme.hanFamily
            font.pixelSize: 10
        }
        InspectorField { label: "弹窗 1 标题"; path: "acts.popups.cards[0].title"; type: "text" }
        InspectorField { label: "弹窗 1 正文"; path: "acts.popups.cards[0].body"; type: "textarea" }
        InspectorField { label: "弹窗 2 标题"; path: "acts.popups.cards[1].title"; type: "text" }
        InspectorField { label: "弹窗 2 正文"; path: "acts.popups.cards[1].body"; type: "textarea" }
        InspectorField { label: "弹窗 3 标题"; path: "acts.popups.cards[2].title"; type: "text" }
        InspectorField { label: "弹窗 3 正文"; path: "acts.popups.cards[2].body"; type: "textarea" }
        EdButton { text: "+ 再加一只"; small: true; onClicked: session.addCard() }
    }

    // step 3
    Column {
        width: parent.width
        spacing: 8
        visible: root.step === 3
        InspectorField { label: "蜡烛数量"; path: "acts.cake.candles.count"; type: "slider"; min: 1; max: 12; step: 1 }
        InspectorField { label: "顶层颜色"; path: "acts.cake.cake.layers[2].color"; type: "color" }
        InspectorField { label: "揭示文字"; path: "acts.cake.wish.reveal_text"; type: "text" }
        InspectorField { label: "允许麦克风吹气"; path: "acts.cake.candles.mic_enabled"; type: "switch"; hint: "失败自动回退点击" }
        InspectorField { label: "终幕主标题"; path: "acts.finale.headline"; type: "text" }
    }

    // step 4
    Column {
        width: parent.width
        spacing: 12
        visible: root.step === 4
        Text {
            text: "准备好了"
            color: (theme.tokens && theme.tokens.ui && theme.tokens.ui.text) || "#f5ede8"
            font.family: theme.serifFamily
            font.pixelSize: 26
            font.weight: Font.DemiBold
        }
        Text {
            width: parent.width
            text: "现在可以试演整场仪式；导出会生成「播放器 + 配置包」目录与 zip，收礼人双击即可观看。"
            color: (theme.tokens && theme.tokens.ui && theme.tokens.ui.textMuted) || "#b9a9b6"
            font.family: theme.hanFamily
            font.pixelSize: 12
            wrapMode: Text.Wrap
            lineHeight: 1.5
        }
        Text {
            width: parent.width
            text: "当前校验：" + (session.canExport ? "通过" : (session.errorCount + " 个错误需要处理")) + " · " + session.warningCount + " 个警告"
            color: session.canExport ? "#7ee0d0" : ((theme.tokens && theme.tokens.ui && theme.tokens.ui.danger) || "#ff8a80")
            font.family: theme.hanFamily
            font.pixelSize: 11
        }
        Row {
            spacing: 10
            EdButton { text: "▶ 试演整场"; primary: true; onClicked: root.playRequested() }
            EdButton { text: "打开导出"; onClicked: root.exportRequested() }
        }
    }

    Item { width: 1; height: 4 }

    Row {
        width: parent.width
        spacing: 10
        EdButton { text: "上一步"; enabled: root.step > 0; onClicked: root.back() }
        Item { width: 1; height: 1 }
        EdButton {
            text: root.step === 0 && session.profileId === "" ? "开始制作" : (root.step === 4 ? "完成" : "下一步")
            primary: true
            enabled: !root.creating
            onClicked: {
                if (root.step === 4)
                    root.close()
                else
                    root.next()
            }
        }
        EdButton { text: "关闭"; onClicked: root.close() }
    }
}
