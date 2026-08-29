# Radio Atlas secure-plugin port

This directory is a schema-v2 migration candidate, not an activatable claim. It demonstrates that Radio Atlas can retain arbitrary Qt Quick, the rotatable globe, animation, hit testing, station selection, and its existing JavaScript model while moving system authority out of the QML process. The current Omarchy reference runtime deliberately denies the provider operations Radio Atlas needs, so this candidate must remain inactive until those closed capabilities are reviewed and implemented.

## Current behavior to secure mapping

| Existing behavior | Secure form | Port status |
| --- | --- | --- |
| `Globe.qml` geometry, drag, zoom, signal hit testing, animation, and `RadioModel.js` ranking | Unmodified arbitrary QML and JavaScript inside the isolated renderer | Preserved; the candidate carries exact copies |
| `PanelWindow`, layer-shell namespace, input mask, and keyboard focus | Host-owned `desktop-overlay` surface with bounded dimensions, frame rate, focus-after-gesture, and dynamic bounded input regions | Expressible in the v2 manifest; multi-surface product wiring is not integrated |
| Bar button and overlay entry points | Host-owned `bar-embedded` and `desktop-overlay` surfaces sharing one plugin generation | Declared; the reference worker currently exposes one QML entry point and does not select between two surfaces |
| Radio Browser discovery through `curl` | `radio-browser.directory@1`, a purpose-built provider that fixes upstream hosts, redirect/DNS policy, response size, record count, cache rules, and request operations | Required provider is not in the closed registry; no generic HTTP permission is requested |
| Stream playback through plugin scripts, proxy, `mpv`, and MPRIS | `media.radio-playback@1`, a host-owned media session accepting opaque station handles issued by the directory provider | Required provider is not implemented; passing community stream URLs back from QML would be the wrong boundary |
| Favorites, history, volume, and directory caches in plugin-selected files | Existing `storage.private@1`, using fixed keys and bounded values in the plugin's private store | Capability exists; Radio Atlas needs an async SDK binding and transaction/list operations beyond the current fixture API |
| Screensaver observation through raw Hyprland events | Sanitized `lifecycle.screensaver@1` event carrying only `started` | Optional provider is not implemented; omission only removes auto-dismiss |
| Reading bundled country geometry with `FileView` | Immutable revision resource exposed by the worker loader or generated QML/JS resource | Worker mounts the revision read-only, but a bounded non-QML resource API is not frozen |
| Shell injection (`shell`, `bar`, manifest object graph), arbitrary `Process`, runtime paths, sockets, and environment | No equivalent | Removed; these ambient powers are intentionally incompatible with isolation |

## Provider rules that matter

The directory provider must return bounded normalized station records and opaque playback handles. It must not return arbitrary executable commands or confer arbitrary Internet access. The playback provider resolves a handle within the same plugin generation, performs the existing private-address and redirect defenses on the trusted side, owns `mpv`/MPRIS lifecycle, emits bounded sanitized status, and invalidates handles on grant revocation or revision replacement.

The existing plugin's `radio-proxy` and Bubblewrap network namespace are useful defense-in-depth evidence, but a plugin cannot be its own security boundary. Their policy belongs in the trusted provider and its tests. The plugin's QML must never receive a raw stream URL if the intended permission is only “play stations selected from Radio Browser.”

## What can run today

The QML scene and pure model are suitable for the isolated worker. Deterministic model tests continue to pass. Full station discovery and playback cannot run against the current reference implementation because unknown capabilities and operations correctly fail closed. Treating that denial as success would undermine the proposal this port is meant to validate.

## Reproducible baseline

The upstream behavior baseline is commit `d5e445e35f3e545fbbb10410aff08ff91fb80647` (`fix: avoid hidden atlas startup errors`). Its unmodified `./tests/run` passes. Omarchy's advisory migration scanner reports 41 findings: 16 critical, 16 high, eight review, and one informational. By detector, those are 13 executable-content findings, 11 QML process uses, five `FileView` uses, five computed filesystem paths, three environment reads, two Hyprland accesses, one Wayland import, and one manifest-entry-point record.

Reproduce that inventory from a clean export so the candidate directory does not affect the baseline:

```bash
baseline=$(mktemp -d /tmp/radio-atlas-baseline.XXXXXX)
git archive d5e445e35f3e545fbbb10410aff08ff91fb80647 | tar -x -C "$baseline"
omarchy plugin security scan "$baseline" --format json
```

`./tests/run` now executes both the unchanged behavior suite and `tests/secure-v2.test.mjs`. The latter freezes the bounded surface request, exact capability vocabulary, absence of ambient APIs in migrated QML, and byte identity of the reusable globe and station model.

Scanning `secure-v2/` alone currently reports zero advisory findings. That is evidence that the known ambient calls were removed, not evidence that the candidate is safe or complete. Manifest validation, the closed capability registry, user grants, sandbox enforcement, broker authorization, provider tests, and VM behavior proof remain authoritative; today the closed registry rejects the proposed provider capabilities.
