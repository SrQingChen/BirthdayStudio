import QtQuick
import QtQuick.Controls

Row {
    id: root
    property string label: ""
    property bool on: false
    signal toggled(bool value)
    width: parent ? parent.width : 240
    spacing: 8
    height: 32
    Text {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 54
        text: root.label
        color: (theme.tokens && theme.tokens.ui && theme.tokens.ui.text) ? theme.tokens.ui.text : "#f5ede8"
        font.family: theme.hanFamily
        font.pixelSize: 12
        elide: Text.ElideRight
    }
    EdSwitch {
        anchors.verticalCenter: parent.verticalCenter
        checked: root.on
        onToggled: root.toggled(checked)
    }
}
