# Ward compatibility branch

This branch retains Radio Atlas's original globe, catalog/search/cache helpers, station model, state files, player controls, stream proxy and mpv status script. It requires the Ward preview with reviewed `lifetime: "plugin"` foreground jobs and host-owned screensaver dismissal. This is a fork PR, not a change to the original author's repository.

## Permissions and boundaries

- Required private storage holds favorites, history, volume and caches. Worker-local `HOME/.local/share/radio-atlas/state.json` is the same file as the host's plugin DATA path plus `.local/share/radio-atlas/state.json`. Existing unsandboxed saves are not imported automatically.
- Optional networking lets the original catalog helper contact Radio Browser, refresh its caches and report station clicks. Ward's network grant is broad, including local services; it is not a domain allowlist.
- The optional `player-status` folder is read-only and should point to `~/.local/state/radio-atlas-ward/status`. Both original UI surfaces watch its atomically replaced `status.json`; there is no status-polling loop.
- The installed `radio-atlas-ward-host` CLI accepts only the enumerated controls and bounded volume/station arguments. The worker supplies one fixed JSON selection through DATA. The CLI refuses symlinks, special files, oversized selections and non-HTTP(S) stream URLs. No plugin-supplied code path, command, player socket or process ID is accepted.
- `radio-session:session` is an explicitly reviewed long-running foreground job. The bar owns its QML Process; closing the panel leaves playback alive, while stopping the caller, disabling/revoking the plugin or stopping its controller kills the entire job group. Other controls retain the ordinary ten-second deadline and share the second exec slot.

The user-installed host component contains the original player/session/proxy code at a fixed path. It retains mpv's host audio and MPRIS integration, including the original bounded public-destination network proxy. Private player sockets, locks, queue files and process tracking live under `$XDG_RUNTIME_DIR/radio-atlas-ward`, never in worker-writable DATA. Stop empties the playlist but keeps the supervised mpv session idle for another station.

Ward pins the installed CLI's bytes, not its interpreter, dependencies or adjacent installed player files. Installing or updating this host component is a separate user-authorized setup operation. A plugin update or approval never installs or replaces it.

## Install the host component

From this reviewed checkout, in a terminal:

```bash
sudo install -d -m755 /usr/local/lib/radio-atlas-ward
sudo install -m644 radio-player radio-session radio-sandbox radio-state radio-proxy radio-status.lua manifest.json /usr/local/lib/radio-atlas-ward/
sudo chmod 755 /usr/local/lib/radio-atlas-ward/radio-player /usr/local/lib/radio-atlas-ward/radio-session /usr/local/lib/radio-atlas-ward/radio-sandbox /usr/local/lib/radio-atlas-ward/radio-state
sudo install -m755 radio-host /usr/local/bin/radio-atlas-ward-host
install -d -m700 "$HOME/.local/state/radio-atlas-ward/status"
```

Install this fork's `rust-sandbox-compat` branch through the usual plugin workflow. Review the immutable revision, then select the desired grants. For full functionality:

```bash
omarchy plugin review akshar.radio-atlas
omarchy plugin approve akshar.radio-atlas --revision <reviewed-revision> \
  --allow-storage --allow-network \
  --read "player-status=$HOME/.local/state/radio-atlas-ward/status" \
  --exec radio-session:session \
  --exec radio-control:status --exec radio-control:play \
  --exec radio-control:toggle --exec radio-control:previous --exec radio-control:next \
  --exec radio-control:mute --exec radio-control:stop --exec radio-control:volume
omarchy plugin enable akshar.radio-atlas
```

Review again after changing the bundle or installed CLI. Stop the plugin before reapproval. Review is not activation, and declaring access does not select it.

## Verification

The original regression suite passes, including catalog caching/fallback, saved-state validation, player cancellation and proxy destination restrictions. Temporary external Ward trials exercised the original UI with declined grants, real catalog browsing/search, silent live playback beyond ten seconds, event-driven metadata, keyboard pause and Escape, mute/volume, previous/next, favorites/history and rejection of extra or invalid control arguments. Revocation was verified against the actual mpv process, not just the controller's status. Separate selection checks reject symlinked files/directories, FIFOs, oversized JSON and unsafe URL schemes. These experiments are not shipped as tests in either repository.

The installed desktop was checked at 1600×1000 logical pixels with scale 2: original globe/catalog, search and rotation, bar opening, one-click keyboard focus, Escape, programmatic opening and outside-click dismissal. The host retains bar placement across restart and dismisses the panel on screensaver launch without forwarding compositor events. Playback tests were silent; audible speaker output was not tested. The local screensaver exited immediately even with plugin panels closed, so sustained screensaver display is not claimed here.

The original README's unsandboxed removal and state paths do not apply to this branch. `omarchy plugin disable akshar.radio-atlas` stops the supervised player; private saved data is retained. Host diagnostics are in `$XDG_RUNTIME_DIR/radio-atlas-ward/omarchy-radio-atlas/mpv.log` and `proxy.log`.
