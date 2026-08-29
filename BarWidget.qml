import QtQuick
import QtQml as Qml

Item {
  id: root
  width: 64
  height: 44

  readonly property string mediaScope: '{"controls":["pause","stop","mute","volume","status"],"sourceHandles":["network.fetch"]}'
  property var mediaCall: null
  property bool playing: false
  property string statusText: "Radio Atlas"
  signal openRequested(string action)

  function control(action, value) {
    var payload = {control: action}
    if (action === "volume") payload.value = Math.max(0, Math.min(100, Math.round(Number(value))))
    mediaCall = runtime.invoke("control", {demandScope: mediaScope, payload: payload})
  }

  Qml.Connections {
    target: root.mediaCall
    function onFinishedChanged() {
      if (!root.mediaCall || !root.mediaCall.finished) return
      root.statusText = root.mediaCall.ok ? "Radio Atlas" : "Radio unavailable"
      if (!root.mediaCall.ok) root.playing = false
    }
  }

  Rectangle {
    anchors.fill: parent
    radius: 10
    color: root.playing ? "#2d6a4f" : "#15191e"

    Text {
      anchors.centerIn: parent
      text: "◉"
      color: "#f3f4f5"
      font.pixelSize: 20
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
      onClicked: function(mouse) {
        if (mouse.button === Qt.RightButton) root.control("stop")
        else root.openRequested(mouse.button === Qt.MiddleButton ? "random" : "toggle")
      }
      onWheel: function(wheel) { root.control("volume", wheel.angleDelta.y > 0 ? 75 : 65) }
    }
  }
}
