pragma Singleton
import QtQuick

QtObject {
  property string playSelection: "[]"
  property string favoriteSelection: "[]"
  property var favorites: []
  property var recent: []
  property int volume: 70
  property var playlist: []
  property int playlistIndex: -1
  property var playingStation: null
  property string playerStatus: ""
  property int statusRevision: 0
  property string worldCursor: ""
  property var worldStations: []
}
