import QtQuick
import Quickshell
import Quickshell.Io
import qs.Plugin as Plugin

// One player and status observer per plugin, shared by every bar placement.
Item {
  id: root
  property var shell: null
  readonly property var runtime: shell?.runtime || null
  property var manifest: null
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property string playerState: "{}"
  property string sessionError: ""

  property bool playerRunning: false
  property bool playerPaused: false
  property bool playerMuted: false
  property int playerVolume: 70
  property int reportedVolume: 70
  property int pendingVolume: -1
  property string playerTitle: ""
  property bool statusReady: false
  readonly property string playerPath: Qt.resolvedUrl("radio-control").toString().replace(/^file:\/\//, "")
  readonly property string statusPath: runtime ? runtime.runtimePath + "/omarchy-radio-atlas/status.json" : ""

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
      root.playerState = raw
      root.playerRunning = state.running === true
      root.playerPaused = state.paused === true
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
    if (actionProcess.running) return
    actionProcess.command = [root.playerPath, action]
    actionProcess.running = true
  }

  function changeVolume(delta) {
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

  FileView {
    path: root.statusReady ? root.statusPath : ""
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.applyPlayerState(text())
    onFileChanged: reload()
  }

  Plugin.Process {
    id: sessionProcess
    runtime: root.runtime
    command: [root.playerPath, "session"]
    running: true
    stderr: StdioCollector { onStreamFinished: root.sessionError = text.trim() }
    onExited: function(code) { if (code !== 0 && !root.sessionError) root.sessionError = "Review playback and public proxy permissions." }
  }

  Plugin.Process {
    id: statusInitProcess
    runtime: root.runtime
    command: []
    onExited: function(exitCode) {
      if (exitCode === 0) root.statusReady = true
    }
  }

  Plugin.Process {
    id: actionProcess
    runtime: root.runtime
    command: []
    onExited: function(exitCode) {
      if (exitCode === 0) root.statusReady = true
    }
  }

  Plugin.Process {
    id: volumeProcess
    runtime: root.runtime
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

}
