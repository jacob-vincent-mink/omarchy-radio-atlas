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
  assert.deepEqual(manifest.runtime.surfaceQml, {
    atlas: "RadioAtlas.qml",
    barWidget: "BarWidget.qml",
  });
  assert.deepEqual(Object.keys(manifest.surfaces).sort(), ["atlas", "barWidget"]);
  assert.equal(manifest.surfaces.atlas.role, "desktop-overlay");
  assert.equal(manifest.surfaces.atlas.keyboardFocus, "after-gesture");
  assert.equal(manifest.surfaces.atlas.lockScreenVisible, false);
  assert.equal(manifest.surfaces.atlas.inputRegions, "dynamic-bounded");
  assert.equal(manifest.surfaces.barWidget.inputRegions, "dynamic-bounded");
});

test("candidate asks for purpose-built authority, never ambient escape hatches", () => {
  assert.deepEqual(manifest.permissions.optional, []);
  const capabilities = [...manifest.permissions.required, ...manifest.permissions.optional]
    .map(request => request.capability);
  assert.deepEqual(capabilities, [
    "network.fetch", "media.play-stream", "storage.private",
  ]);
  for (const forbidden of ["command.invoke", "http.request", "filesystem", "dbus", "wayland"])
    assert.equal(capabilities.includes(forbidden), false);
});

test("isolated QML has no ambient Quickshell, process, filesystem, or compositor API", () => {
  for (const source of [qml, barQml]) for (const forbidden of [
    "import Quickshell", "Process {", "FileView {", "PanelWindow {",
    "Hyprland", "WlrLayershell", "Quickshell.env", "Omarchy.PluginPresentation",
  ]) assert.equal(source.includes(forbidden), false, forbidden);
  assert.match(qml, /runtime\.invoke\("network\.fetch", "fetch"/);
  assert.match(qml, /runtime\.invoke\("media\.play-stream", "play"/);
  assert.match(qml, /runtime\.invoke\("media\.play-stream", "control"/);
  assert.match(qml, /decodeDirectory/);
  assert.match(qml, /decodeDirectory\(fetchCall\.utf8Text\)/);
  assert.match(qml, /function onCallFinished\(call\)/);
  assert.match(qml, /playbackHandle/);
  assert.equal(qml.includes("url_resolved"), false);
  assert.match(barQml, /runtime\.invoke\("media\.play-stream", "control"/);
});

test("dynamic requests pin trusted definitions and operations", () => {
  const requests = [...manifest.permissions.required, ...manifest.permissions.optional];
  for (const request of requests.filter(item => item.capability !== "storage.private")) {
    assert.equal(request.definitionGeneration, 1);
    assert.match(request.definitionDigest, /^[0-9a-f]{64}$/);
    assert.ok(request.operations.length > 0);
  }
});

test("QML operations and demand scopes are a subset of the manifest request", () => {
  const requests = new Map(manifest.permissions.required.map(request => [request.capability, request]));
  const fetch = requests.get("network.fetch");
  const media = requests.get("media.play-stream");
  const fetchScope = JSON.parse(qml.match(/readonly property string fetchScope: '([^']+)'/)[1]);
  const mediaScope = JSON.parse(qml.match(/readonly property string mediaScope: '([^']+)'/)[1]);
  const barMediaScope = JSON.parse(barQml.match(/readonly property string mediaScope: '([^']+)'/)[1]);

  assert.deepEqual(fetchScope, {methods: fetch.methods, origins: fetch.origins});
  assert.deepEqual(mediaScope, {controls: media.controls, sourceCapabilities: media.sourceCapabilities});
  assert.deepEqual(barMediaScope, mediaScope);
  const qualified = [...qml.matchAll(/runtime\.invoke\("([^"]+)", "([^"]+)"/g)]
    .map(match => [match[1], match[2]]);
  assert.deepEqual([...new Set(qualified.filter(pair => pair[0] !== "storage.private")
    .map(pair => pair[1]))].sort(), [...fetch.operations, ...media.operations].sort());
  assert.match(qml, /runtime\.invoke\("network\.fetch", "fetch", \{demandScope: fetchScope,/);
  assert.match(qml, /runtime\.invoke\("media\.play-stream", "play", \{demandScope: mediaScope,/);
  assert.match(qml, /runtime\.invoke\("media\.play-stream", "control", \{demandScope: mediaScope,/);
  assert.match(barQml, /runtime\.invoke\("media\.play-stream", "control", \{demandScope: mediaScope,/);

  const allInvokes = [...qml.matchAll(/runtime\.invoke\("([^"]+)", "([^"]+)"/g),
    ...barQml.matchAll(/runtime\.invoke\("([^"]+)", "([^"]+)"/g)]
    .map(match => `${match[1]}/${match[2]}`);
  const allowed = new Set(["network.fetch/fetch", "media.play-stream/play",
    "media.play-stream/control", "storage.private/read", "storage.private/write"]);
  for (const invocation of allInvokes) assert.equal(allowed.has(invocation), true, invocation);
  assert.equal(requests.has("storage.private"), true);
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

test("directory response is bounded and no observation API is implied", () => {
  assert.match(qml, /result\.stations\.length > 64/);
  assert.match(qml, /runtime\.readPackagedText\("assets\/countries\.json", 524288\)/);
  assert.match(qml, /runtime\.hasPermission\("network\.fetch", "fetch"\)/);
  assert.match(qml, /Directory unavailable:/);
  assert.equal(JSON.stringify(manifest).includes("system.observe"), false);
  assert.equal(qml.includes("screensaver"), false);
});

test("permission state is immutable for the generation", () => {
  for (const source of [qml, barQml]) {
    assert.equal(source.includes("onPermissionsChanged"), false);
    assert.equal(source.includes("onPermissionsChanged"), false);
  }
  assert.match(qml, /runtime\.hasPermission\("network\.fetch", "fetch"\)/);
  assert.match(qml, /function onBrokerReadyChanged\(\) \{ root\.startRuntime\(\) \}/);
});

test("partial media grants expose only their permitted behavior", () => {
  assert.match(qml, /readonly property bool canPlay:\s*runtime\.hasPermission\("media\.play-stream", "play"\)/);
  assert.match(qml, /readonly property bool canControl:\s*runtime\.hasPermission\("media\.play-stream", "control"\)/);
  assert.match(qml, /function play\(station\) \{\s*if \(!canPlay/);
  assert.match(qml, /function tuneRandom\(\) \{\s*if \(!canPlay/);
  assert.match(qml, /function setVolume\(nextVolume\) \{\s*if \(!canControl\) return false/);
  assert.match(qml, /function controlPlayer\(control, value\) \{\s*if \(!canControl\) return false/);
  assert.match(qml, /if \(canControl\) controlPlayer\("status"\)/);
  assert.match(qml, /text: "Random"; enabled: root\.canPlay/);
  assert.match(qml, /enabled: root\.playing && root\.canControl/);
  assert.match(qml, /QQC\.Slider \{\s*enabled: root\.canControl/);

  assert.match(barQml, /readonly property bool canControl:\s*runtime\.hasPermission\("media\.play-stream", "control"\)/);
  assert.match(barQml, /function control\(action, value\) \{\s*if \(!canControl\)/);
  assert.match(barQml, /WheelHandler \{\s*enabled: root\.canControl/);
});

test("bar surface intents consume the authenticated press gesture", () => {
  assert.match(barQml, /onPressed: function\(mouse\)/);
  assert.match(barQml, /runtime\.requestSurfaceIntent\("atlas", "toggle"\)/);
  assert.equal(barQml.includes("openRequested"), false);
  assert.doesNotMatch(barQml, /on(?:Clicked|Released|Tapped)[\s\S]{0,160}requestSurfaceIntent/);
  const intents = [...barQml.matchAll(/requestSurfaceIntent\("[^"]+", "([^"]+)"\)/g)];
  assert.deepEqual(intents.map(match => match[1]), ["toggle"]);
  assert.equal(Object.hasOwn(manifest.surfaces, "atlas"), true);
});

test("interactive surfaces publish bounded authenticated input regions", () => {
  assert.match(qml, /property var inputRegions:/);
  assert.match(barQml, /property var inputRegions:/);
});

test("private storage restoration validates the broker result envelope", () => {
  assert.match(qml, /function decodeStoredValue\(value\)/);
  assert.match(qml, /bytes\[0\] !== 1/);
  assert.match(qml, /bytes\.length !== 8 \+ length/);
  assert.match(qml, /decodeStoredValue\(storageCall\.value\)/);
});

test("migrated UI retains a bounded subset of navigation and library code", () => {
  for (const feature of [
    "function search(text)", "function browseCountry(code, name)",
    "function showFavorites()", "function showRecent()", "function tuneRandom()",
    "function moveSelection(delta)", "function toggleFavorite(station)",
    "function recordPlayed(station)", "Keys.onPressed", "QQC.TextField",
    "ListView {", "QQC.Slider", "function open()",
  ]) assert.ok(qml.includes(feature), feature);
  assert.match(qml, /activeCountryCode: root\.activeCountryCode/);
  assert.match(qml, /QQC\.Button \{/);
  assert.match(barQml, /^Item \{/m);
  assert.match(barQml, /MouseArea \{/);
  assert.match(barQml, /runtime\.invoke\("media\.play-stream", "control"/);
  assert.match(barQml, /JSON\.parse\(mediaCall\.utf8Text/);
});
