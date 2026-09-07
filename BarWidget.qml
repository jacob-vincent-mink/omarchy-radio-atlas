import QtQuick
import Omarchy.PluginPresentation 1.0

Item {
  id: root

  property var inputRegions: [{x: 0, y: 0, width: width, height: height}]

  property bool playerRunning: false
  property bool playerPaused: false
  property string streamError: ""
  property bool playerMuted: false
  property int playerVolume: 70
  property int reportedVolume: 70
  property int pendingVolume: -1
  property string playerTitle: ""
  property bool statusReady: false
  readonly property bool canPlay: runtime.hasPermission("media.play-stream", "play")
  readonly property bool canControl: runtime.hasPermission("media.play-stream", "control")
  readonly property string playerPath: Qt.resolvedUrl("radio-player").toString().replace(/^file:\/\//, "")
  readonly property string statusPath: "radio-status"

  function singleLineText(value, limit) {
    return String(value || "").replace(/[\r\n\t]+/g, " ").slice(0, limit)
  }

  function safeTooltipText(value) {
    return root.singleLineText(value, 160).replace(/</g, "‹").replace(/>/g, "›")
  }

  function applyPlayerState(raw) {
    try {
      if (typeof raw !== "string" || raw.length > 65536) return
      var state = JSON.parse(raw || "{}")
      root.playerRunning = state.running === true
      root.playerPaused = state.paused === true
      root.streamError = root.singleLineText(state.error || "", 200)
      root.playerMuted = state.muted === true
      var nextVolume = Math.round(Number(state.volume === undefined ? 70 : state.volume))
      root.reportedVolume = isFinite(nextVolume)
        ? Math.max(0, Math.min(100, nextVolume)) : 70
      if (root.pendingVolume < 0) root.playerVolume = root.reportedVolume
      root.playerTitle = root.singleLineText(
        state.title || (state.station && state.station.name) || "", 160)
    } catch (error) {
      return
    }
  }

  function runPlayerAction(action) {
    if (!canControl) return
    if (actionProcess.running) return
    actionProcess.command = [root.playerPath, action]
    actionProcess.running = true
  }

  function changeVolume(delta) {
    if (!canControl) return
    var current = pendingVolume >= 0 ? pendingVolume : playerVolume
    pendingVolume = Math.max(0, Math.min(100, current + (delta > 0 ? 5 : -5)))
    playerVolume = pendingVolume
    flushVolume()
  }

  function flushVolume() {
    if (volumeProcess.running || pendingVolume < 0) return
    volumeProcess.submittedVolume = pendingVolume
    volumeProcess.command = [playerPath, "volume", String(pendingVolume)]
    volumeProcess.running = true
  }

  implicitWidth: Style.bar.statusSlot
  implicitHeight: Style.bar.size

  RadioFileView {
    path: root.statusReady ? root.statusPath : ""
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.applyPlayerState(text())
    onFileChanged: reload()
  }

  RadioProcess {
    id: statusInitProcess
    command: []
    onExited: function(exitCode) {
      if (exitCode === 0) root.statusReady = true
    }
  }

  RadioProcess {
    id: actionProcess
    command: []
    onExited: function(exitCode) {
      if (exitCode === 0) root.statusReady = true
    }
  }

  RadioProcess {
    id: volumeProcess
    property int submittedVolume: -1
    command: []
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        if (root.pendingVolume === submittedVolume) {
          root.pendingVolume = -1
          root.playerVolume = root.reportedVolume
        } else {
          Qt.callLater(root.flushVolume)
        }
        return
      }

      root.statusReady = true
      root.reportedVolume = submittedVolume
      if (root.pendingVolume === submittedVolume) {
        root.pendingVolume = -1
        root.playerVolume = submittedVolume
        return
      }
      Qt.callLater(root.flushVolume)
    }
  }

  Component.onCompleted: {
    statusInitProcess.command = [playerPath, "status"]
    statusInitProcess.running = true
  }

  Rectangle {
    id: button
    anchors.fill: parent
    color: "transparent"
    opacity: root.canPlay && root.playerRunning && !root.playerPaused ? 1 : 0.6
    property string tooltipText: root.playerRunning
      ? (root.streamError ? root.streamError + ": " : root.playerPaused ? "Radio paused: " : "Playing: ")
        + root.safeTooltipText(root.playerTitle)
        + "  ·  " + (root.playerMuted ? "muted" : root.playerVolume + "%")
      : "Open Radio Atlas"

    Text {
      anchors.centerIn: parent
      text: "\uf0ac"
      color: Color.bar.text
      font.family: Style.font.family
      font.pixelSize: Style.font.icon
    }

    MouseArea {
      id: pointer
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
      onPressed: function(mouse) {
        if (mouse.button === Qt.RightButton) root.runPlayerAction("stop")
        else runtime.requestSurfaceIntent("atlas", "toggle")
      }
    }

    WheelHandler {
      target: null
      enabled: root.canControl
      onWheel: function(event) { root.changeVolume(event.angleDelta.y) }
    }

    ToolTip {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.top
      text: button.tooltipText
      shown: pointer.containsMouse
    }
  }
}
