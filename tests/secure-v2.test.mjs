import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";

const root = path.resolve(import.meta.dirname, "..");
const manifest = JSON.parse(fs.readFileSync(path.join(root, "secure-v2/manifest.json"), "utf8"));
const qml = fs.readFileSync(path.join(root, "secure-v2/ui/RadioAtlas.qml"), "utf8");

test("secure candidate declares bounded host-owned surfaces", () => {
  assert.equal(manifest.schemaVersion, 2);
  assert.equal(manifest.runtime.apiVersion, 1);
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
  for (const forbidden of [
    "import Quickshell", "Process {", "FileView {", "PanelWindow {",
    "Hyprland", "WlrLayershell", "Quickshell.env", "Qt.resolvedUrl",
  ]) assert.equal(qml.includes(forbidden), false, forbidden);
  assert.match(qml, /runtime\.invoke\("network_fetch"/);
  assert.match(qml, /runtime\.invoke\("media_play_stream"/);
});

test("port keeps the product station model and globe exactly", () => {
  assert.equal(
    fs.readFileSync(path.join(root, "secure-v2/ui/RadioModel.js"), "utf8"),
    fs.readFileSync(path.join(root, "RadioModel.js"), "utf8"),
  );
  assert.equal(
    fs.readFileSync(path.join(root, "secure-v2/ui/Globe.qml"), "utf8"),
    fs.readFileSync(path.join(root, "Globe.qml"), "utf8"),
  );
});
