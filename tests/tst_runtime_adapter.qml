import QtQuick
import QtTest
import ".."

Item {
  id: fixture
  width: 1280
  height: 900

  QtObject {
    id: runtime
    property bool brokerReady: false
    property var requests: []
    property var activeCall: null
    property bool deferReply: false
    function hasPermission(capability, operation) { return true }
    function permissionState(capability, operation) { return "granted" }
    function requestSurfaceIntent(target, action) { return true }
    function readPackagedText(path, limit) { return '{"features":[]}' }
    function invoke(capability, operation, arguments) {
      requests = requests.concat([{capability: capability, operation: operation, arguments: arguments}])
      var response = operation === "fetch"
        ? '{"ok":true,"status":200,"json":[],"sourceHandles":{}}'
        : operation === "read" ? '{"found":false}' : '{"ok":true,"running":false}'
      activeCall = replyFactory.createObject(fixture, {finished: !deferReply, utf8Text: response})
      return activeCall
    }
  }

  Component {
    id: replyFactory
    QtObject {
      property bool finished: true
      property bool ok: true
      property string utf8Text: ""
      property string error: ""
    }
  }

  Component {
    id: requestFactory
    RadioProcess {
      stdout: RadioOutput {}
      stderr: RadioOutput {}
    }
  }

  TestCase {
    name: "RadioRuntimeAdapter"
    when: windowShown

    function init() {
      runtime.brokerReady = false
      runtime.deferReply = false
      runtime.requests = []
    }

    function test_waitsForBrokerReadiness() {
      var request = createTemporaryObject(requestFactory, fixture, {
        command: ["radio-fetch", "world"], running: true
      })
      verify(request !== null)
      compare(runtime.requests.length, 0)
      runtime.brokerReady = true
      compare(runtime.requests.length, 1, JSON.stringify({running: request.running, initialized: request.initialized, dispatched: request.dispatched, command: request.command, error: request.stderr.text}))
      compare(runtime.requests[0].capability, "network.fetch")
      compare(runtime.requests[0].arguments.method, "GET")
      verify(runtime.requests[0].arguments.demandScope === undefined)
      verify(runtime.requests[0].arguments.payload === undefined)
      compare(request.stdout.text, "[]")
      compare(request.running, false)
    }

    function test_lateReplyDoesNotPublishAfterLocalStop() {
      runtime.brokerReady = true
      runtime.deferReply = true
      var request = createTemporaryObject(requestFactory, fixture, {
        command: ["radio-player", "status"], running: true
      })
      verify(request !== null)
      compare(runtime.requests.length, 1, JSON.stringify({running: request.running, initialized: request.initialized, dispatched: request.dispatched, command: request.command, error: request.stderr.text}))
      var reply = runtime.activeCall
      request.running = false
      reply.finished = true
      compare(request.stdout.text, "")
      compare(request.pendingCalls.length, 0)
    }

    function test_surfacesLoad_data() {
      return [{tag: "atlas", file: "RadioAtlas.qml"}, {tag: "bar", file: "BarWidget.qml"}]
    }

    function test_surfacesLoad(data) {
      var component = Qt.createComponent("../" + data.file)
      compare(component.status, Component.Ready, component.errorString())
      var surface = component.createObject(fixture)
      verify(surface !== null, component.errorString())
      verify(surface.inputRegions.length > 0)
      surface.destroy()
    }
  }
}
