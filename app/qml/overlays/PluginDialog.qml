import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import "../components"

ModalLayer {
    id: root
    title: "主题与插件"
    subtitle: "插件 = QML / 着色器 / 资产，不执行 Python；导出时自动内嵌"
    cardWidth: 820
    cardHeight: 640

    function syncProfile() {
        var ids = []
        var list = plugins.plugins || []
        for (var i = 0; i < list.length; i++) {
            if (list[i].enabled && list[i].compatible && !list[i].error)
                ids.push(list[i].id)
        }
        session.setField("plugins", ids)
        session.refreshTheme()
        showBridge.setPluginIds(ids)
    }

    Text {
        width: parent.width
        text: "已安装 " + (plugins.plugins ? plugins.plugins.length : 0) + " 个插件。启用后会写入当前配置档，导出包自动携带。"
        color: (theme.tokens && theme.tokens.ui && theme.tokens.ui.textMuted) || "#b9a9b6"
        font.family: theme.hanFamily
        font.pixelSize: 10
        wrapMode: Text.Wrap
    }

    ScrollView {
        width: parent.width
        height: parent.height - 130
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        Column {
            width: parent.width
            spacing: 8
            Repeater {
                model: plugins.plugins
                Rectangle {
                    width: parent.width
                    height: 104
                    radius: 12
                    color: Qt.rgba(0, 0, 0, 0.14)
                    border.width: 1
                    border.color: modelData.compatible ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 0.54, 0.5, 0.3)

                    Image {
                        id: preview
                        x: 10
                        y: 10
                        width: 100
                        height: 84
                        source: modelData.previewUrl || ""
                        fillMode: Image.PreserveAspectCrop
                        visible: modelData.previewUrl !== ""
                        layer.enabled: true
                    }
                    Rectangle {
                        x: 10
                        y: 10
                        width: 100
                        height: 84
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.05)
                        visible: !modelData.previewUrl
                        Text {
                            anchors.centerIn: parent
                            text: "插件"
                            color: (theme.tokens && theme.tokens.ui && theme.tokens.ui.textMuted) || "#b9a9b6"
                            font.family: theme.hanFamily
                            font.pixelSize: 11
                        }
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: 124
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.top: parent.top
                        anchors.topMargin: 10
                        spacing: 4
                        Row {
                            spacing: 8
                            Text {
                                text: modelData.name
                                color: (theme.tokens && theme.tokens.ui && theme.tokens.ui.text) || "#f5ede8"
                                font.family: theme.hanFamily
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: "v" + modelData.version
                                color: (theme.tokens && theme.tokens.ui && theme.tokens.ui.textMuted) || "#b9a9b6"
                                font.family: "Consolas"
                                font.pixelSize: 9
                            }
                        }
                        Text {
                            width: parent.width
                            text: modelData.description
                            color: (theme.tokens && theme.tokens.ui && theme.tokens.ui.textMuted) || "#b9a9b6"
                            font.family: theme.hanFamily
                            font.pixelSize: 10
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                        Text {
                            text: "槽位：" + (modelData.slots && modelData.slots.length ? modelData.slots.join(" · ") : "仅令牌")
                            color: (theme.tokens && theme.tokens.ui && theme.tokens.ui.textMuted) || "#b9a9b6"
                            font.family: theme.hanFamily
                            font.pixelSize: 9
                            opacity: 0.75
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 10
                        spacing: 8
                        EdSwitch {
                            anchors.verticalCenter: parent.verticalCenter
                            checked: modelData.enabled
                            enabled: modelData.compatible
                            onToggled: {
                                plugins.setEnabled(modelData.id, checked)
                                root.syncProfile()
                            }
                        }
                        EdButton {
                            text: modelData.compatible ? (modelData.enabled ? "停用" : "启用") : "不兼容"
                            small: true
                            enabled: modelData.compatible
                            onClicked: {
                                plugins.setEnabled(modelData.id, !modelData.enabled)
                                root.syncProfile()
                            }
                        }
                        EdButton {
                            visible: modelData.installed
                            text: "卸载"
                            small: true
                            danger: true
                            onClicked: {
                                plugins.uninstall(modelData.id)
                                root.syncProfile()
                            }
                        }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 124
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 8
                        text: modelData.compatibilityMessage || modelData.error || ""
                        color: ((theme.tokens && theme.tokens.ui && theme.tokens.ui.danger) || "#ff8a80")
                        font.family: theme.hanFamily
                        font.pixelSize: 9
                        visible: text !== ""
                    }
                }
            }
        }
    }

    Row {
        width: parent.width
        spacing: 8
        EdButton { text: "安装插件…"; primary: true; onClicked: folderPicker.open() }
        EdButton { text: "打开插件目录"; onClicked: app.openPath(plugins.pluginFolder()) }
        EdButton { text: "刷新"; onClicked: plugins.refresh() }
    }

    FileDialog {
        id: folderPicker
        title: "选择插件目录（含 manifest.json）"
        fileMode: FileDialog.Directory
        onAccepted: {
            var id = plugins.install(selectedFile.toString())
            if (id)
                root.syncProfile()
        }
    }

    Connections {
        target: plugins
        function onPluginsChanged() { root.syncProfile() }
    }
}
