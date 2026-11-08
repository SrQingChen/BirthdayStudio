import QtQuick
import QtQuick.Controls

ComboBox {
    id: root

    property string value: ""
    property var options: []   // [{value: "...", label: "..."}]
    signal picked(string value)

    readonly property var ui: (theme.tokens && theme.tokens.ui) ? theme.tokens.ui : ({})
    readonly property color ink: ui.text || "#f5ede8"
    readonly property color muted: ui.textMuted || "#b9a9b6"
    readonly property color accent: ui.accent || "#ffb08a"
    readonly property color borderColor: ui.panelBorder || "#ffffff14"
    readonly property bool dark: !ui || ui.mode !== "light"

    implicitHeight: 34
    font.family: theme.hanFamily
    font.pixelSize: 13
    model: options
    textRole: "label"
    valueRole: "value"

    // Keep the shown index in sync with `value`. A plain binding on
    // currentIndex breaks the first time ComboBox assigns it from user
    // interaction, so sync explicitly instead.
    function syncIndex() {
        for (var i = 0; i < options.length; i++) {
            if (options[i].value === root.value) {
                currentIndex = i
                return
            }
        }
        currentIndex = options.length ? 0 : -1
    }
    onValueChanged: syncIndex()
    onOptionsChanged: syncIndex()
    Component.onCompleted: syncIndex()

    onActivated: function (index) {
        if (index >= 0 && index < options.length)
            root.picked(options[index].value)
    }

    contentItem: Text {
        leftPadding: 10
        text: root.displayText
        color: root.ink
        font: root.font
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    indicator: Text {
        x: root.width - width - 10
        y: root.height / 2 - height / 2
        text: "▾"
        color: root.muted
        font.pixelSize: 12
    }

    background: Rectangle {
        radius: 8
        color: Qt.rgba(0, 0, 0, 0.14)
        border.width: root.activeFocus ? 1.5 : 1
        border.color: root.activeFocus ? root.accent : root.borderColor
    }

    popup: Popup {
        y: root.height + 4
        width: root.width
        implicitHeight: Math.min(280, contentItem.implicitHeight + 8)
        padding: 4

        background: Rectangle {
            radius: 10
            color: (theme.tokens && theme.tokens.ui && theme.tokens.ui.panel) ? theme.tokens.ui.panel : "#171020"
            border.width: 1
            border.color: root.borderColor
        }

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: root.popup.visible ? root.delegateModel : null
            currentIndex: root.highlightedIndex
            ScrollIndicator.vertical: ScrollIndicator { }
        }
    }

    delegate: ItemDelegate {
        width: root.width - 8
        height: 32
        text: (modelData && modelData.label !== undefined) ? modelData.label : modelData
        font.family: theme.hanFamily
        font.pixelSize: 13
        highlighted: root.highlightedIndex === index
        contentItem: Text {
            text: parent.text
            color: root.ink
            font: parent.font
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        background: Rectangle {
            radius: 6
            color: parent.highlighted
                   ? (root.dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.06))
                   : "transparent"
        }
        // Do NOT close the popup here. ComboBox closes it after emitting
        // `activated`; closing first tears down the delegate (the popup's
        // model is only bound while visible), so `activated` never runs and
        // the selection appears to be accepted but nothing is written back.
    }
}
