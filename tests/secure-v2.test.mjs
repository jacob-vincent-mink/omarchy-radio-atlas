import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";

const root = path.resolve(import.meta.dirname, "..");
const manifest = JSON.parse(fs.readFileSync(path.join(root, "manifest.json"), "utf8"));
const qml = fs.readFileSync(path.join(root, "RadioAtlas.qml"), "utf8");
const barQml = fs.readFileSync(path.join(root, "BarWidget.qml"), "utf8");

test("secure candidate declares bounded host-owned surfaces", () => {
  assert.equal(manifest.schemaVersion, 2);
  assert.equal(manifest.runtime.apiVersion, 1);
  assert.equal(manifest.runtime.qml, "RadioAtlas.qml");
  assert.deepEqual(Object.keys(manifest.surfaces).sort(), ["atlas", "barWidget"]);
  assert.equal(manifest.surfaces.atlas.role, "desktop-overlay");
  assert.equal(manifest.surfaces.atlas.keyboardFocus, "after-gesture");
  assert.equal(manifest.surfaces.atlas.lockScreenVisible, false);
});

test("candidate asks for purpose-built authority, never ambient escape hatches", () => {
  const capabilities = [...manifest.permissions.required, ...manifest.permissions.optional]
    .map(request => request.capability);
  assert.deepEqual(capabilities, [
    "network.fetch", "media.play-stream", "storage.private", "system.observe",
  ]);
  for (const forbidden of ["command.invoke", "http.request", "filesystem", "dbus", "wayland"])
    assert.equal(capabilities.includes(forbidden), false);
});

test("isolated QML has no ambient Quickshell, process, filesystem, or compositor API", () => {
  for (const source of [qml, barQml]) for (const forbidden of [
    "import Quickshell", "Process {", "FileView {", "PanelWindow {",
    "Hyprland", "WlrLayershell", "Quickshell.env", "Qt.resolvedUrl",
  ]) assert.equal(source.includes(forbidden), false, forbidden);
  assert.match(qml, /runtime\.invoke\("fetch"/);
  assert.match(qml, /runtime\.invoke\("play"/);
  assert.match(qml, /runtime\.invoke\("control"/);
  assert.match(qml, /decodeDirectory/);
  assert.match(qml, /decodeDirectory\(fetchCall\.utf8Text\)/);
  assert.match(qml, /function onCallFinished\(call\)/);
  assert.match(qml, /playbackHandle/);
  assert.equal(qml.includes("url_resolved"), false);
  assert.match(barQml, /runtime\.invoke\("control"/);
});

test("dynamic requests pin trusted definitions and operations", () => {
  const requests = [...manifest.permissions.required, ...manifest.permissions.optional];
  for (const request of requests.filter(item => item.capability !== "storage.private")) {
    assert.equal(request.definitionGeneration, 1);
    assert.match(request.definitionDigest, /^[0-9a-f]{64}$/);
    assert.ok(request.operations.length > 0);
  }
});

test("port keeps the product station model and globe in their original files", () => {
  assert.match(qml, /import "RadioModel\.js" as RadioModel/);
  assert.match(qml, /Globe \{/);
  assert.ok(fs.statSync(path.join(root, "RadioModel.js")).size > 10000);
  assert.ok(fs.statSync(path.join(root, "Globe.qml")).size > 10000);
  assert.equal(fs.existsSync(path.join(root, "secure-v2/ui/RadioAtlas.qml")), false);
  assert.equal(fs.existsSync(path.join(root, "secure-v2/ui/Globe.qml")), false);
  assert.equal(fs.existsSync(path.join(root, "secure-v2/ui/RadioModel.js")), false);
});

test("directory response is bounded and optional observation has a fallback", () => {
  assert.match(qml, /result\.stations\.length > 64/);
  assert.match(qml, /runtime\.permissionState\("system\.observe", "observe"\)/);
  assert.match(qml, /Directory unavailable:/);
});
