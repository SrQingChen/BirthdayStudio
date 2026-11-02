import QtQuick
import QtQuick.Controls
import "../components"

ModalLayer {
    id: root
    title: "检测到未正常退出的编辑会话"
    subtitle: "自动保存已经兜底；你可以恢复到最后一个保存点，或挑一份快照"
    cardWidth: 700
    cardHeight: 500
    closeOnDim: false
    signal resolved(string profileId)

    property int candidateIndex: 0
    property var snapshots: []
    property int snapshotIndex: 0

    readonly property var candidates: app.crashCandidates || []
    readonly property var current: candidates.length > candidateIndex ? candidates[candidateIndex] : ({})

    onOpenedChanged: {
        if (opened) {
            candidateIndex = 0
            snapshotIndex = 0
            root.reloadSnapshots()
        }
    }

    function reloadSnapshots() {
        if (current && current.id)
            root.snapshots = library.snapshots(current.id)
        else
            root.snapshots = []
        snapshotIndex = 0
    }

    function resolve(action) {
        if (!current || !current.id)
            return
        var file = (action === "snapshot" && snapshots.length > snapshotIndex) ? snapshots[snapshotIndex].file : ""
        var id = library.resolveCrash(current.id, action, file)
        if (id) {
            app.clearCrashCandidate(current.id)
            root.resolved(id)
            root.close()
        }
    }

    Repeater {
        model: root.candidates
        Rectangle {
            width: parent.width
            height: 48
            radius: 9
            color: root.candidateIndex === index ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.12)
            border.width: 1
            border.color: root.candidateIndex === index
                          ? ((theme.tokens && theme.tokens.ui && theme.tokens.ui.accent) || "#ffb08a")
                          : Qt.rgba(1, 1, 1, 0.10)
            Column {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Text {
                    text: modelData.name || modelData.id || "配置档"
                    color: (theme.tokens && theme.tokens.ui && theme.tokens.ui.text) ? theme.tokens.ui.text : "#f5ede8"
                    font.family: theme.hanFamily
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
                Text {
                    text: "最后事件：" + (modelData.lastEvent || "未知")
                    color: (theme.tokens && theme.tokens.ui && theme.tokens.ui.textMuted) ? theme.tokens.ui.textMuted : "#b9a9b6"
                    font.family: theme.hanFamily
                    font.pixelSize: 10
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.candidateIndex = index
                    root.reloadSnapshots()
                }
            }
        }
    }

    Text {
        text: "快照历史"
        visible: root.snapshots.length > 0
        color: (theme.tokens && theme.tokens.ui && theme.tokens.ui.textMuted) ? theme.tokens.ui.textMuted : "#b9a9b6"
        font.family: theme.hanFamily
        font.pixelSize: 11
    }

    ScrollView {
        width: parent.width
        height: Math.min(140, Math.max(60, root.snapshots.length * 30))
        visible: root.snapshots.length > 0
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        Column {
            width: parent.width
            spacing: 4
            Repeater {
                model: root.snapshots
                Rectangle {
                    width: parent.width
                    height: 28
                    radius: 7
                    color: root.snapshotIndex === index ? Qt.rgba(1, 1, 1, 0.10) : "transparent"
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.time + "  ·  " + modelData.summary
                        color: (theme.tokens && theme.tokens.ui && theme.tokens.ui.text) ? theme.tokens.ui.text : "#f5ede8"
                        font.family: theme.hanFamily
                        font.pixelSize: 10
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.snapshotIndex = index
                    }
                }
            }
        }
    }

    Text {
        width: parent.width
        text: "恢复会以最后一次自动保存为准；快照恢复会用所选快照覆盖当前配置档。"
        color: (theme.tokens && theme.tokens.ui && theme.tokens.ui.textMuted) ? theme.tokens.ui.textMuted : "#b9a9b6"
        font.family: theme.hanFamily
        font.pixelSize: 10
        wrapMode: Text.Wrap
        opacity: 0.75
    }

    Row {
        width: parent.width
        spacing: 10
        EdButton {
            text: "恢复并继续"
            primary: true
            onClicked: root.resolve("resume")
        }
        EdButton {
            text: "从所选快照恢复"
            enabled: root.snapshots.length > 0
            onClicked: root.resolve("snapshot")
        }
        EdButton {
            text: "放弃未保存更改"
            danger: true
            onClicked: root.resolve("discard")
        }
    }
}
