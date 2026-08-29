# Radio Atlas secure-plugin port

This directory is a schema-v2 migration candidate, not a real-provider claim. It demonstrates that Radio Atlas can retain arbitrary Qt Quick, the rotatable globe, animation, hit testing, station selection, and its existing JavaScript model while moving system authority out of the QML process. The repository-root manifest is installable and pins the independently trusted reference definitions by generation, digest, operations, and scope.

## Current behavior to secure mapping

| Existing behavior | Secure form | Port status |
| --- | --- | --- |
| `Globe.qml` geometry, drag, zoom, signal hit testing, animation, and `RadioModel.js` ranking | Unmodified arbitrary QML and JavaScript inside the isolated renderer | Preserved; the candidate carries exact copies |
| `PanelWindow`, layer-shell namespace, input mask, and keyboard focus | Host-owned `desktop-overlay` surface with bounded dimensions, frame rate, focus-after-gesture, and dynamic bounded input regions | Expressible in the v2 manifest; multi-surface product wiring is not integrated |
| Bar button and overlay entry points | Host-owned `bar-embedded` and `desktop-overlay` surfaces sharing one plugin generation | Declared; the reference worker currently exposes one QML entry point and does not select between two surfaces |
| Radio Browser discovery through `curl` | `network.fetch` generation 1 / `1b1d…f5874`, operation `fetch`, scoped to exact HTTPS origins and `GET`; a separately installed Radio Browser adapter profile fixes paths, redirect/DNS policy, response size, record count, cache rules, and operations | Exact trusted authority is requested; Radio Browser is adapter identity, never permission vocabulary |
| Stream playback through plugin scripts, proxy, `mpv`, and MPRIS | `media.play-stream` generation 1 / `2c06…e4c9`, operations `play` and `control`, constrained to opaque handles issued by the granted fetch adapter | Required real adapter is not implemented; passing community stream URLs back from QML would be the wrong boundary |
| Favorites, history, volume, and directory caches in plugin-selected files | Existing `storage.private@1`, using fixed keys and bounded values in the plugin's private store | Capability exists; Radio Atlas needs an async SDK binding and transaction/list operations beyond the current fixture API |
| Screensaver observation through raw Hyprland events | `system.observe` generation 1 / `dc22…84c`, operation `observe`, scoped to the sanitized `screensaver.state` dataset | Optional real adapter is not implemented; omission only removes auto-dismiss |
| Reading bundled country geometry with `FileView` | Immutable revision resource exposed by the worker loader or generated QML/JS resource | Worker mounts the revision read-only, but a bounded non-QML resource API is not frozen |
| Shell injection (`shell`, `bar`, manifest object graph), arbitrary `Process`, runtime paths, sockets, and environment | No equivalent | Removed; these ambient powers are intentionally incompatible with isolation |

## Provider rules that matter

The Radio Browser adapter is a trusted registration under `network.fetch`; it is not a capability. It must return bounded normalized station records and opaque playback handles. The playback adapter is registered under `media.play-stream`, resolves a handle within the same plugin generation, performs the existing private-address and redirect defenses on the trusted side, owns `mpv`/MPRIS lifecycle, emits bounded sanitized status, and invalidates handles on grant revocation or revision replacement. Neither adapter can introduce a friendlier alias for broader authority because its canonical definition and implementation digest are bound by the trusted registry.

The existing plugin's `radio-proxy` and Bubblewrap network namespace are useful defense-in-depth evidence, but a plugin cannot be its own security boundary. Their policy belongs in the trusted provider and its tests. The plugin's QML must never receive a raw stream URL if the intended permission is only “play stations selected from Radio Browser.”

## What can run today

The QML scene and pure model run in the isolated worker. The external fixture resolves every dynamic request against the independent trusted definition directory, uses separately registered fake adapters, executes `stepForTest()`, and verifies a non-transparent shared-memory frame. Full station discovery and playback remain unproved because the real bounded fetch and media adapters do not exist yet.

Radio Atlas does not declare a sidecar. Its old fetch/proxy/player scripts require host network and media authority, so treating them as same-sandbox helpers would not make them authorized; their reusable policy belongs in trusted adapters. The secure QML and bundled JavaScript communicate freely inside one sandbox.

## Reproducible baseline

The upstream behavior baseline is commit `d5e445e35f3e545fbbb10410aff08ff91fb80647` (`fix: avoid hidden atlas startup errors`). Its unmodified `./tests/run` passes. Omarchy's advisory migration scanner reports 41 findings: 16 critical, 16 high, eight review, and one informational. By detector, those are 13 executable-content findings, 11 QML process uses, five `FileView` uses, five computed filesystem paths, three environment reads, two Hyprland accesses, one Wayland import, and one manifest-entry-point record.

Reproduce that inventory from a clean export so the candidate directory does not affect the baseline:

```bash
baseline=$(mktemp -d /tmp/radio-atlas-baseline.XXXXXX)
git archive d5e445e35f3e545fbbb10410aff08ff91fb80647 | tar -x -C "$baseline"
omarchy plugin security scan "$baseline" --format json
```

`./tests/run` now executes both the unchanged behavior suite and `tests/secure-v2.test.mjs`. The latter freezes the bounded surface request, exact capability vocabulary, absence of ambient APIs in migrated QML, and byte identity of the reusable globe and station model.

Scanning `secure-v2/` alone currently reports zero advisory findings. That is evidence that the known ambient calls were removed, not evidence that the candidate is safe or complete. Manifest validation, trusted definitions, user grants, sandbox enforcement, broker authorization, provider tests, and VM behavior proof remain authoritative.
