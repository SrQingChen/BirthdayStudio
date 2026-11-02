import QtQuick
import QtQuick.Controls
import "../components"

ModalLayer {
    id: root
    title: "回收站"
    subtitle: "删除的配置档在这里保留 30 天，过期自动清理"
    cardWidth: 660
    cardHeight: 500
    signal restored(string profileId)

    property var items: []
    property int selectedIndex: 0
    property bool confirmEmpty: false

    function reload() {
        root.items = library.trash || []
        selectedIndex = 0
    }

    onOpenedChanged: if (opened) reload()

    ScrollView {
        width: parent.width
        height: parent.height - 110
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        Column {
            width: parent.width
            spacing: 6
            Repeater {
                model: root.items
                Rectangle {
                    width: parent.width
                    height: 48
                    radius: 9
                    color: root.selectedIndex === index ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.12)
                    border.width: 1
                    border.color: root.selectedIndex === index
                                  ? ((theme.tokens && theme.tokens.ui && theme.tokens.ui.accent) || "#ffb08a")
                                  : Qt.rgba(1, 1, 1, 0.08)
                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text {
                            text: modelData.name || modelData.id
                            color: (theme.tokens && theme.tokens.ui && theme.tokens.ui.text) || "#f5ede8"
                            font.family: theme.hanFamily
                            font.pixelSize: 12
                        }
                        Text {
                            text: "删除于 " + (modelData.deletedAt || "")
                            color: (theme.tokens && theme.tokens.ui && theme.tokens.ui.textMuted) || "#b9a9b6"
                            font.family: theme.hanFamily
                            font.pixelSize: 10
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectedIndex = index
                    }
                }
            }
            Text {
                width: parent.width
                visible: root.items.length === 0
                text: "回收站是空的"
                color: (theme.tokens && theme.tokens.ui && theme.tokens.ui.textMuted) || "#b9a9b6"
                font.family: theme.hanFamily
                font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
                opacity: 0.7
            }
        }
    }

    Row {
        width: parent.width
        spacing: 10
        EdButton {
            text: "恢复所选配置档"
            primary: true
            enabled: root.items.length > 0
            onClicked: {
                if (root.items.length <= root.selectedIndex)
                    return
                var id = library.restoreTrash(root.items[root.selectedIndex].trashDir)
                if (id) {
                    root.reload()
                    root.restored(id)
                }
            }
        }
        EdButton {
            text: root.confirmEmpty ? "确认清空？" : "清空回收站"
            danger: true
            enabled: root.items.length > 0
            onClicked: {
                if (!root.confirmEmpty) {
                    root.confirmEmpty = true
                    confirmTimer.restart()
                } else {
                    library.emptyTrash()
                    root.confirmEmpty = false
                    root.reload()
                }
            }
        }
        EdButton { text: "关闭"; onClicked: root.close() }
    }

    Timer {
        id: confirmTimer
        interval: 4000
        onTriggered: root.confirmEmpty = false
    }
}
