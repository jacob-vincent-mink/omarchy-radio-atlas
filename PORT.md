# Ward compatibility branch

This branch retains Radio Atlas's globe, catalog/search/cache helpers, station model, saved state, player controls and mpv status script. It requires Ward's `networkProxy` and `audioPlayback` permissions and the shared service runtime. This is a fork PR, not a change to the original author's repository.

## Permissions and boundaries

- Required private storage holds favorites, history, volume and caches under the sandbox's home. Existing unsandboxed saves are not imported automatically.
- Optional `networkProxy` lets sandboxed curl/mpv contact public Internet destinations through Ward's HTTP/CONNECT proxy. It includes opaque TCP tunnels and can transmit data; it is not a domain or URL allowlist. Direct networking and local/private destinations remain unavailable.
- Optional `audioPlayback` accepts PCM samples decoded by mpv inside the worker. It grants neither microphone input nor capture of other applications' audio.
- There are no host-exec grants and no `player-status` filesystem grant. The former installed host component is no longer used by this manifest. No privileged installation is needed.

One `Service.qml` owns the foreground player process and watches the sandbox-local `status.json`. All bar placements share that service, and the panel consumes its cached status. Closing the panel or removing one bar placement does not stop another placement's player. Disabling/revoking the plugin or stopping its worker stops playback. Stop empties the playlist while leaving the one supervised session idle for another station.

The sandboxed session uses Ward's existing private network namespace and localhost proxy. It never calls the older nested-namespace wrapper. The original `radio-proxy`/`radio-sandbox` implementation remains only for the trusted/non-Ward path and its upstream regression tests; it is not Ward's security boundary. Decoding, volume, mute, playlists and player IPC remain inside the worker. Ward's host audio backend receives only fixed-format PCM, never a station URL or plugin-supplied filename.

Publishing a player to desktop MPRIS controls is not included in these permissions. The panel and bar controls work locally; the old host player's MPRIS behavior is not claimed for this adaptation.

## Review and enable

Use a matching native Ward build and freshly staged shared runtime. Install this fork's `rust-sandbox-compat` branch through the usual plugin workflow, then review the immutable revision. For catalog access and playback:

```bash
omarchy plugin review akshar.radio-atlas
omarchy plugin approve akshar.radio-atlas --revision <reviewed-revision> \
  --allow-storage --allow-network-proxy --allow-audio-playback
omarchy plugin enable akshar.radio-atlas
```

Stop the plugin before reapproval, and review again after bundle changes. Requests are not grants. Declining playback or proxy access keeps the local UI available but prevents a live playback session. These permissions do not include microphone or system-output recording.

## Verification

The new adaptation passed repeated bounded private-display trials with the matching native runtime and staged adapter. The original catalog populated through Ward's proxy, and sandbox-local mpv streamed a live HTTPS station into Ward's PCM endpoint for more than ten seconds. A private synthetic PipeWire output received nonzero samples. Pause/resume updated the original status script and panel; removing a second bar placement left the one shared decoder and surviving widget running. Revocation removed every tracked controller, worker, decoder, audio backend and proxy process. The rendered globe, catalog and playing panel were inspected.

With proxy and playback declined, the UI still loaded, reported missing playback/proxy access, created no decoder or audio backend, and produced no samples. The test's synthetic audio server had no real hardware source or sink; no speakers, microphone or desktop audio were used. These checks do not claim every station protocol, physical output or MPRIS publication.

The earlier compatibility trials covered the former host-exec adapter: original globe/catalog, search and rotation, keyboard focus, Escape, outside-click dismissal, silent live playback, volume/mute, previous/next, favorites/history and revocation. Those historical results are not evidence for the new PCM/proxy transport.

The original README's unsandboxed removal and state paths do not apply to Ward. `omarchy plugin disable akshar.radio-atlas` stops its worker; private saved data is retained. Player diagnostics now live inside the worker at `$XDG_RUNTIME_DIR/omarchy-radio-atlas/mpv.log`, not in the former host component's directories.
