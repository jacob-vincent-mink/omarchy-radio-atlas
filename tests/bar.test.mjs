import assert from "node:assert/strict"
import fs from "node:fs"
import vm from "node:vm"

const source = fs.readFileSync(new URL("../BarWidget.qml", import.meta.url), "utf8")
const handler = source.match(/onPressed: (function\(mouseButton\) \{[\s\S]*?\n    \})/)
assert.ok(handler, "bar press handler exists")

const calls = []
const Qt = { LeftButton: 1, RightButton: 2, MiddleButton: 4 }
const root = {
  moduleName: "akshar.radio-atlas",
  bar: {
    shell: {
      toggle: id => calls.push(["toggle", id]),
      summon: (id, payload) => calls.push(["summon", id, JSON.parse(payload)])
    },
    run: () => assert.fail("panel activation must use scoped lifecycle calls")
  },
  runPlayerAction: action => calls.push(["player", action])
}
const press = vm.runInNewContext(`(${handler[1]})`, { root, Qt, JSON })

press(Qt.LeftButton)
press(Qt.MiddleButton)
press(Qt.RightButton)
assert.deepEqual(calls, [
  ["toggle", "akshar.radio-atlas"],
  ["summon", "akshar.radio-atlas", { action: "random" }],
  ["player", "stop"]
])

root.bar = null
press(Qt.LeftButton)
assert.equal(calls.length, 3)
console.log("Bar lifecycle tests passed")
