import QtQuick
import QtQml as Qml
import Omarchy.PluginPresentation 1.0 as P

P.BarWidget {
  id: root
  moduleName: "akshar.radio-atlas"
  width: button.width
  height: button.height

  readonly property string mediaScope: '{"controls":["pause","stop","mute","volume","status"],"sourceHandles":["network.fetch"]}'
  property var mediaCall: null
  property bool playing: false
  property bool paused: false
  property bool muted: false
  property int volume: 70
  property int pendingVolume: -1
  property string playerTitle: ""
  property string statusText: "Radio Atlas"
  signal openRequested(string action)

  function control(action, value) {
    var payload = {control: action}
    if (action === "volume") payload.value = Math.max(0, Math.min(100, Math.round(Number(value))))
    mediaCall = runtime.invoke("control", {demandScope: mediaScope, payload: payload})
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

  Qml.Connections {
    target: root.mediaCall
    function onFinishedChanged() {
      if (!root.mediaCall || !root.mediaCall.finished) return
      root.applyPlayerState()
    }
  }

  Qml.Component.onCompleted: root.control("status")

  P.WidgetButton {
    id: button
    width: 44
    height: 36
    tooltipText: root.statusText
    dimmed: !root.playing || root.paused

    Text {
      anchors.centerIn: parent
      text: "\uf0ac"
      color: P.Color.foreground
      font.family: P.Style.font.family
      font.pixelSize: P.Style.font.icon
    }

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.control("stop")
      else root.openRequested(buttonCode === Qt.MiddleButton ? "random" : "toggle")
    }

    WheelHandler {
      target: null
      onWheel: function(event) { root.changeVolume(event.angleDelta.y) }
    }
  }
}
