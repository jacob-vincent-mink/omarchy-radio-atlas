import QtQuick
import "RadioModel.js" as RadioModel

Item {
  id: root
  width: 1180
  height: 760

  property var countries: []
  property var stations: []
  property var selectedStation: null
  property string statusText: "Radio Atlas"
  property bool playing: false
  property int volume: 70

  function applyDirectoryResult(nextStations) {
    if (!Array.isArray(nextStations)) return
    stations = RadioModel.mergeStations(stations, nextStations, 5000)
  }

  function refreshWorld() {
    applyDirectoryResult(runtime.invoke("network_fetch", {
      operation: "radio-directory.world", limit: 5000
    }))
  }

  function play(station) {
    if (!station || !station.uuid) return false
    var accepted = runtime.invoke("media_play_stream", {
      handle: station.playbackHandle
    })
    if (accepted) {
      selectedStation = station
      playing = true
      statusText = String(station.name || "Radio Atlas")
    }
    return accepted === true
  }

  function setVolume(nextVolume) {
    var bounded = Math.max(0, Math.min(100, Math.round(Number(nextVolume))))
    if (runtime.invoke("media_stream_control", {
      control: "volume", value: bounded
    })) volume = bounded
  }

  function toggleFavorite(station) {
    if (!station || !station.uuid) return false
    return runtime.invoke("storage_private_update", {
      key: "favorites", operation: "toggle", station: station.uuid
    }) === true
  }

  Component.onCompleted: refreshWorld()

  Rectangle {
    anchors.fill: parent
    radius: 22
    color: "#090a0c"
    border.color: "#283039"

    Globe {
      id: globe
      anchors.fill: parent
      anchors.margins: 24
      countries: root.countries
      stations: root.stations
      selectedStation: root.selectedStation
      onStationActivated: function(station) { root.play(station) }
    }

    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: 72
      color: "#e611151a"

      Text {
        anchors.left: parent.left
        anchors.leftMargin: 24
        anchors.verticalCenter: parent.verticalCenter
        text: root.statusText
        color: "#f3f4f5"
        font.pixelSize: 18
        textFormat: Text.PlainText
      }
    }
  }
}
