import QtQuick
import "../components"

ModalLayer {
    id: root
    title: "新建配置档"
    subtitle: "从出厂主题模板开始，之后的一切都可改"
    cardWidth: 820
    cardHeight: 480
    signal created(string id)

    property string themeId: ""
    property bool creating: false

    onOpenedChanged: {
        if (opened) {
            root.themeId = ""
            nameField.text = ""
            honoreeField.text = "你"
            authorField.text = "SrQingChen"
            if (library.themes.length > 0)
                root.themeId = library.themes[0].id
        }
    }

    Text {
        text: "选择主题"
        color: (theme.tokens && theme.tokens.ui && theme.tokens.ui.text) ? theme.tokens.ui.text : "#f5ede8"
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
                height: 110
                radius: 12
                color: root.themeId === modelData.id ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.12)
                border.width: root.themeId === modelData.id ? 1.5 : 1
                border.color: root.themeId === modelData.id
                              ? ((theme.tokens && theme.tokens.ui && theme.tokens.ui.accent) || "#ffb08a")
                              : Qt.rgba(1, 1, 1, 0.12)

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6
                    Row {
                        spacing: 5
                        Repeater {
                            model: themeData.previewColors || []
                            Rectangle {
                                width: 22
                                height: 22
                                radius: 11
                                color: modelData
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.28)
                            }
                        }
                    }
                    Text {
                        text: modelData.name
                        color: (theme.tokens && theme.tokens.ui && theme.tokens.ui.text) ? theme.tokens.ui.text : "#f5ede8"
                        font.family: theme.hanFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                    Text {
                        width: parent.width
                        text: modelData.description || modelData.tagline || ""
                        color: (theme.tokens && theme.tokens.ui && theme.tokens.ui.textMuted) ? theme.tokens.ui.textMuted : "#b9a9b6"
                        font.family: theme.hanFamily
                        font.pixelSize: 10
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.themeId = modelData.id
                }
            }
        }
    }

    EdText {
        id: nameField
        width: parent.width
        placeholderText: "配置档显示名（留空自动生成）"
    }
    Row {
        width: parent.width
        spacing: 10
        EdText {
            id: honoreeField
            width: (parent.width - 10) * 0.5
            placeholderText: "寿星的名字"
        }
        EdText {
            id: authorField
            width: (parent.width - 10) * 0.5
            placeholderText: "作者"
        }
    }

    Item { width: 1; height: 6 }

    Row {
        width: parent.width
        spacing: 10
        EdButton {
            text: root.creating ? "创建中…" : "创建并开始"
            primary: true
            enabled: root.themeId !== "" && !root.creating
            onClicked: {
                root.creating = true
                var id = library.createProfile(root.themeId, nameField.text, honoreeField.text || "你", authorField.text || "SrQingChen")
                root.creating = false
                if (id) {
                    root.created(id)
                    root.close()
                }
            }
        }
        EdButton { text: "取消"; onClicked: root.close() }
    }
}
