import QtQuick
import Omarchy.PluginPresentation 1.0
import "RadioModel.js" as RadioModel

BrokerProcess {
  id: root

  readonly property string networkScope: '{"methods":["GET"],"origins":["https://all.api.radio-browser.info"]}'

  function boundedText(value, limit) {
    return String(value || "").replace(/[\r\n\t]/g, " ").replace(/  +/g, " ").slice(0, limit)
  }

  function normalizeStation(row, handle) {
    if (!row || typeof row !== "object") return null
    var uuid = boundedText(row.stationuuid, 64).replace(/ /g, "")
    var name = boundedText(row.name, 160)
    if (!uuid || !name || !handle) return null
    var latitude = Number(row.geo_lat)
    var longitude = Number(row.geo_long)
    return {
      uuid: uuid, name: name, playbackHandle: String(handle),
      homepage: boundedText(row.homepage, 2048), favicon: boundedText(row.favicon, 2048),
      country: boundedText(row.country, 100), countryCode: boundedText(row.countrycode, 2).toUpperCase(),
      state: boundedText(row.state, 100), language: boundedText(row.language, 120),
      tags: boundedText(row.tags, 240), codec: boundedText(row.codec, 24),
      bitrate: Math.max(0, Math.min(10000, Math.round(Number(row.bitrate) || 0))),
      votes: Math.max(0, Math.min(1000000000, Math.round(Number(row.votes) || 0))),
      latitude: isFinite(latitude) && latitude >= -90 && latitude <= 90 ? latitude : null,
      longitude: isFinite(longitude) && longitude >= -180 && longitude <= 180 ? longitude : null
    }
  }

  function requestStations(path, onSuccess, onFailure) {
    var request = runtime.invoke("network.fetch", "fetch", {
      demandScope: networkScope,
      payload: {method: "GET", origin: "https://all.api.radio-browser.info", path: path,
        headers: {accept: "application/json"}, responseType: "json",
        mediaJsonPointers: ["/*/url_resolved"]}
    })
    if (!request) { onFailure("Broker request was rejected"); return }
    var done = function() {
      if (!request.finished) return
      try { request.finishedChanged.disconnect(done) } catch (_) {}
      if (!request.ok) { onFailure(String(request.error || "Request failed")); return }
      try {
        var envelope = JSON.parse(typeof request.value === "string" ? request.value : request.utf8Text || "{}")
        if (!envelope.ok || Number(envelope.status) < 200 || Number(envelope.status) >= 300)
          throw new Error(String(envelope.error || "HTTP request failed"))
        var raw = envelope.json
        if (!Array.isArray(raw) || raw.length > 64) throw new Error("Station response was invalid")
        var handles = envelope.sourceHandles || {}
        var rows = []
        for (var index = 0; index < raw.length; ++index) {
          var station = normalizeStation(raw[index], handles["/" + index + "/url_resolved"])
          if (station) rows.push(station)
        }
        onSuccess(rows)
      } catch (error) { onFailure(String(error)) }
    }
    if (request.finished) done()
    else request.finishedChanged.connect(done)
  }

  function stations() {
    try { return JSON.parse(RadioSessionState.playSelection || "[]") } catch (_) { return [] }
  }

  function stationFor(uuid) {
    var rows = stations().concat(RadioSessionState.favorites).concat(RadioSessionState.recent)
    for (var index = 0; index < rows.length; ++index)
      if (String(rows[index].uuid || "") === String(uuid || "")) return rows[index]
    return null
  }

  function publishPlayerState(state) {
    var text = JSON.stringify(state)
    RadioSessionState.playerStatus = text
    RadioSessionState.statusRevision += 1
    return text
  }

  function mediaControl(control, value) {
    if (!runtime.hasPermission("media.play-stream", "control")) {
      finish(1, "", "Playback control permission was not granted"); return
    }
    var payload = {control: control}
    if (control === "volume") payload.value = Number(value)
    observe(runtime.invoke("media.play-stream", "control", {
      demandScope: '{"controls":["pause","stop","mute","volume","status"],"sourceHandles":["network.fetch"]}',
      payload: payload
    }), function(raw) {
      if (control === "volume") {
        RadioSessionState.volume = Math.max(0, Math.min(100, Math.round(Number(value))))
        RadioStorage.save(RadioSessionState.favorites, RadioSessionState.recent,
          RadioSessionState.volume, function(_) {})
      }
      var state = JSON.parse(raw || "{}")
      if (RadioSessionState.playingStation) state.station = RadioSessionState.playingStation
      state.playlistPosition = RadioSessionState.playlistIndex
      state.playlistCount = RadioSessionState.playlist.length
      state.loaded = state.running === true
      return publishPlayerState(state)
    })
  }

  function playStation(station) {
    if (!runtime.hasPermission("media.play-stream", "play")) {
      finish(1, "", "Playback permission was not granted"); return
    }
    if (!station || !station.playbackHandle) { finish(1, "", "Station has no playback handle"); return }
    RadioSessionState.playingStation = station
    observe(runtime.invoke("media.play-stream", "play", {
      demandScope: '{"controls":["pause","stop","mute","volume","status"],"sourceHandles":["network.fetch"]}',
      payload: {handle: station.playbackHandle, volume: RadioSessionState.volume}
    }), function(raw) {
      var state = JSON.parse(raw || "{}")
      state.station = station
      state.playlistPosition = RadioSessionState.playlistIndex
      state.playlistCount = RadioSessionState.playlist.length
      state.loaded = true
      return publishPlayerState(state)
    })
  }

  function runPlayer(args) {
    var action = String(args[1] || "status")
    if (action === "play") {
      RadioSessionState.playlist = stations()
      var station = stationFor(args[2])
      RadioSessionState.playlistIndex = Math.max(0, RadioSessionState.playlist.indexOf(station))
      playStation(station)
    } else if (action === "next" || action === "previous") {
      if (RadioSessionState.playlist.length === 0) { finish(1, "", "Playlist is empty"); return }
      var delta = action === "next" ? 1 : -1
      RadioSessionState.playlistIndex = (RadioSessionState.playlistIndex + delta + RadioSessionState.playlist.length) % RadioSessionState.playlist.length
      playStation(RadioSessionState.playlist[RadioSessionState.playlistIndex])
    } else if (action === "toggle") mediaControl("pause")
    else if (action === "volume") mediaControl("volume", args[2])
    else mediaControl(action)
  }

  function stateObject() {
    return {favorites: RadioSessionState.favorites, recent: RadioSessionState.recent, volume: RadioSessionState.volume}
  }

  function persistState() {
    if (!runtime.hasPermission("storage.private", "write")) { finish(0, JSON.stringify(stateObject()), ""); return }
    RadioStorage.save(RadioSessionState.favorites, RadioSessionState.recent, RadioSessionState.volume,
      function(ok) { if (ok) finish(0, JSON.stringify(stateObject()), ""); else finish(1, "", "Could not save state") })
  }

  function resolveState(saved) {
    var ids = saved.favorites.concat(saved.recent).filter(function(value, index, all) {
      return typeof value === "string" && value.length > 0 && value.length <= 64 && all.indexOf(value) === index
    }).slice(0, 500)
    RadioSessionState.volume = saved.volume
    if (ids.length === 0) { finish(0, JSON.stringify(stateObject()), ""); return }
    var rows = []
    var offset = 0
    var next = function() {
      if (offset >= ids.length) {
        RadioSessionState.favorites = RadioStorage.resolve(saved.favorites, rows)
        RadioSessionState.recent = RadioStorage.resolve(saved.recent, rows)
        finish(0, JSON.stringify(stateObject()), "")
        return
      }
      var chunk = ids.slice(offset, offset + 40)
      offset += chunk.length
      requestStations("/json/stations/byuuid?uuids=" + encodeURIComponent(chunk.join(",")),
        function(found) { rows = RadioModel.mergeStations(rows, found, 500); next() },
        function(error) { finish(1, "", error) })
    }
    next()
  }

  function runState(args) {
    var action = String(args[1] || "get")
    if (action === "get") {
      RadioStorage.load(function(saved) {
        if (!saved) finish(1, "", "Saved state is invalid")
        else resolveState(saved)
      })
      return
    }
    var station = stationFor(args[2])
    if (!station) { finish(1, "", "Station is unavailable"); return }
    var rows = action === "favorite" ? RadioSessionState.favorites.slice() : RadioSessionState.recent.slice()
    var found = rows.findIndex(function(row) { return row.uuid === station.uuid })
    if (action === "favorite" && found >= 0) rows.splice(found, 1)
    else { if (found >= 0) rows.splice(found, 1); rows.unshift(station) }
    if (action === "favorite") RadioSessionState.favorites = rows.slice(0, 500)
    else RadioSessionState.recent = rows.slice(0, 30)
    persistState()
  }

  function runFetch(args) {
    var action = String(args[1] || "world")
    var value = String(args[2] || "")
    var limit = action === "country" ? 25 : 40
    var offset = action === "world-more" ? Math.max(0, Number(RadioSessionState.worldCursor) || 0) : 0
    var base = "/json/stations/search?hidebroken=true&order=clickcount&reverse=true&limit=" + limit
    var paths = [base + "&has_geo_info=true&offset=" + offset]
    if (action === "country") paths = ["/json/stations/bycountrycodeexact/" + encodeURIComponent(value.toUpperCase())
      + "?hidebroken=true&order=clickcount&reverse=true&limit=" + limit]
    else if (action === "search") {
      paths = []
      var searchFields = ["name", "country", "tag"]
      searchFields.forEach(function(field) {
        paths.push(base + "&" + field + "=" + encodeURIComponent(value) + "&offset=0")
        paths.push(base + "&" + field + "=" + encodeURIComponent(value) + "&offset=40")
      })
    }
    else if (action === "random") paths = ["/json/stations/search?hidebroken=true&order=random&limit=40"]
    var rows = []
    var requestIndex = 0
    var next = function() {
      if (requestIndex < paths.length) {
        requestStations(paths[requestIndex++], function(found) {
          rows = RadioModel.mergeStations(rows, found, 150); next()
        }, function(error) { finish(1, "", error) })
        return
      }
      if (action === "world" || action === "world-more") {
        RadioSessionState.worldCursor = String(offset + rows.length)
        RadioSessionState.worldStations = RadioModel.mergeStations(RadioSessionState.worldStations, rows, 5000)
      }
      if (action === "random" && rows.length > 0) {
        rows = RadioModel.mergeStations(RadioSessionState.worldStations, rows, 5000)
        var excluded = value.split(",")
        var candidates = rows.filter(function(row) {
          return excluded.indexOf(String(row.uuid || "")) < 0
            && ((row.latitude !== null && row.longitude !== null)
              || /^[A-Z]{2}$/.test(String(row.countryCode || "")))
        })
        if (candidates.length === 0) candidates = rows
        rows = [candidates[Math.floor(Math.random() * candidates.length)]]
      }
      finish(0, JSON.stringify(rows), "")
    }
    next()
  }

  function start() {
    if (!running || !Array.isArray(command) || command.length < 2) return
    var executable = String(command[0] || "").split("/").pop()
    if (executable === "radio-fetch") runFetch(command)
    else if (executable === "radio-player") runPlayer(command)
    else if (executable === "radio-state") runState(command)
    else finish(1, "", "Unsupported broker operation")
  }
}
