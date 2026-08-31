import QtQuick
import QtQuick.Controls as QQC
import QtQml as Qml
import "RadioModel.js" as RadioModel

Item {
  id: root
  width: 1180
  height: 760
  property var inputRegions: [
    {x: 24, y: 24, width: Math.max(0, sidebar.x - 48), height: Math.max(0, height - 48)},
    {x: sidebar.x, y: 0, width: sidebar.width, height: height}
  ]

  readonly property string fetchScope: '{"methods":["GET"],"origins":["https://all.api.radio-browser.info"]}'
  readonly property string mediaScope: '{"controls":["pause","stop","mute","volume","status"],"sourceCapabilities":["network.fetch"]}'
  property var countries: []
  property var stations: []
  property var results: []
  property var favorites: []
  property var recent: []
  property var favoriteUuids: []
  property var recentUuids: []
  property string mode: "world"
  property string activeCountryCode: ""
  property string activeCountryName: ""
  property string searchText: ""
  property int selectedIndex: -1
  property var selectedStation: null
  property var pendingPlayStation: null
  property var fetchCall: null
  property var mediaCall: null
  property string statusText: "Radio Atlas"
  property string errorText: ""
  property bool fetching: false
  property bool playing: false
  property int volume: 70
  property bool paused: false
  property bool muted: false
  property string playerTitle: ""
  property var storageCall: null
  property string pendingStorageAction: ""
  property bool runtimeStarted: false
  readonly property var displayStations: mode === "favorites" ? favorites
    : mode === "recent" ? recent : results
  readonly property bool directoryAvailable:
    runtime.hasPermission("network.fetch", "fetch")
  readonly property bool canPlay:
    runtime.hasPermission("media.play-stream", "play")
  readonly property bool canControl:
    runtime.hasPermission("media.play-stream", "control")
  readonly property color background: "#090a0c"
  readonly property color foreground: "#f2f4f8"
  readonly property color accent: "#5e81ac"
  readonly property color urgent: "#bf616a"
  readonly property color dim: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.56)
  readonly property color faint: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.12)

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

  function decodeStoredValue(value) {
    var bytes = null
    if (value instanceof ArrayBuffer) bytes = new Uint8Array(value)
    else if (ArrayBuffer.isView(value)) bytes = new Uint8Array(value.buffer, value.byteOffset, value.byteLength)
    if (!bytes || bytes.length < 8 || bytes[0] !== 1 || bytes[1] !== 0
        || bytes[2] !== 0 || bytes[3] !== 0) return null
    var length = (((bytes[4] << 24) >>> 0) + (bytes[5] << 16)
      + (bytes[6] << 8) + bytes[7]) >>> 0
    if (length === 0 || length > 4096 || bytes.length !== 8 + length) return null
    return decodeUtf8(bytes.subarray(8), 4096)
  }

  function loadCountries() {
    var text = runtime.readPackagedText("assets/countries.json", 524288)
    if (!text) {
      root.errorText = "Map data could not be loaded"
      return
    }
    try {
      var collection = JSON.parse(text)
      root.countries = Array.isArray(collection.features)
        ? collection.features.slice(0, 512) : []
    } catch (error) {
      root.countries = []
      root.errorText = "Map data could not be loaded"
    }
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
    favorites = favoriteUuids.map(stationByUuid).filter(Boolean)
    recent = recentUuids.map(stationByUuid).filter(Boolean)
    if (mode === "world") results = stations
    else if (mode === "search") results = RadioModel.searchStations(stations, searchText, 150)
    else if (mode === "country") results = RadioModel.stationsForCountry(stations, activeCountryCode, 150)
    errorText = ""
    statusText = stations.length + " HTTPS stations"
  }

  function refreshWorld() {
    if (fetchCall && !fetchCall.finished) return
    if (!directoryAvailable) {
      fetching = false
      errorText = "Radio directory permission is not granted"
      statusText = "Radio Atlas — directory unavailable"
      return
    }
    fetching = true
    errorText = ""
    statusText = "Loading Radio Browser…"
    fetchCall = runtime.invoke("network.fetch", "fetch", {demandScope: fetchScope,
      payload: {operation: "radio-directory.world", limit: 64}})
    if (fetchCall && fetchCall.finished) finishFetch()
  }

  function setStationList(nextMode, nextStations) {
    mode = nextMode
    results = Array.isArray(nextStations) ? nextStations : []
    selectedIndex = results.length > 0 ? 0 : -1
    selectedStation = selectedIndex >= 0 ? results[selectedIndex] : null
  }

  function showWorld() {
    searchText = ""
    activeCountryCode = ""
    activeCountryName = ""
    setStationList("world", stations)
  }

  function showFavorites() { setStationList("favorites", favorites) }
  function showRecent() { setStationList("recent", recent) }

  function search(text) {
    searchText = String(text || "").trim()
    if (!searchText) { showWorld(); return }
    setStationList("search", RadioModel.searchStations(stations, searchText, 150))
  }

  function browseCountry(code, name) {
    activeCountryCode = String(code || "").toUpperCase().slice(0, 2)
    activeCountryName = String(name || "").slice(0, 96)
    setStationList("country", RadioModel.stationsForCountry(stations, activeCountryCode, 150))
  }

  function moveSelection(delta) {
    if (displayStations.length === 0) return
    selectedIndex = (selectedIndex + delta + displayStations.length) % displayStations.length
    selectedStation = displayStations[selectedIndex]
  }

  function tuneRandom() {
    if (!canPlay) {
      errorText = "Playback permission is not granted"
      return false
    }
    var pool = displayStations.length > 0 ? displayStations : stations
    if (pool.length === 0) return false
    var index = Math.floor(Math.random() * pool.length)
    selectedIndex = index
    selectedStation = pool[index]
    return play(selectedStation)
  }

  function finishMedia() {
    if (!mediaCall || !mediaCall.finished) return
    if (!mediaCall.ok) {
      errorText = "Playback unavailable: " + mediaCall.error
      playing = false
      return
    }
    var state = ({})
    try { state = JSON.parse(mediaCall.utf8Text || "{}") } catch (error) {}
    if (pendingPlayStation) {
      selectedStation = pendingPlayStation
      recordPlayed(selectedStation)
      pendingPlayStation = null
    }
    playing = state.running === undefined ? true : state.running === true
    paused = state.paused === true
    muted = state.muted === true
    if (state.volume !== undefined) volume = Math.max(0, Math.min(100, Math.round(Number(state.volume))))
    playerTitle = String(state.title || selectedStation && selectedStation.name || "").slice(0, 160)
    errorText = ""
    statusText = playerTitle || "Radio Atlas"
  }

  function play(station) {
    if (!canPlay || !station || !station.uuid || !station.playbackHandle) {
      if (!canPlay) errorText = "Playback permission is not granted"
      return false
    }
    pendingPlayStation = station
    mediaCall = runtime.invoke("media.play-stream", "play", {demandScope: mediaScope,
      payload: {sourceHandle: station.playbackHandle}})
    if (mediaCall && mediaCall.finished) finishMedia()
    return true
  }

  function setVolume(nextVolume) {
    if (!canControl) return false
    var bounded = Math.max(0, Math.min(100, Math.round(Number(nextVolume))))
    var call = runtime.invoke("media.play-stream", "control", {demandScope: mediaScope,
      payload: {control: "volume", value: bounded}})
    if (call && call.finished && call.ok) volume = bounded
    return true
  }

  function controlPlayer(control, value) {
    if (!canControl) return false
    mediaCall = runtime.invoke("media.play-stream", "control", {demandScope: mediaScope,
      payload: control === "volume" ? {control: control, value: value} : {control: control}})
    if (mediaCall && mediaCall.finished) finishMedia()
    return true
  }

  function stationByUuid(uuid) {
    for (var i = 0; i < stations.length; ++i)
      if (stations[i].uuid === uuid) return stations[i]
    return null
  }

  function isFavorite(uuid) {
    for (var i = 0; i < favorites.length; ++i)
      if (favorites[i].uuid === uuid) return true
    return false
  }

  function toggleFavorite(station) {
    if (!station || !station.uuid) return false
    var next = []
    var removed = false
    for (var i = 0; i < favorites.length; ++i) {
      if (favorites[i].uuid === station.uuid) removed = true
      else next.push(favorites[i])
    }
    if (!removed) next.unshift(station)
    favorites = next.slice(0, 100)
    favoriteUuids = favorites.map(function(row) { return row.uuid })
    saveLocalState()
    return true
  }

  function recordPlayed(station) {
    if (!station || !station.uuid) return
    var next = [station]
    for (var i = 0; i < recent.length && next.length < 50; ++i)
      if (recent[i].uuid !== station.uuid) next.push(recent[i])
    recent = next
    recentUuids = recent.map(function(row) { return row.uuid })
    saveLocalState()
  }

  function saveLocalState() {
    pendingStorageAction = "write"
    storageCall = runtime.invoke("storage.private", "write", {key: "radio-state-v1",
      value: JSON.stringify({favorites: favoriteUuids,
        recent: recentUuids, volume: volume}),
      quotaBytes: 1048576, itemBytes: 4096})
  }

  function loadLocalState() {
    pendingStorageAction = "read"
    storageCall = runtime.invoke("storage.private", "read", {key: "radio-state-v1",
      quotaBytes: 1048576, itemBytes: 4096})
  }

  function finishStorage() {
    if (!storageCall || !storageCall.finished || !storageCall.ok || pendingStorageAction !== "read") return
    try {
      var encoded = decodeStoredValue(storageCall.value)
      if (encoded === null) return
      var state = JSON.parse(encoded)
      volume = Math.max(0, Math.min(100, Math.round(Number(state.volume || 70))))
      favoriteUuids = Array.isArray(state.favorites) ? state.favorites.slice(0, 100) : []
      recentUuids = Array.isArray(state.recent) ? state.recent.slice(0, 50) : []
      favorites = favoriteUuids.map(stationByUuid).filter(Boolean)
      recent = recentUuids.map(stationByUuid).filter(Boolean)
    } catch (error) {}
  }

  function stepForTest() { refreshWorld() }

  function startRuntime() {
    if (runtimeStarted || !runtime.brokerReady) return
    runtimeStarted = true
    loadLocalState()
    refreshWorld()
    if (canControl) controlPlayer("status")
  }

  function open() {
    startRuntime()
    if (runtimeStarted && stations.length === 0 && !fetching) refreshWorld()
  }

  Qml.Component.onCompleted: { loadCountries(); startRuntime() }

  Qml.Connections {
    target: runtime
    function onCallFinished(call) {
      if (call === root.fetchCall) root.finishFetch()
      else if (call === root.mediaCall) root.finishMedia()
      else if (call === root.storageCall) root.finishStorage()
    }
    function onBrokerReadyChanged() { root.startRuntime() }
  }

  Rectangle {
    anchors.fill: parent
    radius: 22
    color: root.background
    border.color: root.errorText ? root.urgent : root.faint
    focus: true
    Keys.onPressed: function(event) {
      if (event.key === Qt.Key_Down || event.key === Qt.Key_J) root.moveSelection(1)
      else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) root.moveSelection(-1)
      else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.play(root.selectedStation)
      else if (event.key === Qt.Key_Space) root.controlPlayer("pause")
      else if (event.key === Qt.Key_R) root.tuneRandom()
      else if (event.key === Qt.Key_F) root.toggleFavorite(root.selectedStation)
      else return
      event.accepted = true
    }

    Globe {
      id: globe
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.right: sidebar.left
      anchors.margins: 24
      countries: root.countries
      stations: root.displayStations
      selectedStation: root.selectedStation
      activeCountryCode: root.activeCountryCode
      onStationActivated: function(station) {
        root.selectedStation = station
        root.play(station)
      }
      onCountryActivated: function(code, name) { root.browseCountry(code, name) }
    }

    Rectangle {
      id: sidebar
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      width: Math.min(390, parent.width * 0.38)
      color: Qt.rgba(root.background.r, root.background.g, root.background.b, 0.96)
      border.color: root.faint

      Column {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 10

        Text { text: "RADIO ATLAS"; color: root.foreground; font.pixelSize: 24; font.bold: true }

        QQC.TextField {
          width: parent.width
          placeholderText: "Search stations"
          text: root.searchText
          onAccepted: root.search(text)
          onTextEdited: root.search(text)
        }

        Row {
          spacing: 6
          QQC.Button { text: "World"; onClicked: root.showWorld() }
          QQC.Button { text: "Favorites"; onClicked: root.showFavorites() }
          QQC.Button { text: "Recent"; onClicked: root.showRecent() }
          QQC.Button { text: "Random"; enabled: root.canPlay; onClicked: root.tuneRandom() }
        }

        Text {
          width: parent.width
          text: root.mode === "country" ? root.activeCountryName : root.mode.charAt(0).toUpperCase() + root.mode.slice(1)
          color: root.dim
          elide: Text.ElideRight
        }

        ListView {
          id: stationList
          width: parent.width
          height: Math.max(120, parent.height - 255)
          clip: true
          model: root.displayStations
          currentIndex: root.selectedIndex
          delegate: Rectangle {
            required property var modelData
            required property int index
            width: stationList.width
            height: 48
            radius: 7
            color: root.selectedStation && root.selectedStation.uuid === modelData.uuid
              ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22) : "transparent"
            Text {
              anchors.left: parent.left
              anchors.right: favorite.left
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: 10
              text: modelData.name + (modelData.countryCode ? "  ·  " + modelData.countryCode : "")
              color: root.foreground
              elide: Text.ElideRight
            }
            Text {
              id: favorite
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.rightMargin: 10
              text: root.isFavorite(modelData.uuid) ? "★" : "☆"
              color: root.isFavorite(modelData.uuid) ? root.accent : root.dim
            }
            MouseArea {
              anchors.fill: parent
              acceptedButtons: Qt.LeftButton | Qt.RightButton
              onClicked: function(mouse) {
                root.selectedIndex = index
                root.selectedStation = modelData
                if (mouse.button === Qt.RightButton) root.toggleFavorite(modelData)
                else root.play(modelData)
              }
            }
          }
        }

        Row {
          spacing: 8
          QQC.Button { text: root.paused ? "Resume" : "Pause"; enabled: root.playing && root.canControl; onClicked: root.controlPlayer("pause") }
          QQC.Button { text: "Stop"; enabled: root.playing && root.canControl; onClicked: root.controlPlayer("stop") }
          QQC.Button { text: root.muted ? "Unmute" : "Mute"; enabled: root.playing && root.canControl; onClicked: root.controlPlayer("mute") }
          QQC.Button { text: root.isFavorite(root.selectedStation && root.selectedStation.uuid) ? "★" : "☆"; enabled: !!root.selectedStation; onClicked: root.toggleFavorite(root.selectedStation) }
        }

        QQC.Slider {
          enabled: root.canControl
          width: parent.width
          height: 32
          from: 0
          to: 100
          value: root.volume
          stepSize: 1
          onPressedChanged: function() {
            if (pressed) return
            root.volume = Math.round(value)
            root.setVolume(root.volume)
          }
        }
      }
    }

    Rectangle {
      anchors.left: parent.left
      anchors.right: sidebar.left
      anchors.bottom: parent.bottom
      height: 72
      color: Qt.rgba(root.background.r, root.background.g, root.background.b, 0.9)

      Text {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        anchors.verticalCenter: parent.verticalCenter
        text: root.errorText || root.statusText
        color: root.errorText ? root.urgent : root.foreground
        font.pixelSize: 18
        textFormat: Text.PlainText
        elide: Text.ElideRight
      }
    }
  }
}
