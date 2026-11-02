import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs

// One schema-bound form row. Reads from session.draft and writes via setField.
Column {
    id: root

    property string label: ""
    property string path: ""
    property string type: "text"
    property var options: []
    property real min: 0
    property real max: 100
    property real step: 1
    property string unit: ""
    property string assetKind: ""
    property string hint: ""
    property bool compact: false

    readonly property var current: readPath(session.draft, path)
    readonly property string sev: session.severityFor(path)
    readonly property string msg: {
        var issue = session.issueFor(path)
        return issue && issue.message ? issue.message : ""
    }
    readonly property color dangerColor: (theme.tokens && theme.tokens.ui && theme.tokens.ui.danger) ? theme.tokens.ui.danger : "#ff8a80"
    readonly property color warnColor: "#ffd166"
    readonly property color muted: (theme.tokens && theme.tokens.ui && theme.tokens.ui.textMuted) ? theme.tokens.ui.textMuted : "#b9a9b6"

    width: parent ? parent.width : 300
    spacing: 4

    function readPath(obj, path) {
        if (!obj || !path)
            return undefined
        var tokens = []
        var parts = String(path).split(".")
        for (var i = 0; i < parts.length; i++) {
            var part = parts[i]
            var m = part.match(/^([^\[]+)((?:\[\d+\])*)$/)
            if (!m) {
                tokens.push(part)
                continue
            }
            tokens.push(m[1])
            var idx = m[2].match(/\[\d+\]/g) || []
            for (var j = 0; j < idx.length; j++)
                tokens.push(parseInt(idx[j].substring(1, idx[j].length - 1)))
        }
        var cur = obj
        for (var k = 0; k < tokens.length; k++) {
            if (cur === null || cur === undefined)
                return undefined
            cur = cur[tokens[k]]
        }
        return cur
    }

    function writeValue(v) {
        if (path)
            session.setField(path, v)
    }

    Row {
        width: parent.width
        spacing: 8

        Item {
            width: 118
            height: 34
            Text {
                id: labelText
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 8
                text: root.label
                color: root.muted
                font.family: theme.hanFamily
                font.pixelSize: 12
                elide: Text.ElideRight
            }
            MouseArea {
                id: labelHover
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
            }
            ToolTip.visible: labelHover.containsMouse && root.label !== ""
            ToolTip.text: root.label
            ToolTip.delay: 600
        }

        Item {
            width: parent.width - 118 - 8 - 22
            height: root.type === "textarea" ? 88 : 34

            EdText {
                id: textInput
                anchors.fill: parent
                visible: root.type === "text"
                text: root.current === undefined ? "" : String(root.current)
                invalid: root.sev === "error"
                onTextEdited: liveTimer.restart()
                onEditingFinished: root.writeValue(text)
            }

            TextArea {
                id: areaInput
                anchors.fill: parent
                visible: root.type === "textarea"
                text: root.current === undefined ? "" : String(root.current)
                color: (theme.tokens && theme.tokens.ui && theme.tokens.ui.text) ? theme.tokens.ui.text : "#f5ede8"
                placeholderTextColor: root.muted
                font.family: theme.hanFamily
                font.pixelSize: 13
                wrapMode: TextEdit.Wrap
                selectByMouse: true
                leftPadding: 10
                rightPadding: 10
                topPadding: 8
                bottomPadding: 8
                onTextChanged: if (activeFocus) liveTimer.restart()
                background: Rectangle {
                    radius: 8
                    color: Qt.rgba(0, 0, 0, 0.14)
                    border.width: areaInput.activeFocus ? 1.5 : 1
                    border.color: areaInput.activeFocus
                                  ? ((theme.tokens && theme.tokens.ui && theme.tokens.ui.accent) || "#ffb08a")
                                  : ((theme.tokens && theme.tokens.ui && theme.tokens.ui.panelBorder) || "#ffffff14")
                }
            }

            EdText {
                id: numberInput
                anchors.fill: parent
                visible: root.type === "number"
                text: root.current === undefined ? "" : String(root.current)
                invalid: root.sev === "error"
                horizontalAlignment: TextInput.AlignRight
                validator: DoubleValidator { bottom: root.min; top: root.max; decimals: 2 }
                onEditingFinished: {
                    var v = parseFloat(text)
                    if (!isNaN(v))
                        root.writeValue(Math.max(root.min, Math.min(root.max, v)))
                }
            }

            Row {
                anchors.fill: parent
                visible: root.type === "slider"
                spacing: 8
                EdSlider {
                    width: parent.width - valueText.width - 8
                    anchors.verticalCenter: parent.verticalCenter
                    from: root.min
                    to: root.max
                    stepSize: root.step
                    value: root.current === undefined ? root.min : Number(root.current)
                    onMoved: root.writeValue(value)
                }
                Text {
                    id: valueText
                    anchors.verticalCenter: parent.verticalCenter
                    width: 42
                    text: (root.current === undefined ? "" : Number(root.current).toFixed(root.step >= 1 ? 0 : 2)) + root.unit
                    color: root.muted
                    font.family: theme.hanFamily
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignRight
                }
            }

            EdSwitch {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.type === "switch"
                checked: root.current === true
                onToggled: root.writeValue(checked)
            }

            EdColor {
                anchors.fill: parent
                visible: root.type === "color"
                value: root.current === undefined ? "#ffffff" : String(root.current)
                invalid: root.sev === "error"
                onPicked: function (v) { root.writeValue(v) }
            }

            EdCombo {
                anchors.fill: parent
                visible: root.type === "combo"
                value: root.current === undefined ? "" : String(root.current)
                options: root.options
                onPicked: function (v) { root.writeValue(v) }
            }

            Row {
                anchors.fill: parent
                visible: root.type === "path"
                spacing: 6
                EdText {
                    width: parent.width - 66
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.current === undefined ? "" : String(root.current)
                    onEditingFinished: root.writeValue(text)
                }
                EdButton {
                    width: 60
                    height: 32
                    text: "浏览"
                    small: true
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: filePicker.open()
                }
            }

            FileDialog {
                id: filePicker
                title: "选择素材"
                fileMode: FileDialog.OpenFile
                nameFilters: root.assetKind === "audio"
                             ? ["音频 (*.wav *.mp3 *.ogg *.flac)", "所有文件 (*)"]
                             : root.assetKind === "image"
                               ? ["图片 (*.png *.jpg *.jpeg *.webp)", "所有文件 (*)"]
                               : ["所有文件 (*)"]
                onAccepted: {
                    var rel = session.importAsset(selectedFile, root.assetKind || "other", "unknown")
                    if (rel !== "")
                        root.writeValue(rel)
                }
            }
        }

        Text {
            width: 14
            height: 34
            text: "↺"
            color: resetArea.containsMouse ? root.muted : Qt.rgba(0.7, 0.7, 0.7, 0.35)
            font.pixelSize: 13
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            MouseArea {
                id: resetArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: session.resetField(root.path)
            }
        }
    }

    Text {
        width: parent.width
        visible: root.msg !== ""
        text: root.msg
        color: root.sev === "error" ? root.dangerColor : root.warnColor
        font.family: theme.hanFamily
        font.pixelSize: 11
        wrapMode: Text.Wrap
        leftPadding: 126
    }

    Text {
        width: parent.width
        visible: root.hint !== "" && root.msg === ""
        text: root.hint
        color: root.muted
        opacity: 0.7
        font.family: theme.hanFamily
        font.pixelSize: 11
        wrapMode: Text.Wrap
        leftPadding: 126
    }

    Timer {
        id: liveTimer
        interval: 480
        onTriggered: {
            if (root.type === "textarea")
                root.writeValue(areaInput.text)
            else
                root.writeValue(textInput.text)
        }
    }

    Connections {
        target: session
        function onDraftChanged() {
            if (!textInput.activeFocus && root.type !== "textarea")
                textInput.text = root.current === undefined ? "" : String(root.current)
            if (!areaInput.activeFocus && root.type === "textarea")
                areaInput.text = root.current === undefined ? "" : String(root.current)
        }
    }
}
