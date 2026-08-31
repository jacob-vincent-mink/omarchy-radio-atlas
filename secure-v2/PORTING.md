# Radio Atlas secure-plugin port

This branch is a schema-v2 migration candidate for the current isolated QML API. It modifies the existing `manifest.json`, `RadioAtlas.qml`, and `BarWidget.qml` in place so the migration diff shows the author's original files becoming isolated. `Globe.qml` and `RadioModel.js` remain in their original locations. There is no parallel secure UI tree. The manifest pins independently trusted definitions by generation, digest, operations, and scope.

## Current behavior to secure mapping

| Existing behavior | Secure form | Port status |
| --- | --- | --- |
| `Globe.qml` geometry, drag, zoom, signal hit testing, animation, and `RadioModel.js` ranking | Unmodified arbitrary QML and JavaScript inside the isolated renderer | Preserved in their original files |
| `PanelWindow`, layer-shell namespace, input mask, and keyboard focus | Host-owned `desktop-overlay` surface with bounded dimensions, frame rate, focus-after-gesture, and dynamic bounded input regions | Declared for the worker's multi-surface path; live shell placement is not yet proved for this port |
| Bar button and overlay entry points | Host-owned `bar-embedded` and `desktop-overlay` surfaces sharing one plugin generation | The bar requests an `atlas` toggle only during authenticated pointer press; the atlas implements the required `open()` lifecycle |
| Radio Browser discovery through `curl` | `network.fetch` generation 1 / `1b1d…f5874`, operation `fetch`, scoped to exact HTTPS origins and `GET`; the intended trusted Radio provider fixes the origin and path, bounds the normalized result to 64 records, accepts only HTTPS stream URLs, and returns opaque playback handles | QML request and response handling are ported; the final trusted provider is not yet installed or exercised with this branch |
| Stream playback through plugin scripts, proxy, `mpv`, and MPRIS | `media.play-stream` generation 1 / `2c06…e4c9`, operations `play` and `control`, constrained to opaque handles issued by the granted fetch adapter | QML uses the typed play/control boundary; final host-owned playback and handle revocation still need provider and live-runtime proof |
| Favorites, history, volume, and directory caches in plugin-selected files | Existing `storage.private@1`, using a fixed key and bounded values in the plugin's private store | Ported to the current async worker API; packaged/live proof remains pending |
| Screensaver observation through raw Hyprland events | `system.observe` generation 1 / `dc22…84c`, operation `observe`, scoped to the sanitized `screensaver.state` dataset | Optional real adapter is not implemented; omission only removes auto-dismiss |
| Reading bundled country geometry with `FileView` | Immutable revision resource read through `runtime.readPackagedText` with a caller and runtime byte bound | Ported to the current worker API |
| Shell injection (`shell`, `bar`, manifest object graph), arbitrary `Process`, runtime paths, sockets, and environment | No equivalent | Removed; these ambient powers are intentionally incompatible with isolation |

## Provider rules that matter

The Radio Browser adapter is a trusted registration under `network.fetch`; it is not a capability. It returns bounded normalized station records and opaque playback handles. The playback adapter is registered under `media.play-stream`, resolves a handle within the same plugin generation and fetch epoch, and invalidates handles on grant revocation. Neither adapter can introduce a friendlier alias for broader authority because its canonical definition and implementation digest are bound by the trusted registry. The remaining HTTPS transport must reject redirects, pin the exact public Radio Browser origin after public-address resolution, retain TLS hostname verification, enforce connect/total deadlines, and never return raw stream URLs to QML. The remaining media process must own exact `/usr/bin/mpv` lifecycle and typed IPC without a shell.

The existing plugin's `radio-proxy` and Bubblewrap network namespace are useful defense-in-depth evidence, but a plugin cannot be its own security boundary. Their policy belongs in the trusted provider and its tests. The plugin's QML never receives a raw stream URL: the directory response contains activation- and grant-epoch-bound opaque handles, and the media provider resolves them internally.

## What this branch proves

The repository tests prove the QML-facing migration shape: no ambient Quickshell or presentation-library import, no process or filesystem API, immutable startup permission projection, broker-readiness-gated effects, bounded response decoding, packaged-resource reads, typed broker calls, and press-bound surface intent. They do not prove final Radio Browser transport, media playback, Bubblewrap packaging, shell placement, or live behavior on Omarchy 4.0.1-1. Those require the final trusted providers and an installed runtime generation.

Radio Atlas does not declare a sidecar. Its old fetch/proxy/player scripts require host network and media authority, so treating them as same-sandbox helpers would not make them authorized; their reusable policy belongs in trusted adapters. The secure QML and bundled JavaScript communicate freely inside one sandbox.

## Reproducible baseline

The upstream behavior baseline is commit `d5e445e35f3e545fbbb10410aff08ff91fb80647` (`fix: avoid hidden atlas startup errors`). Its unmodified `./tests/run` passes. Omarchy's advisory migration scanner reports 41 findings: 16 critical, 16 high, eight review, and one informational. By detector, those are 13 executable-content findings, 11 QML process uses, five `FileView` uses, five computed filesystem paths, three environment reads, two Hyprland accesses, one Wayland import, and one manifest-entry-point record.

Reproduce that inventory from a clean export so the candidate directory does not affect the baseline:

```bash
baseline=$(mktemp -d /tmp/radio-atlas-baseline.XXXXXX)
git archive d5e445e35f3e545fbbb10410aff08ff91fb80647 | tar -x -C "$baseline"
omarchy plugin security scan "$baseline" --format json
```

`./tests/run` now executes both the unchanged pure behavior suite and `tests/secure-v2.test.mjs`. The latter freezes the bounded surface request, exact capability vocabulary, absence of ambient APIs in migrated QML, in-place runtime entry point, response bounds, opaque-handle boundary, and reuse of the original globe and station-model files.

`qmllint BarWidget.qml Globe.qml RadioAtlas.qml` passes. Both migrated QML entry files also compile and publish non-transparent frames under the current Omarchy worker's software/offscreen external-fixture harness. That harness currently accepts one surface per fixture, so the check used temporary manifests that selected each unchanged QML entry independently. This is compile/render evidence only: it does not exercise the two surfaces in one live shell generation, authenticated input routing, Bubblewrap, or any network, storage, observation, or media effect.

Scanning the activated schema-v2 entry point currently reports no ambient QML calls. `BarWidget.qml` is also migrated in place: it uses ordinary Qt Quick controls, requests the host-owned atlas surface only from pointer press, and uses only the typed media control operation. Legacy executable helper scripts remain in the repository for migration review but are undeclared and cannot execute in the isolated runtime; they must be removed before claiming the whole source tree is free of old implementation artifacts. Manifest validation, trusted definitions, user grants, sandbox enforcement, broker authorization, provider tests, and VM behavior proof remain authoritative.

## Feature parity status

The in-place QML retains the globe, station markers, selection animation, station activation, world/search/country modes, favorite and recent libraries, random tuning inside the atlas, keyboard navigation, detailed local playback state, volume, mute, pause, and stop. The bar retains toggle, stop, and volume; its old middle-click random intent cannot cross the host surface API because that API intentionally accepts only `open`, `toggle`, and `dismiss`, so middle click now toggles the atlas and random remains an in-surface action. Directory, playback, and persistence effects use broker calls; permission or provider failure leaves the surface available with an explicit error instead of restoring ambient authority.

The host owns the former `PanelWindow`, layer-shell, focus, input-region, and bar-to-overlay routing responsibilities. The migration therefore does not preserve the original `Quickshell`, `PanelWindow`, `Process`, `FileView`, `BarWidget`, `WidgetButton`, `Color`, or `Style` object identities inside the hostile worker. It uses plugin-local Qt Quick controls and colors instead of requiring a privileged presentation module. The permission projection is immutable for one plugin generation; changing a grant requires the host to replace or stop that generation, so the QML has no permission-change callback. Track-title metadata and screensaver auto-dismiss remain permission-aware degradations until sanitized observation fields are included in the media and system-observation provider responses.
