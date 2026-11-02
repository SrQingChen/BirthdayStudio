import QtQuick
import QtQuick.Controls
import "../components"

ModalLayer {
    id: root
    title: "快照历史"
    subtitle: "每 5 分钟且有实质改动时自动快照，滚动保留最近 10 份"
    cardWidth: 680
    cardHeight: 520
    signal restored(string profileId)

    property string profileId: ""
    property string profileName: ""
    property var snapshots: []
    property int selectedIndex: 0

    onOpenedChanged: {
        if (opened) {
            selectedIndex = 0
            root.snapshots = profileId !== "" ? library.snapshots(profileId) : []
        }
    }

    Text {
        width: parent.width
        text: root.profileName || root.profileId
        color: (theme.tokens && theme.tokens.ui && theme.tokens.ui.text) || "#f5ede8"
        font.family: theme.hanFamily
        font.pixelSize: 13
        font.weight: Font.DemiBold
    }

    ScrollView {
        width: parent.width
        height: parent.height - 150
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        Column {
            width: parent.width
            spacing: 6
            Repeater {
                model: root.snapshots
                Rectangle {
                    width: parent.width
                    height: 54
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
                        spacing: 3
                        Text {
                            text: modelData.time
                            color: (theme.tokens && theme.tokens.ui && theme.tokens.ui.text) || "#f5ede8"
                            font.family: "Consolas"
                            font.pixelSize: 11
                        }
                        Text {
                            text: modelData.summary
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
                visible: root.snapshots.length === 0
                text: "还没有快照。继续编辑至少 5 分钟会自动生成第一份。"
                color: (theme.tokens && theme.tokens.ui && theme.tokens.ui.textMuted) || "#b9a9b6"
                font.family: theme.hanFamily
                font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
                opacity: 0.7
            }
        }
    }

    Text {
        width: parent.width
        text: "恢复会覆盖当前配置档的内容，并自动写入一次保存点。"
        color: "#ffd166"
        font.family: theme.hanFamily
        font.pixelSize: 10
        opacity: 0.85
        wrapMode: Text.Wrap
    }

    Row {
        width: parent.width
        spacing: 10
        EdButton {
            text: "恢复到这份快照"
            primary: true
            enabled: root.snapshots.length > 0
            onClicked: {
                if (root.snapshots.length <= root.selectedIndex)
                    return
                if (session.profileId !== root.profileId)
                    session.openProfile(root.profileId)
                var ok = session.restoreSnapshot(root.snapshots[root.selectedIndex].file)
                if (ok) {
                    root.restored(root.profileId)
                    root.close()
                }
            }
        }
        EdButton {
            text: "打开快照目录"
            enabled: root.profileId !== ""
            onClicked: app.openPath(app.homeDir + "/profiles/" + root.profileId + "/snapshots")
        }
        EdButton { text: "关闭"; onClicked: root.close() }
    }
}
