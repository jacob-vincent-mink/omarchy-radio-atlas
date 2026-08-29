import QtQuick
import QtQml as Qml
import "RadioModel.js" as RadioModel

Item {
  id: root
  width: 1180
  height: 760

  readonly property string fetchScope: '{"methods":["GET"],"origins":["https://all.api.radio-browser.info"]}'
  readonly property string mediaScope: '{"controls":["pause","stop","mute","volume","status"],"sourceHandles":["network.fetch"]}'
  property var countries: []
  property var stations: []
  property var selectedStation: null
  property var pendingPlayStation: null
  property var fetchCall: null
  property var mediaCall: null
  property string statusText: "Radio Atlas"
  property string errorText: ""
  property bool fetching: false
  property bool playing: false
  property int volume: 70
  readonly property bool screensaverAwarenessAvailable:
    runtime.permissionState("system.observe", "observe") === "granted"

  function decodeUtf8(value, maximumBytes) {
    if (typeof value === "string")
      return value.length > 0 && value.length <= maximumBytes ? value : null
    var bytes = null
    if (value instanceof ArrayBuffer) bytes = new Uint8Array(value)
    else if (ArrayBuffer.isView(value)) bytes = new Uint8Array(value.buffer, value.byteOffset, value.byteLength)
    if (!bytes || bytes.length === 0 || bytes.length > maximumBytes) return null
    var encoded = ""
    for (var i = 0; i < bytes.length; ++i) encoded += "%" + bytes[i].toString(16).padStart(2, "0")
    try { return decodeURIComponent(encoded) } catch (error) { return null }
  }

  function decodeDirectory(value) {
    var text = decodeUtf8(value, 65536)
    if (text === null) return null
    try {
      var result = JSON.parse(text)
      if (!result || result.version !== 1 || !Array.isArray(result.stations) || result.stations.length > 64) return null
      var normalized = []
      for (var i = 0; i < result.stations.length; ++i) {
        var station = result.stations[i]
        if (!station || typeof station.uuid !== "string" || station.uuid.length === 0 || station.uuid.length > 64
            || typeof station.name !== "string" || station.name.length === 0 || station.name.length > 160
            || typeof station.playbackHandle !== "string" || station.playbackHandle.length === 0 || station.playbackHandle.length > 32) return null
        normalized.push({uuid: station.uuid, name: station.name, country: String(station.country || "").slice(0, 96),
          countryCode: String(station.countryCode || "").slice(0, 2).toUpperCase(),
          latitude: station.latitude === null ? null : Number(station.latitude),
          longitude: station.longitude === null ? null : Number(station.longitude),
          votes: Math.max(0, Math.round(Number(station.votes || 0))), playbackHandle: station.playbackHandle})
      }
      return normalized
    } catch (error) { return null }
  }

  function finishFetch() {
    if (!fetchCall || !fetchCall.finished) return
    fetching = false
    if (!fetchCall.ok) {
      errorText = "Directory unavailable: " + fetchCall.error
      statusText = "Radio Atlas — offline"
      return
    }
    var decoded = decodeDirectory(fetchCall.utf8Text)
    if (decoded === null) {
      errorText = "Directory provider returned an invalid response"
      statusText = "Radio Atlas — unavailable"
      return
    }
    stations = RadioModel.mergeStations(stations, decoded, 5000)
    errorText = ""
    statusText = stations.length + " HTTPS stations"
  }

  function refreshWorld() {
    if (fetchCall && !fetchCall.finished) return
    fetching = true
    errorText = ""
    statusText = "Loading Radio Browser…"
    fetchCall = runtime.invoke("fetch", {demandScope: fetchScope,
      payload: {operation: "radio-directory.world", limit: 64}})
    if (fetchCall && fetchCall.finished) finishFetch()
  }

  function finishMedia() {
    if (!mediaCall || !mediaCall.finished) return
    if (!mediaCall.ok) {
      errorText = "Playback unavailable: " + mediaCall.error
      playing = false
      return
    }
    selectedStation = pendingPlayStation
    playing = true
    errorText = ""
    statusText = String(selectedStation && selectedStation.name || "Radio Atlas")
  }

  function play(station) {
    if (!station || !station.uuid || !station.playbackHandle) return false
    pendingPlayStation = station
    mediaCall = runtime.invoke("play", {demandScope: mediaScope,
      payload: {handle: station.playbackHandle}})
    if (mediaCall && mediaCall.finished) finishMedia()
    return true
  }

  function setVolume(nextVolume) {
    var bounded = Math.max(0, Math.min(100, Math.round(Number(nextVolume))))
    var call = runtime.invoke("control", {demandScope: mediaScope,
      payload: {control: "volume", value: bounded}})
    if (call && call.finished && call.ok) volume = bounded
  }

  function toggleFavorite(station) {
    if (!station || !station.uuid) return false
    runtime.invoke("storage_write", {key: "favorites", value: JSON.stringify({operation: "toggle", station: station.uuid}),
      quotaBytes: 1048576, itemBytes: 262144})
    return true
  }

  function stepForTest() { refreshWorld() }

  Qml.Component.onCompleted: refreshWorld()

  Qml.Connections {
    target: runtime
    function onCallFinished(call) {
      if (call === root.fetchCall) root.finishFetch()
      else if (call === root.mediaCall) root.finishMedia()
    }
  }

  Rectangle {
    anchors.fill: parent
    radius: 22
    color: "#090a0c"
    border.color: root.errorText ? "#d96b6b" : "#283039"

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
        anchors.right: parent.right
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        anchors.verticalCenter: parent.verticalCenter
        text: root.errorText || root.statusText
        color: root.errorText ? "#ff9b9b" : "#f3f4f5"
        font.pixelSize: 18
        textFormat: Text.PlainText
        elide: Text.ElideRight
      }
    }
  }
}
