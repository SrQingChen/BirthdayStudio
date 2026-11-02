import QtQuick
import "../components"

ModalLayer {
    id: root
    title: "绘制祝福轨迹"
    subtitle: "按住鼠标拖动，卡片会沿着这条笔画依次出现"
    cardWidth: 780
    cardHeight: 600
    signal applied()

    property var points: []
    property string errorText: ""

    onOpenedChanged: {
        if (opened) {
            points = []
            errorText = ""
            canvas.requestPaint()
        }
    }

    Item {
        width: parent.width
        height: parent.height - 90

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: Qt.rgba(0, 0, 0, 0.18)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.12)
            clip: true

            Canvas {
                id: canvas
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    // grid
                    ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.06)
                    ctx.lineWidth = 1
                    for (var x = 0; x <= width; x += width / 8) {
                        ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height); ctx.stroke()
                    }
                    for (var y = 0; y <= height; y += height / 6) {
                        ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke()
                    }
                    if (root.points.length < 2)
                        return
                    var accent = (theme.tokens && theme.tokens.ui && theme.tokens.ui.accent) ? theme.tokens.ui.accent : "#ffb08a"
                    ctx.strokeStyle = accent
                    ctx.lineWidth = 3
                    ctx.lineCap = "round"
                    ctx.lineJoin = "round"
                    ctx.beginPath()
                    ctx.moveTo(root.points[0].x * width, root.points[0].y * height)
                    for (var i = 1; i < root.points.length; i++)
                        ctx.lineTo(root.points[i].x * width, root.points[i].y * height)
                    ctx.stroke()
                    ctx.fillStyle = "#fff5ee"
                    for (var j = 0; j < root.points.length; j += Math.max(1, Math.floor(root.points.length / 18))) {
                        var p = root.points[j]
                        ctx.beginPath()
                        ctx.arc(p.x * width, p.y * height, 4, 0, Math.PI * 2)
                        ctx.fill()
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                onPressed: function (mouse) {
                    root.points = [{ x: mouse.x / width, y: mouse.y / height }]
                    root.errorText = ""
                    canvas.requestPaint()
                }
                onPositionChanged: function (mouse) {
                    if (!pressed)
                        return
                    var p = { x: Math.max(0, Math.min(1, mouse.x / width)), y: Math.max(0, Math.min(1, mouse.y / height)) }
                    var arr = root.points.slice()
                    var last = arr[arr.length - 1]
                    if (!last || Math.abs(p.x - last.x) + Math.abs(p.y - last.y) > 0.012) {
                        arr.push(p)
                        root.points = arr
                        canvas.requestPaint()
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: root.points.length === 0
                text: "在这里画一条线"
                color: Qt.rgba(1, 1, 1, 0.35)
                font.family: theme.hanFamily
                font.pixelSize: 16
            }
        }
    }

    Row {
        width: parent.width
        spacing: 10
        EdButton { text: "清空"; onClicked: { root.points = []; canvas.requestPaint() } }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.errorText
            color: "#ff8a80"
            font.family: theme.hanFamily
            font.pixelSize: 11
        }
        Item { width: 1; height: 1 }
        EdButton {
            text: "使用这条轨迹"
            primary: true
            onClicked: {
                if (root.points.length < 3) {
                    root.errorText = "至少需要画出一小段轨迹"
                    return
                }
                var flat = []
                for (var i = 0; i < root.points.length; i++)
                    flat.push([root.points[i].x, root.points[i].y])
                session.setFields({
                    "acts.popups.trajectory.preset": "custom",
                    "acts.popups.trajectory.custom_points": flat
                })
                root.applied()
                root.close()
            }
        }
        EdButton { text: "取消"; onClicked: root.close() }
    }

    Text {
        width: parent.width
        text: "提示：轨迹坐标会按预览画布归一化保存，换分辨率也不会跑偏。"
        color: (theme.tokens && theme.tokens.ui && theme.tokens.ui.textMuted) || "#b9a9b6"
        font.family: theme.hanFamily
        font.pixelSize: 10
        opacity: 0.7
        wrapMode: Text.Wrap
    }
}
