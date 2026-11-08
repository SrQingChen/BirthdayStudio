import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Dialogs
import "components"
import "overlays"
import "editor"

Item {
    id: editor
    anchors.fill: parent

    property string selectedAct: "intro"
    property int leftWidth: 268
    property int rightWidth: 348
    property int timelineHeight: 220
    property bool previewLowMotion: false
    property bool previewHighContrast: false
    property bool previewSlowmo: false
    property bool previewMuted: false
    property bool previewAudit: false
    property string previewResolution: "1080p"
    property int previewZoom: 100
    property string confirmAction: ""
    property string confirmProfileId: ""
    property string bbpProfileId: ""

    readonly property var ui: (theme.tokens && theme.tokens.ui) ? theme.tokens.ui : ({})
    readonly property color panelColor: ui.panel || "#171020"
    readonly property color borderColor: ui.panelBorder || "#ffffff14"

    function clamp(v, lo, hi) {
        return Math.max(lo, Math.min(hi, v))
    }

    function queuePreviewSave() {
        previewSave.restart()
    }

    function openSnapshots(id, name) {
        snapshotsDialog.profileId = id
        snapshotsDialog.profileName = name
        snapshotsDialog.opened = true
    }

    function openConfirm(action, id, message, label) {
        editor.confirmAction = action
        editor.confirmProfileId = id
        confirmDialog.message = message
        confirmDialog.confirmText = label || "确认"
        confirmDialog.opened = true
    }

    Rectangle { anchors.fill: parent; color: editor.panelColor }

    TopBar {
        id: topBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 54
        hasProfile: session.profileId !== ""
        playing: preview.running
        onNewProfile: newDialog.opened = true
        onPlayAll: preview.startAll()
        onPlayAct: preview.startAct()
        onStop: preview.stop()
        onExportRequested: exportDialog.opened = true
        onPluginsRequested: pluginDialog.opened = true
        onSettingsRequested: settingsDialog.opened = true
        onSnapshotsRequested: editor.openSnapshots(session.profileId, session.draft.meta ? session.draft.meta.name : "")
        onWizardRequested: { preview.stop(); wizard.opened = true }
    }

    Item {
        id: middle
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: topBar.bottom
        anchors.bottom: timelineBar.top

        ProfileLibrary {
            id: profileLibrary
            width: editor.leftWidth
            height: parent.height
            currentId: session.profileId
            onOpenProfile: function (id) {
                preview.stop()
                session.openProfile(id)
            }
            onNewProfile: newDialog.opened = true
            onTrashRequested: trashDialog.opened = true
            onCardAction: function (action, id) {
                if (action === "duplicate") {
                    var newId = library.duplicateProfile(id)
                    if (newId)
                        session.openProfile(newId)
                } else if (action === "export") {
                    editor.bbpProfileId = id
                    bbpDialog.open()
                } else if (action === "snapshots") {
                    var name = ""
                    for (var i = 0; i < library.profiles.length; i++)
                        if (library.profiles[i].id === id) name = library.profiles[i].name
                    editor.openSnapshots(id, name)
                } else if (action === "reveal") {
                    app.openPath(app.homeDir + "/profiles/" + id)
                } else if (action === "delete") {
                    editor.openConfirm("delete", id, "将把配置档移入回收站，保留 30 天可恢复。", "移入回收站")
                }
            }
        }

        // left splitter
        MouseArea {
            id: leftSplit
            x: editor.leftWidth - 2
            width: 5
            height: parent.height
            cursorShape: Qt.SplitHCursor
            property real startGlobal: 0
            property real startWidth: 0
            onPressed: function (mouse) {
                startGlobal = mapToItem(editor, mouse.x, mouse.y).x
                startWidth = editor.leftWidth
            }
            onPositionChanged: function (mouse) {
                if (!pressed)
                    return
                var gx = mapToItem(editor, mouse.x, mouse.y).x
                editor.leftWidth = editor.clamp(startWidth + gx - startGlobal, 220, 430)
            }
            onReleased: app.saveLayout(editor.leftWidth, editor.rightWidth, editor.timelineHeight)
        }

        PreviewStage {
            id: preview
            x: editor.leftWidth + 3
            width: Math.max(360, parent.width - editor.leftWidth - editor.rightWidth - 6)
            height: parent.height
            hasProfile: session.profileId !== ""
            selectedAct: editor.selectedAct
            onNewRequested: newDialog.opened = true
            onImportRequested: profileLibrary.openImport()
            onToast: function (message) { toast.show(message) }

            onLowMotionChanged: { editor.previewLowMotion = lowMotion; editor.queuePreviewSave() }
            onHighContrastChanged: { editor.previewHighContrast = highContrast; editor.queuePreviewSave() }
            onSlowmoChanged: { editor.previewSlowmo = slowmo; editor.queuePreviewSave() }
            onMutedChanged: { editor.previewMuted = muted; editor.queuePreviewSave(); audioBridge.setMuted(muted) }
            onAuditChanged: { editor.previewAudit = audit; editor.queuePreviewSave() }
            onResolutionChanged: { editor.previewResolution = resolution; editor.queuePreviewSave() }
            onZoomChanged: { editor.previewZoom = zoom; editor.queuePreviewSave() }
        }

        // right splitter
        MouseArea {
            id: rightSplit
            x: parent.width - editor.rightWidth - 2
            width: 5
            height: parent.height
            cursorShape: Qt.SplitHCursor
            property real startGlobal: 0
            property real startWidth: 0
            onPressed: function (mouse) {
                startGlobal = mapToItem(editor, mouse.x, mouse.y).x
                startWidth = editor.rightWidth
            }
            onPositionChanged: function (mouse) {
                if (!pressed)
                    return
                var gx = mapToItem(editor, mouse.x, mouse.y).x
                editor.rightWidth = editor.clamp(startWidth - (gx - startGlobal), 300, 540)
            }
            onReleased: app.saveLayout(editor.leftWidth, editor.rightWidth, editor.timelineHeight)
        }

        Rectangle {
            x: parent.width - editor.rightWidth
            width: 1
            height: parent.height
            color: editor.borderColor
        }

        InspectorPane {
            id: inspector
            x: parent.width - editor.rightWidth
            width: editor.rightWidth
            height: parent.height
            selectedAct: editor.selectedAct
            onActSelected: function (id) { editor.selectedAct = id }
            onToast: function (message) { toast.show(message) }
            onPlayFrom: function (id) { editor.selectedAct = id; preview.startAct() }
            onDrawTrajectory: trajectoryDialog.opened = true
        }
    }

    // timeline splitter
    Item {
        id: timelineBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: timelinePanel.top
        height: 5

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.SplitVCursor
            property real startGlobal: 0
            property real startHeight: 0
            onPressed: function (mouse) {
                startGlobal = mapToItem(editor, mouse.x, mouse.y).y
                startHeight = editor.timelineHeight
            }
            onPositionChanged: function (mouse) {
                if (!pressed)
                    return
                var gy = mapToItem(editor, mouse.x, mouse.y).y
                editor.timelineHeight = editor.clamp(startHeight - (gy - startGlobal), 150, 380)
            }
            onReleased: app.saveLayout(editor.leftWidth, editor.rightWidth, editor.timelineHeight)
        }
    }

    TimelinePanel {
        id: timelinePanel
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: editor.timelineHeight
        selectedAct: editor.selectedAct
        playingAct: preview.playingAct
        playing: preview.running
        onSelectAct: function (id) { editor.selectedAct = id }
        onPlayFrom: function (id) { editor.selectedAct = id; preview.startAct() }
    }

    Toast {
        id: toast
    }

    // ------------------------------------------------------------------ //
    // Dialogs
    // ------------------------------------------------------------------ //
    NewProfileDialog {
        id: newDialog
        onCreated: function (id) {
            session.openProfile(id)
            editor.selectedAct = "intro"
            toast.show("配置档已创建")
        }
    }

    RecoveryDialog {
        id: recovery
        onResolved: function (id) {
            session.openProfile(id)
            var ctx = session.context || ({})
            editor.selectedAct = ctx.act || "intro"
            toast.show("已恢复编辑会话")
        }
    }

    ExportDialog {
        id: exportDialog
        onExported: function (path) { toast.show("导出完成：" + path) }
    }

    PluginDialog {
        id: pluginDialog
    }

    SettingsDialog {
        id: settingsDialog
    }

    SnapshotsDialog {
        id: snapshotsDialog
        onRestored: function (id) {
            session.openProfile(id)
            toast.show("已从快照恢复")
        }
    }

    TrashDialog {
        id: trashDialog
        onRestored: function (id) {
            session.openProfile(id)
            toast.show("已从回收站恢复")
        }
    }

    ConfirmDialog {
        id: confirmDialog
        onConfirmed: {
            if (editor.confirmAction === "delete") {
                if (session.profileId === editor.confirmProfileId) {
                    preview.stop()
                    session.closeSession()
                }
                library.deleteProfile(editor.confirmProfileId)
                toast.show("已移入回收站（保留 30 天）")
            }
        }
    }

    TrajectoryDialog {
        id: trajectoryDialog
        onApplied: toast.show("轨迹已应用")
    }

    WizardDialog {
        id: wizard
        onCreated: function (id) {
            editor.selectedAct = "intro"
            toast.show("开始制作这场仪式")
        }
        onPlayRequested: {
            wizard.opened = false
            preview.startAll()
        }
        onExportRequested: {
            wizard.opened = false
            exportDialog.opened = true
        }
    }

    FileDialog {
        id: bbpDialog
        title: "导出配置档包"
        fileMode: FileDialog.SaveFile
        defaultSuffix: "bbp"
        nameFilters: ["BirthdayStudio 配置包 (*.bbp)"]
        onAccepted: {
            if (editor.bbpProfileId !== "")
                library.exportBbp(editor.bbpProfileId, selectedFile)
        }
    }

    Timer {
        id: previewSave
        interval: 450
        onTriggered: app.savePreviewSettings(
                         preview.resolution,
                         preview.zoom,
                         "dark",
                         preview.slowmo,
                         preview.muted,
                         preview.audit,
                         preview.lowMotion)
    }

    Shortcut { sequence: "Ctrl+S"; onActivated: session.forceSave() }
    Shortcut { sequence: "F5"; onActivated: preview.startAll() }
    Shortcut { sequence: "F6"; onActivated: preview.startAct() }
    Shortcut { sequence: "Ctrl+E"; onActivated: if (session.canExport) exportDialog.opened = true }
    Shortcut { sequence: "Escape"; onActivated: if (preview.running) preview.stop() }

    Connections {
        target: session
        function onOpened(profileId) {
            var ctx = session.context || ({})
            editor.selectedAct = ctx.act || "intro"
            showBridge.setProfileDir(session.profileDir)
            showBridge.setPluginIds(session.draft.plugins || [])
        }
        function onToast(message) { toast.show(message) }
    }

    Connections {
        target: library
        function onToast(message) { toast.show(message) }
    }
    Connections {
        target: plugins
        function onToast(message) { toast.show(message) }
    }
    Connections {
        target: audioBridge
        function onToast(message) { toast.show(message) }
    }

    onSelectedActChanged: {
        session.setContext({
            "act": editor.selectedAct,
            "selection": "",
            "playhead": 0,
            "scroll": 0
        })
    }

    Component.onCompleted: {
        var layout = app.layout || ({})
        leftWidth = layout.left_width || 268
        rightWidth = layout.right_width || 348
        timelineHeight = layout.timeline_height || 220

        var ps = app.previewSettings || ({})
        // Sanitize persisted values: a corrupted/legacy entry (e.g. zoom: 1)
        // must never shrink the preview stage to an invisible dot.
        previewResolution = ["1080p", "1440p", "4K"].indexOf(ps.resolution) >= 0 ? ps.resolution : "1080p"
        var restoredZoom = parseInt(ps.zoom)
        previewZoom = (restoredZoom >= 50 && restoredZoom <= 200) ? restoredZoom : 100
        if (ps.resolution !== previewResolution || parseInt(ps.zoom) !== previewZoom)
            editor.queuePreviewSave()   // self-heal the stored settings
        previewLowMotion = ps.reduced_motion === true
        previewHighContrast = false
        previewSlowmo = ps.slowmo === true
        previewMuted = ps.muted === true
        previewAudit = ps.audit_overlay === true
        preview.lowMotion = previewLowMotion
        preview.highContrast = previewHighContrast
        preview.slowmo = previewSlowmo
        preview.audit = previewAudit
        preview.resolution = previewResolution
        preview.zoom = previewZoom
        preview.muted = previewMuted
        audioBridge.setMuted(previewMuted)

        if (app.devDialog !== "")
            devDialogTimer.start()
        if (app.devAutoplay)
            autoplayTimer.start()

        // V1.1.0 fix #1: opening a fullscreen modal (recovery / wizard /
        // new-profile) during component completion — before the window has
        // rendered its first frames — permanently breaks Qt Quick 3D
        // compositing in this window on Qt 6.11 (the preview cake then never
        // renders for the whole session). Defer the startup plan until the
        // scene graph has settled.
        startupPlanTimer.start()
    }

    // V1.1.0 fix #1 (robust arm): the startup plan may open a fullscreen
    // modal (crash recovery / wizard / new-profile). Opening one before the
    // window has rendered permanently breaks Qt Quick 3D compositing on
    // Qt 6.11, so arm the timer only after the first real frame.
    property bool sawFirstFrame: false
    Connections {
        // Resolve the attached window through the editor Item — a bare
        // `Window.window` inside a non-Item Connections scope does not
        // resolve (acceptance finding #1).
        target: editor.Window.window
        enabled: !editor.sawFirstFrame
        function onAfterAnimating() {
            editor.sawFirstFrame = true
            startupPlanTimer.restart()
        }
    }
    Timer {
        id: startupPlanTimer
        interval: 500
        onTriggered: {
            var plan = app.startupPlan
            if (plan.action === "recovery") {
                recovery.opened = true
            } else if (plan.action === "open") {
                session.openProfile(plan.profileId)
            } else if (library.profiles.length === 0) {
                if (app.editorMode === "wizard")
                    wizard.opened = true
                else
                    newDialog.opened = true
            }
        }
    }

    function openDevDialog(name) {
        if (name === "new") newDialog.opened = true
        else if (name === "export") exportDialog.opened = true
        else if (name === "plugins") pluginDialog.opened = true
        else if (name === "settings") settingsDialog.opened = true
        else if (name === "wizard") wizard.opened = true
        else if (name === "snapshots") editor.openSnapshots(session.profileId, session.draft.meta ? session.draft.meta.name : "")
        else if (name === "trash") trashDialog.opened = true
        else if (name === "recovery") recovery.opened = true
        else if (name === "confirm") editor.openConfirm("delete", session.profileId, "这是一条开发预览用的确认文案。", "移入回收站")
    }

    Timer {
        id: devDialogTimer
        interval: 700
        onTriggered: editor.openDevDialog(app.devDialog)
    }

    Timer {
        id: autoplayTimer
        interval: 1400
        onTriggered: if (session.profileId !== "") preview.startAll()
    }

    Component.onDestruction: {
        preview.stop()
    }
}
