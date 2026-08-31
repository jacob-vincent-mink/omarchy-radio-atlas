import QtQuick
import QtQuick.Controls as QQC
import QtQml as Qml

Item {
  id: root
  width: button.width
  height: button.height
  property var inputRegions: [{x: 0, y: 0, width: width, height: height}]

  readonly property string mediaScope: '{"controls":["pause","stop","mute","volume","status"],"sourceCapabilities":["network.fetch"]}'
  property var mediaCall: null
  property bool playing: false
  property bool paused: false
  property bool muted: false
  property int volume: 70
  property int pendingVolume: -1
  property string playerTitle: ""
  property string statusText: "Radio Atlas"
  property bool runtimeStarted: false
  readonly property bool canControl:
    runtime.hasPermission("media.play-stream", "control")

  function control(action, value) {
    if (!canControl) {
      statusText = "Radio controls unavailable"
      return false
    }
    var payload = {control: action}
    if (action === "volume") payload.value = Math.max(0, Math.min(100, Math.round(Number(value))))
    mediaCall = runtime.invoke("media.play-stream", "control", {demandScope: mediaScope, payload: payload})
    return true
  }

  function applyPlayerState() {
    if (!mediaCall || !mediaCall.finished) return
    if (!mediaCall.ok) {
      statusText = "Radio unavailable"
      playing = false
      return
    }
    var state = ({})
    try { state = JSON.parse(mediaCall.utf8Text || "{}") } catch (error) {}
    playing = state.running === true
    paused = state.paused === true
    muted = state.muted === true
    if (state.volume !== undefined)
      volume = Math.max(0, Math.min(100, Math.round(Number(state.volume))))
    playerTitle = String(state.title || "").replace(/[\r\n\t]+/g, " ").slice(0, 160)
    statusText = playing
      ? (paused ? "Radio paused: " : "Playing: ") + (playerTitle || "Radio Atlas")
        + "  ·  " + (muted ? "muted" : volume + "%")
      : "Open Radio Atlas"
  }

  function changeVolume(delta) {
    var next = Math.max(0, Math.min(100, volume + (delta > 0 ? 5 : -5)))
    volume = next
    control("volume", next)
  }

  function startRuntime() {
    if (runtimeStarted || !runtime.brokerReady) return
    runtimeStarted = true
    control("status")
  }

  function open() { startRuntime() }

  Qml.Connections {
    target: runtime
    function onCallFinished(call) {
      if (call === root.mediaCall) root.applyPlayerState()
    }
    function onBrokerReadyChanged() { root.startRuntime() }
  }

  Qml.Component.onCompleted: root.startRuntime()

  Rectangle {
    id: button
    width: 44
    height: 36
    radius: 8
    color: pointer.containsMouse ? "#243142" : "transparent"
    border.color: pointer.containsMouse ? "#3b526c" : "transparent"
    opacity: !root.playing || root.paused ? 0.6 : 1

    QQC.ToolTip.visible: pointer.containsMouse
    QQC.ToolTip.text: root.statusText

    Text {
      anchors.centerIn: parent
      text: "\uf0ac"
      color: "#f2f4f8"
      font.pixelSize: 18
    }

    MouseArea {
      id: pointer
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
      onPressed: function(mouse) {
        if (mouse.button === Qt.RightButton) root.control("stop")
        else runtime.requestSurfaceIntent("atlas", "toggle")
      }
    }

    WheelHandler {
      enabled: root.canControl
      target: null
      onWheel: function(event) { root.changeVolume(event.angleDelta.y) }
    }
  }
}
