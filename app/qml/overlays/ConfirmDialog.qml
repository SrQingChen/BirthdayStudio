import QtQuick
import "../components"

ModalLayer {
    id: root
    title: "请确认"
    subtitle: ""
    cardWidth: 460
    cardHeight: 230
    signal confirmed()

    property string message: ""
    property string confirmText: "确认"
    property string cancelText: "取消"

    Text {
        width: parent.width
        text: root.message
        color: (theme.tokens && theme.tokens.ui && theme.tokens.ui.text) || "#f5ede8"
        font.family: theme.hanFamily
        font.pixelSize: 13
        wrapMode: Text.Wrap
        lineHeight: 1.5
    }

    Row {
        width: parent.width
        spacing: 10
        EdButton {
            text: root.confirmText
            danger: true
            onClicked: {
                root.confirmed()
                root.close()
            }
        }
        EdButton { text: root.cancelText; onClicked: root.close() }
    }
}
