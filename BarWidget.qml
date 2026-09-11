import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  required property var runtime
  moduleName: "akshar.radio-atlas"

  readonly property var playerService: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
  readonly property bool playerRunning: playerService ? playerService.playerRunning : false
  readonly property bool playerPaused: playerService ? playerService.playerPaused : false
  readonly property bool playerMuted: playerService ? playerService.playerMuted : false
  readonly property int playerVolume: playerService ? playerService.playerVolume : 70
  readonly property string playerTitle: playerService ? playerService.playerTitle : ""

  function safeTooltipText(value) {
    return String(value || "").replace(/[\r\n\t]+/g, " ").slice(0, 160).replace(/</g, "‹").replace(/>/g, "›")
  }

  function runPlayerAction(action) {
    if (playerService) playerService.runPlayerAction(action)
  }

  function changeVolume(delta) {
    if (playerService) playerService.changeVolume(delta)
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\uf0ac"
    active: root.playerRunning && !root.playerPaused
    tooltipText: root.playerRunning
      ? (root.playerPaused ? "Radio paused: " : "Playing: ") + root.safeTooltipText(root.playerTitle)
        + "  ·  " + (root.playerMuted ? "muted" : root.playerVolume + "%")
      : "Open Radio Atlas"

    onPressed: function(mouseButton) {
      if (!root.bar) return
      if (mouseButton === Qt.RightButton) {
        root.runPlayerAction("stop")
        return
      }
      if (mouseButton === Qt.MiddleButton) {
        root.bar.shell.summon(root.moduleName, JSON.stringify({ action: "random" }))
        return
      }
      root.bar.shell.toggle(root.moduleName)
    }

    onWheelMoved: function(delta) {
      root.changeVolume(delta)
    }
  }
}
