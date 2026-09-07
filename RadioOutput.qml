import QtQuick

QtObject {
  property string text: ""
  property bool waitForEnd: true
  signal streamFinished()

  function publish(value) {
    text = value
    streamFinished()
  }
}
