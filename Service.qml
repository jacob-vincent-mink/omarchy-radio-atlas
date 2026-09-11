import QtQuick
import Quickshell
import Quickshell.Io

// One player and status observer per plugin, shared by every bar placement.
Item {
  id: root
  property var shell: null
  required property var runtime
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
  readonly property string statusPath: runtime.runtimePath + "/omarchy-radio-atlas/status.json"

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
    if (actionJob) return
    actionJob = runtime.runLocal([root.playerPath, action], {onFinished: result => {
      actionJob = null
      if (result.exitCode === 0) statusReady = true
    }})
  }

  function changeVolume(delta) {
    var current = pendingVolume >= 0 ? pendingVolume : playerVolume
    pendingVolume = Math.max(0, Math.min(100, current + (delta > 0 ? 5 : -5)))
    playerVolume = pendingVolume
    flushVolume()
  }

  function flushVolume() {
    if (volumeJob || pendingVolume < 0) return
    submittedVolume = pendingVolume
    volumeJob = runtime.runLocal([playerPath, "volume", String(pendingVolume)], {onFinished: finishVolume})
  }

  FileView {
    path: root.statusReady ? root.statusPath : ""
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.applyPlayerState(text())
    onFileChanged: reload()
  }

  property var actionJob: null
  property var volumeJob: null
  property int submittedVolume: -1

  function finishVolume(result) {
    volumeJob = null
    const exitCode = result.status === "completed" ? result.exitCode : -1
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

  Component.onCompleted: {
    runtime.runLocal([playerPath, "session"], {onFinished: result => {
      sessionError = String(result.stderr || "").trim()
      if (result.exitCode !== 0 && !sessionError)
        sessionError = "Review playback and public proxy permissions."
    }})
    runtime.runLocal([playerPath, "status"], {onFinished: result => {
      if (result.exitCode === 0) statusReady = true
    }})
  }
}
