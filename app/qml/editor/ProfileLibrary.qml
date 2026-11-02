import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import "../components"

Item {
    id: root

    property string currentId: ""
    property string searchText: ""
    signal openProfile(string id)
    signal newProfile()
    signal importRequested()
    signal cardAction(string action, string id)
    signal trashRequested()

    function openImport() {
        filePicker.open()
    }

    readonly property var ui: (theme.tokens && theme.tokens.ui) ? theme.tokens.ui : ({})
    readonly property color ink: ui.text || "#f5ede8"
    readonly property color muted: ui.textMuted || "#b9a9b6"
    readonly property color accent: ui.accent || "#ffb08a"
    readonly property color borderColor: ui.panelBorder || "#ffffff14"
    readonly property var filtered: {
        var all = library.profiles || []
        var q = searchText.trim().toLowerCase()
        if (q === "")
            return all
        var out = []
        for (var i = 0; i < all.length; i++) {
            var p = all[i]
            if ((p.name || "").toLowerCase().indexOf(q) >= 0 || (p.honoree || "").toLowerCase().indexOf(q) >= 0)
                out.push(p)
        }
        return out
    }

    width: 268

    Rectangle { anchors.fill: parent; color: ui.panelAlt || "#1f1629" }
    Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: root.borderColor }

    Column {
        id: content
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        Row {
            width: parent.width
            spacing: 8
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "配置档库"
                color: root.ink
                font.family: theme.hanFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: (library.profiles ? library.profiles.length : 0) + ""
                color: root.muted
                font.family: theme.hanFamily
                font.pixelSize: 10
                opacity: 0.7
            }
        }

        EdText {
            width: parent.width
            height: 32
            placeholderText: "搜索配置档 / 寿星"
            text: root.searchText
            onTextEdited: root.searchText = text
        }

        Row {
            width: parent.width
            spacing: 6
            EdButton {
                width: (parent.width - 6) / 2
                text: "＋ 新建"
                primary: true
                onClicked: root.newProfile()
            }
            EdButton {
                width: (parent.width - 6) / 2
                text: "导入 .bbp"
                onClicked: root.openImport()
            }
        }

        ListView {
            id: list
            width: parent.width
            height: parent.height - y - footer.height - 8
            clip: true
            spacing: 4
            model: root.filtered
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            delegate: ProfileCard {
                width: list.width
                profile: modelData
                selected: root.currentId === modelData.id
                onActivated: function (id) { root.openProfile(id) }
                onAction: function (action, id) { root.cardAction(action, id) }
            }

            Text {
                anchors.centerIn: parent
                width: parent.width * 0.8
                visible: root.filtered.length === 0
                text: root.searchText !== "" ? "没有匹配的配置档" : "还没有配置档\n点击「新建」开始第一场仪式"
                color: root.muted
                font.family: theme.hanFamily
                font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 1.6
                opacity: 0.7
            }
        }

        Item {
            id: footer
            width: parent.width
            height: 30
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                EdButton { text: "回收站"; small: true; onClicked: root.trashRequested() }
                EdButton { text: "数据目录"; small: true; onClicked: app.openPath(app.homeDir) }
            }
        }
    }

    FileDialog {
        id: filePicker
        title: "导入配置档包"
        fileMode: FileDialog.OpenFile
        nameFilters: ["BirthdayStudio 配置包 (*.bbp)", "所有文件 (*)"]
        onAccepted: {
            var id = library.importBbp(selectedFile)
            if (id)
                root.openProfile(id)
        }
    }
}
