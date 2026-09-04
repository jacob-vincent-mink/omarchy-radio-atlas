# Radio Atlas secure-plugin port

This branch is a schema-v2 migration candidate for the current isolated QML API. It modifies the existing `manifest.json`, `RadioAtlas.qml`, and `BarWidget.qml` in place so the migration diff shows the author's original files becoming isolated. `Globe.qml` and `RadioModel.js` remain in their original locations. There is no parallel secure UI tree. The manifest pins independently trusted definitions by generation, digest, operations, and scope.

## Current behavior to secure mapping

| Existing behavior | Secure form | Port status |
| --- | --- | --- |
| `Globe.qml` geometry, drag, zoom, signal hit testing, animation, and `RadioModel.js` ranking | Unmodified arbitrary QML and JavaScript inside the isolated renderer | Preserved in their original files |
| `PanelWindow`, layer-shell namespace, input mask, and keyboard focus | Host-owned `desktop-overlay` surface with bounded dimensions, frame rate, focus-after-gesture, and dynamic bounded input regions | Declared for the worker's multi-surface path; live shell placement is not yet proved for this port |
| Bar button and overlay entry points | Host-owned `bar-embedded` and `desktop-overlay` surfaces sharing one plugin generation | The bar requests an `atlas` toggle only during authenticated pointer press; the atlas implements the required `open()` lifecycle |
| Radio Browser discovery through `curl` | `network.fetch` generation 1 / `fd87…af62`, operation `fetch`, scoped to exact HTTPS origins and `GET`; the trusted Radio provider fixes the origin and path, bounds the normalized result to 64 records, accepts only HTTPS stream URLs, and returns opaque playback handles | QML request and response handling are ported and the provider is packaged by the current secure runtime; live behavior still requires end-to-end verification |
| Stream playback through plugin scripts, proxy, `mpv`, and MPRIS | `media.play-stream` generation 1 / `4070…950b`, operations `play` and `control`, constrained to activation-bound opaque handles issued through `network.fetch` | QML uses the typed play/control boundary; final host-owned playback and handle revocation still need provider and live-runtime proof |
| Favorites, history, volume, and directory caches in plugin-selected files | Existing `storage.private@1`, using a fixed key and bounded values in the plugin's private store | The port stores favorite/recent UUIDs and volume, but does not cache directory records; restored UUIDs disappear from the UI unless their records are in the current 64-station response |
| Screensaver observation through raw Hyprland events | No equivalent requested by this port | Auto-dismiss is absent; the manifest does not request an observation permission or imply an adapter that does not exist |
| Reading bundled country geometry with `FileView` | Immutable revision resource read through `runtime.readPackagedText` with a caller and runtime byte bound | Ported to the current worker API |
| Shell injection (`shell`, `bar`, manifest object graph), arbitrary `Process`, runtime paths, sockets, and environment | No equivalent | Removed; these ambient powers are intentionally incompatible with isolation |

## Provider rules that matter

The intended Radio Browser adapter is a trusted registration under `network.fetch`; it is not a capability. It must return bounded normalized station records and opaque playback handles. The intended playback adapter is registered under `media.play-stream`, must resolve a handle within the same plugin generation and fetch epoch, and must invalidate handles on grant revocation. Neither adapter may introduce a friendlier alias for broader authority because its canonical definition and semantic contract digest are bound by the trusted registry. The HTTPS transport must reject redirects, pin the exact public Radio Browser origin after public-address resolution, retain TLS hostname verification, enforce connect/total deadlines, and never return raw stream URLs to QML. The media process must own exact `/usr/bin/mpv` lifecycle and typed IPC without a shell.

The existing plugin's `radio-proxy` and Bubblewrap network namespace are useful defense-in-depth evidence, but a plugin cannot be its own security boundary. Their policy belongs in the trusted provider and its tests. The plugin's QML never receives a raw stream URL: the directory response contains activation- and grant-epoch-bound opaque handles, and the media provider resolves them internally.

## What this branch proves

The repository tests prove the QML-facing migration shape: no ambient Quickshell or presentation-library import, no process or filesystem API, immutable startup permission projection, broker-readiness-gated effects, bounded response decoding, and a press-bound surface-intent call. They semantically compare every QML operation and demand-scope constant with the manifest request. They do not execute those calls through `ManifestInvokeEncoder`, the broker authorization path, final Radio Browser transport, media playback, Bubblewrap packaging, shell placement, or a live Omarchy 4.0.1-1 generation. The encoder/broker and live proof must wait for the final integration work.

Radio Atlas does not declare a sidecar. Its old fetch/proxy/player scripts require host network and media authority, so treating them as same-sandbox helpers would not make them authorized; their reusable policy belongs in trusted adapters. The secure QML and bundled JavaScript communicate freely inside one sandbox.

## Reproducible baseline

The upstream behavior baseline is commit `d5e445e35f3e545fbbb10410aff08ff91fb80647` (`fix: avoid hidden atlas startup errors`). Its unmodified `./tests/run` passes. Omarchy's advisory migration scanner reports 41 findings: 16 critical, 16 high, eight review, and one informational. By detector, those are 13 executable-content findings, 11 QML process uses, five `FileView` uses, five computed filesystem paths, three environment reads, two Hyprland accesses, one Wayland import, and one manifest-entry-point record.

Reproduce that inventory from a clean export so the candidate directory does not affect the baseline:

```bash
baseline=$(mktemp -d /tmp/radio-atlas-baseline.XXXXXX)
git archive d5e445e35f3e545fbbb10410aff08ff91fb80647 | tar -x -C "$baseline"
omarchy plugin security scan "$baseline" --format json
```

`./tests/run` now executes both the unchanged pure behavior suite and `tests/secure-v2.test.mjs`. The latter freezes the bounded surface request, exact capability vocabulary, absence of ambient APIs in migrated QML, in-place runtime entry point, response bounds, opaque-handle boundary, operation/scope-to-manifest mapping, and reuse of the original globe and station-model files.

`qmllint BarWidget.qml Globe.qml RadioAtlas.qml` passes. Both migrated QML entry files instantiate and publish non-transparent frames under the current Omarchy `WorkerRuntime` software/offscreen external-fixture harness. That harness substitutes a minimal provider object rather than the real `QmlBrokerApi` and currently accepts one surface per fixture, so the check used temporary manifests that selected each unchanged QML entry independently. Runtime-property warnings are not promoted to failures by that harness. This is instantiation/render-only evidence: it does not prove the accepted immutable snapshot, broker-ready transition, packaged asset root, surface-intent sink, QML demand encoding, the two surfaces in one generation, authenticated input routing, Bubblewrap, or any network, storage, or media effect.

Scanning the activated schema-v2 entry point currently reports no ambient QML calls. `BarWidget.qml` is also migrated in place: it uses ordinary Qt Quick controls, requests the host-owned atlas surface only from pointer press, and uses only the typed media control operation. Legacy executable helper scripts remain in the repository for migration review but are undeclared and cannot execute in the isolated runtime; they must be removed before claiming the whole source tree is free of old implementation artifacts. Manifest validation, trusted definitions, user grants, sandbox enforcement, broker authorization, provider tests, and VM behavior proof remain authoritative.

## Feature parity status

The in-place QML retains the globe, station markers, selection animation, station activation, a bounded world view, local search/country modes, in-memory favorite and recent lists, local random tuning inside the atlas, a subset of keyboard navigation, bounded playback state, volume, mute, pause, and stop. The bar retains toggle, stop, and volume; its old middle-click random intent cannot cross the host surface API because that API intentionally accepts only `open`, `toggle`, and `dismiss`, so middle click now toggles the atlas and random remains an in-surface action. The exact losses relative to the winner are documented in `README.md`: 64 records instead of progressive 5,000-station discovery, no remote search/country refresh, incomplete favorite/recent restoration, random may repeat recent stations, no previous/next or failed-stream skip, reduced keyboard and Escape behavior, fixed styling, no click-count call, and no screensaver dismissal.

The host owns the former `PanelWindow`, layer-shell, focus, input-region, and bar-to-overlay routing responsibilities. The migration therefore does not preserve the original `Quickshell`, `PanelWindow`, `Process`, `FileView`, `BarWidget`, `WidgetButton`, `Color`, or `Style` object identities inside the hostile worker. It uses plugin-local Qt Quick controls and colors instead of requiring a privileged presentation module. The permission projection is immutable for one plugin generation; changing a grant requires the host to replace or stop that generation, so the QML has no permission-change callback. Screensaver observation is simply absent rather than represented by a fictional permission-aware fallback.
