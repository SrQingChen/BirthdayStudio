import QtQuick
import "../components"
import QtQuick.Dialogs

ModalLayer {
    id: root
    title: "导出演出"
    subtitle: "默认形态：通用播放器 + profile 目录，收礼人解压双击即看"
    cardWidth: 760
    cardHeight: 570
    signal exported(string path)

    property string destination: ""
    property string exeName: ""
    property string form: "folder"
    property bool includeBbp: true
    property bool copyrightConfirmed: false
    property var result: ({})
    readonly property bool errorsOK: session.errorCount === 0 && session.profileId !== ""

    onOpenedChanged: {
        if (opened) {
            var honoree = session.draft.meta ? session.draft.meta.honoree : "你"
            root.exeName = "给" + honoree + "的生日礼物"
            root.destination = app.lastExportDir !== "" ? app.lastExportDir : (app.homeDir + "/exports")
            root.result = ({})
            root.copyrightConfirmed = false
        }
    }

    Text {
        width: parent.width
        text: root.errorsOK ? "校验通过，可以导出" : ("导出被阻止：" + session.errorCount + " 个错误未解决")
        color: root.errorsOK ? "#7ee0d0" : ((theme.tokens && theme.tokens.ui && theme.tokens.ui.danger) || "#ff8a80")
        font.family: theme.hanFamily
        font.pixelSize: 12
        font.weight: Font.DemiBold
    }

    Row {
        width: parent.width
        spacing: 8
        EdText {
            width: parent.width - 112
            text: root.destination
            readOnly: true
            placeholderText: "选择导出目录"
        }
        EdButton { text: "选择文件夹"; onClicked: folderPicker.open() }
    }

    EdText {
        width: parent.width
        text: root.exeName
        onTextEdited: root.exeName = text
        placeholderText: "exe / 文件夹名称"
    }

    Row {
        width: parent.width
        spacing: 10
        EdButton {
            text: "播放器 + 配置包"
            checkable: true
            checked: root.form === "folder"
            onClicked: root.form = "folder"
        }
        EdButton {
            text: "单文件 exe（需专用构建）"
            checkable: true
            checked: root.form === "single"
            onClicked: root.form = "single"
        }
    }

    Text {
        width: parent.width
        text: "单文件需要把 profile 打进专用播放器；当前版本选择单文件会安全退回「播放器 + 配置包」。"
        color: (theme.tokens && theme.tokens.ui && theme.tokens.ui.textMuted) || "#b9a9b6"
        font.family: theme.hanFamily
        font.pixelSize: 10
        wrapMode: Text.Wrap
        opacity: 0.65
    }

    LabeledSwitch {
        width: parent.width
        label: "同时附带 .bbp 配置包（便于再次编辑）"
        on: root.includeBbp
        onToggled: function (v) { root.includeBbp = v }
    }

    LabeledSwitch {
        width: parent.width
        label: "我确认已拥有音乐 / 图片 / 字体的分发授权"
        on: root.copyrightConfirmed
        onToggled: function (v) { root.copyrightConfirmed = v }
    }

    Text {
        width: parent.width
        text: exporter.playerAvailable
              ? "检测到预编译播放器：" + exporter.playerPath
              : "未检测到预编译 Player.exe，将导出开发模式启动器。正式分发前请运行 scripts/build_player.bat。"
        color: exporter.playerAvailable ? "#7ee0d0"
                                       : ((theme.tokens && theme.tokens.ui && theme.tokens.ui.textMuted) || "#b9a9b6")
        font.family: theme.hanFamily
        font.pixelSize: 10
        wrapMode: Text.Wrap
        opacity: 0.85
    }

    Text {
        width: parent.width
        text: "导出包会自动附带 LICENSES/（GPL-3.0、第三方许可与源码获取说明）；你的祝福文字与媒体仍归你所有。"
        color: (theme.tokens && theme.tokens.ui && theme.tokens.ui.textMuted) || "#b9a9b6"
        font.family: theme.hanFamily
        font.pixelSize: 10
        wrapMode: Text.Wrap
        opacity: 0.7
    }

    Item { width: 1; height: 4 }

    Row {
        width: parent.width
        spacing: 10
        EdButton {
            text: "开始导出"
            primary: true
            enabled: root.errorsOK && root.copyrightConfirmed && root.destination !== "" && root.result.ok !== true
            onClicked: {
                var opts = {
                    "form": root.form,
                    "exe_name": root.exeName,
                    "include_profile_bbp": root.includeBbp,
                    "copyright_confirmed": root.copyrightConfirmed,
                    "license_confirmations": {
                        "背景音乐": "已确认授权类型",
                        "图片/视频": "已确认授权类型",
                        "字体": "已确认授权类型"
                    }
                }
                var res = exporter.exportPackage(session.profileId, root.destination, opts)
                root.result = res
                if (res.ok) {
                    app.setLastExportDir(root.destination)
                    root.exported(res.packageDir)
                }
            }
        }
        EdButton { text: "打开导出目录"; enabled: root.destination !== ""; onClicked: app.openPath(root.destination) }
    }

    Rectangle {
        visible: root.result.ok === true
        width: parent.width
        height: 72
        radius: 10
        color: Qt.rgba(0.49, 0.88, 0.82, 0.10)
        border.width: 1
        border.color: Qt.rgba(0.49, 0.88, 0.82, 0.35)
        Column {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            Text {
                text: "导出完成"
                color: "#7ee0d0"
                font.family: theme.hanFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }
            Text {
                text: root.result.zipPath || root.result.packageDir || ""
                color: (theme.tokens && theme.tokens.ui && theme.tokens.ui.textMuted) || "#b9a9b6"
                font.family: "Consolas"
                font.pixelSize: 10
                elide: Text.ElideMiddle
                width: parent.parent.width - 24
            }
            Text {
                text: "包体大小：" + Math.round((root.result.sizeBytes || 0) / 1024) + " KiB"
                color: (theme.tokens && theme.tokens.ui && theme.tokens.ui.textMuted) || "#b9a9b6"
                font.family: theme.hanFamily
                font.pixelSize: 10
            }
        }
    }

    FileDialog {
        id: folderPicker
        title: "选择导出目录"
        fileMode: FileDialog.Directory
        onAccepted: root.destination = selectedFile.toString()
    }
}
