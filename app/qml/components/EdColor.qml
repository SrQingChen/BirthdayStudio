import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs

Item {
    id: root

    property string value: "#ffffff"
    property bool invalid: false
    signal picked(string value)

    readonly property var ui: (theme.tokens && theme.tokens.ui) ? theme.tokens.ui : ({})
    readonly property color borderColor: ui.panelBorder || "#ffffff14"
    readonly property color accent: ui.accent || "#ffb08a"
    readonly property bool dark: !ui || ui.mode !== "light"

    implicitHeight: 34

    Rectangle {
        id: swatch
        width: 34
        height: 34
        radius: 8
        color: root.value || "#000000"
        border.width: 1
        border.color: root.dark ? Qt.rgba(1, 1, 1, 0.3) : Qt.rgba(0, 0, 0, 0.22)
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: picker.open()
        }
    }

    EdText {
        anchors.left: swatch.right
        anchors.leftMargin: 8
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: root.value
        invalid: root.invalid
        mono: true
        onEditingFinished: {
            var v = text.trim()
            if (/^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(v) || v === "")
                root.picked(v)
        }
    }

    ColorDialog {
        id: picker
        title: "选择颜色"
        selectedColor: root.value && /^#/.test(root.value) ? root.value : "#ffffff"
        onAccepted: {
            var c = selectedColor.toString()
            // Qt may return #AARRGGBB; convert if alpha is FF, keep otherwise
            root.picked(c)
        }
    }
}
