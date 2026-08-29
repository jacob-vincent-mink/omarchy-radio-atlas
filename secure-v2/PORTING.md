# Radio Atlas secure-plugin port

This branch is a schema-v2 migration candidate with live Radio Browser and media-provider evidence. It modifies the existing `manifest.json` and `RadioAtlas.qml` in place so the migration diff shows the author's original files becoming isolated. `Globe.qml` and `RadioModel.js` remain in their original locations. There is no parallel secure UI tree. The manifest pins independently trusted definitions by generation, digest, operations, and scope.

## Current behavior to secure mapping

| Existing behavior | Secure form | Port status |
| --- | --- | --- |
| `Globe.qml` geometry, drag, zoom, signal hit testing, animation, and `RadioModel.js` ranking | Unmodified arbitrary QML and JavaScript inside the isolated renderer | Preserved in their original files |
| `PanelWindow`, layer-shell namespace, input mask, and keyboard focus | Host-owned `desktop-overlay` surface with bounded dimensions, frame rate, focus-after-gesture, and dynamic bounded input regions | Expressible in the v2 manifest; multi-surface product wiring is not integrated |
| Bar button and overlay entry points | Host-owned `bar-embedded` and `desktop-overlay` surfaces sharing one plugin generation | Declared; the reference worker currently exposes one QML entry point and does not select between two surfaces |
| Radio Browser discovery through `curl` | `network.fetch` generation 1 / `1b1d…f5874`, operation `fetch`, scoped to exact HTTPS origins and `GET`; the trusted Radio provider fixes the origin and path, bounds the raw response to 1 MiB and normalized result to 64 records, accepts only HTTPS stream URLs, and returns opaque playback handles | Implemented in the opt-in live host; tested against the public service through the real broker and Bubblewrap worker |
| Stream playback through plugin scripts, proxy, `mpv`, and MPRIS | `media.play-stream` generation 1 / `2c06…e4c9`, operations `play` and `control`, constrained to opaque handles issued by the granted fetch adapter | Host-owned `mpv` playback and bounded volume, pause, status, and stop controls are implemented and live-tested; fetch revocation invalidates every issued handle |
| Favorites, history, volume, and directory caches in plugin-selected files | Existing `storage.private@1`, using fixed keys and bounded values in the plugin's private store | Capability exists; Radio Atlas needs an async SDK binding and transaction/list operations beyond the current fixture API |
| Screensaver observation through raw Hyprland events | `system.observe` generation 1 / `dc22…84c`, operation `observe`, scoped to the sanitized `screensaver.state` dataset | Optional real adapter is not implemented; omission only removes auto-dismiss |
| Reading bundled country geometry with `FileView` | Immutable revision resource exposed by the worker loader or generated QML/JS resource | Worker mounts the revision read-only, but a bounded non-QML resource API is not frozen |
| Shell injection (`shell`, `bar`, manifest object graph), arbitrary `Process`, runtime paths, sockets, and environment | No equivalent | Removed; these ambient powers are intentionally incompatible with isolation |

## Provider rules that matter

The Radio Browser adapter is a trusted registration under `network.fetch`; it is not a capability. It returns bounded normalized station records and opaque playback handles. The playback adapter is registered under `media.play-stream`, resolves a handle within the same plugin generation and fetch epoch, and invalidates handles on grant revocation. Neither adapter can introduce a friendlier alias for broader authority because its canonical definition and implementation digest are bound by the trusted registry. The remaining HTTPS transport must reject redirects, pin the exact public Radio Browser origin after public-address resolution, retain TLS hostname verification, enforce connect/total deadlines, and never return raw stream URLs to QML. The remaining media process must own exact `/usr/bin/mpv` lifecycle and typed IPC without a shell.

The existing plugin's `radio-proxy` and Bubblewrap network namespace are useful defense-in-depth evidence, but a plugin cannot be its own security boundary. Their policy belongs in the trusted provider and its tests. The plugin's QML never receives a raw stream URL: the directory response contains activation- and grant-epoch-bound opaque handles, and the media provider resolves them internally.

## What can run today

The QML scene and pure model run in the isolated worker. `RadioAtlas.qml` decodes only the broker's validated UTF-8 view of the versioned, bounded provider response, never sees a stream URL, follows the stable runtime completion signal, and renders explicit directory and playback denial states. The real-Bubblewrap compatibility run authorized live Radio Browser fetch and opaque-handle playback through the audited dynamic broker. The opt-in provider probe returned 22 policy-compliant HTTPS stations in a 4,545-byte normalized response, started host-owned playback, exercised volume, pause, status, and stop, and denied reuse of the handle after fetch revocation.

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

Scanning the activated schema-v2 entry point currently reports no ambient QML calls. `BarWidget.qml` is also migrated in place: it emits host-owned open requests and uses only the typed media control operation. Legacy executable helper scripts remain in the repository for migration review but are undeclared and cannot execute in the isolated runtime; they must be removed before claiming the whole source tree is free of legacy implementation artifacts. Manifest validation, trusted definitions, user grants, sandbox enforcement, broker authorization, provider tests, and VM behavior proof remain authoritative.

## Feature parity status

The current in-place QML keeps the original globe, station markers, selection animation, station activation, directory status, basic playback, volume, and favorite requests. It does not yet reproduce the original search and country-mode controls, recent-station and favorite browsing, random selection, keyboard navigation, full player status, or multi-surface bar-to-overlay integration. Those are UI and SDK migration work rather than reasons to restore ambient process, filesystem, compositor, or socket access. This branch therefore demonstrates the secure boundary and response path, not complete winner parity.
