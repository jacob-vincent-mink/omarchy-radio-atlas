import QtQuick

QtObject {
  property string path: ""
  property bool preload: true
  property bool watchChanges: false
  property bool blockWrites: false
  property bool atomicWrites: false
  property bool printErrors: false
  property string contents: ""
  signal loaded()
  signal fileChanged()
  signal saveFailed()

  function text() { return contents }
  function setText(value) {
    contents = String(value || "")
    if (path.indexOf("play-selection.json") >= 0) RadioSessionState.playSelection = contents
    else if (path.indexOf("favorite-selection.json") >= 0) RadioSessionState.favoriteSelection = contents
  }
  function reload() { load() }
  function statusChanged() {
    if (path.indexOf("status") >= 0) fileChanged()
  }
  function load() {
    if (path.indexOf("status.json") >= 0)
      contents = RadioSessionState.playerStatus
    else if (path === "radio-status")
      contents = RadioSessionState.playerStatus
    loaded()
  }
  Component.onCompleted: {
    RadioSessionState.statusRevisionChanged.connect(statusChanged)
    if (preload && path) load()
  }
  Component.onDestruction: RadioSessionState.statusRevisionChanged.disconnect(statusChanged)
  onPathChanged: if (preload && path) load()
}
