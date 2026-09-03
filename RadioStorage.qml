pragma Singleton
import QtQuick
import Omarchy.PluginPresentation 1.0

QtObject {
  id: root

  property PrivateStorage storage: PrivateStorage { itemBytes: 49152 }

  function stableIds(rows, limit) {
    var output = []
    var source = Array.isArray(rows) ? rows : []
    for (var index = 0; index < source.length && output.length < limit; ++index) {
      var row = source[index]
      var uuid = typeof row === "string" ? row : String(row && row.uuid || "")
      if (uuid && uuid.length <= 64 && output.indexOf(uuid) < 0) output.push(uuid)
    }
    return output
  }

  function validIds(rows, limit) {
    if (!Array.isArray(rows) || rows.length > limit) return false
    var seen = []
    for (var index = 0; index < rows.length; ++index) {
      var uuid = rows[index]
      if (typeof uuid !== "string" || !uuid || uuid.length > 64
          || seen.indexOf(uuid) >= 0) return false
      seen.push(uuid)
    }
    return true
  }

  function boundedVolume(value) {
    var number = Number(value)
    return isFinite(number) ? Math.max(0, Math.min(100, Math.round(number))) : 70
  }

  function validVolume(value) {
    return typeof value === "number" && isFinite(value) && value >= 0 && value <= 100
  }

  function document(favorites, recent, volume) {
    return {schemaVersion: 1, favorites: stableIds(favorites, 500),
      recent: stableIds(recent, 30), volume: boundedVolume(volume)}
  }

  function save(favorites, recent, volume, callback) {
    if (!runtime.hasPermission("storage.private", "write")) { callback(true); return }
    storage.writeText("state", JSON.stringify(document(favorites, recent, volume)),
      function(_) { callback(true) }, function(_) { callback(false) })
  }

  function load(callback) {
    if (!runtime.hasPermission("storage.private", "read")) {
      callback({favorites: [], recent: [], volume: 70})
      return
    }
    storage.readText("state", function(text) {
        var saved
        try { saved = JSON.parse(text || "null") } catch (_) { saved = null }
        if (!saved || saved.schemaVersion !== 1 || !validIds(saved.favorites, 500)
            || !validIds(saved.recent, 30) || !validVolume(saved.volume)) {
          callback(null)
          return
        }
        callback({favorites: saved.favorites, recent: saved.recent,
          volume: boundedVolume(saved.volume)})
      }, function(_) { callback({favorites: [], recent: [], volume: 70}) })
  }

  function resolve(ids, stations) {
    var byId = {}
    for (var index = 0; index < stations.length; ++index) {
      var station = stations[index]
      if (station && station.uuid) byId[String(station.uuid)] = station
    }
    return ids.map(function(uuid) { return byId[uuid] }).filter(Boolean)
  }
}
