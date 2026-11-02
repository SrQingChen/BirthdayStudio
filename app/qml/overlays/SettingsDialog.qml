import QtQuick
import "../components"

ModalLayer {
    id: root
    title: "设置"
    subtitle: "应用级设置与数据目录（与配置档分离）"
    cardWidth: 660
    cardHeight: 600

    Column {
        width: parent.width
        spacing: 14

        Section {
            title: "启动与编辑"
            LabeledSwitch {
                width: parent.width
                label: "启动时恢复上次打开的配置档与编辑上下文"
                on: app.startupRestore
                onToggled: function (v) { app.startupRestore = v }
            }
            Row {
                width: parent.width
                spacing: 10
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 200
                    text: "默认编辑模式"
                    color: (theme.tokens && theme.tokens.ui && theme.tokens.ui.textMuted) || "#b9a9b6"
                    font.family: theme.hanFamily
                    font.pixelSize: 12
                }
                EdCombo {
                    width: 180
                    value: app.editorMode
                    options: [
                        { value: "wizard", label: "向导模式" },
                        { value: "expert", label: "专家模式" }
                    ]
                    onPicked: function (v) { app.editorMode = v }
                }
            }
        }

        Section {
            title: "数据与缓存"
            Row {
                width: parent.width
                spacing: 8
                EdButton { text: "数据目录"; onClicked: app.openPath(app.homeDir) }
                EdButton { text: "插件目录"; onClicked: app.openPath(plugins.pluginFolder()) }
                EdButton { text: "日志"; onClicked: app.openPath(app.homeDir + "/logs") }
            }
            Text {
                width: parent.width
                text: "配置档：%APPDATA%/BirthdayStudio/profiles\n快照：每个配置档下 snapshots/（滚动保留 10 份）\n回收站：删除后保留 30 天"
                color: (theme.tokens && theme.tokens.ui && theme.tokens.ui.textMuted) || "#b9a9b6"
                font.family: theme.hanFamily
                font.pixelSize: 10
                wrapMode: Text.Wrap
                lineHeight: 1.5
                opacity: 0.75
            }
        }

        Section {
            title: "健康与无障碍"
            Text {
                width: parent.width
                text: "三条红线在编辑器内强制校验：闪烁 ≤3 次/秒且亮度变化 <10%；音频常驻可控、默认音量 ≤50%；低动效模式覆盖全部特效。"
                color: (theme.tokens && theme.tokens.ui && theme.tokens.ui.textMuted) || "#b9a9b6"
                font.family: theme.hanFamily
                font.pixelSize: 10
                wrapMode: Text.Wrap
                lineHeight: 1.6
                opacity: 0.8
            }
            Text {
                width: parent.width
                text: "系统“减弱动态效果”检测：" + (app.systemReducedMotion ? "已检测到开启" : "未检测到")
                color: app.systemReducedMotion ? "#7ee0d0" : ((theme.tokens && theme.tokens.ui && theme.tokens.ui.textMuted) || "#b9a9b6")
                font.family: theme.hanFamily
                font.pixelSize: 10
            }
        }

        Section {
            title: "维护"
            Row {
                width: parent.width
                spacing: 8
                EdButton {
                    text: "清空回收站"
                    danger: true
                    onClicked: library.emptyTrash()
                }
                EdButton {
                    text: "重新扫描库"
                    onClicked: library.refresh()
                }
            }
        }

        Item { width: 1; height: 4 }
        Text {
            width: parent.width
            text: "BirthdayStudio " + app.version + " · GPL-3.0（插件接口例外）· 作者 SrQingChen"
            color: (theme.tokens && theme.tokens.ui && theme.tokens.ui.textMuted) || "#b9a9b6"
            font.family: theme.hanFamily
            font.pixelSize: 10
            wrapMode: Text.Wrap
            opacity: 0.6
        }
    }
}
