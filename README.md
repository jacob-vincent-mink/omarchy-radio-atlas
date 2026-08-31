# Radio Atlas

Explore live radio on a rotatable globe from the Omarchy bar. Click a station signal to play it, or click a country to browse its stations.

[View Radio Atlas on the Omarchy Plugin Marketplace](https://omarchyplugins.com/plugin.html?id=akshar.radio-atlas)

![Radio Atlas showing live stations across the globe](preview.png)

## Secure preview

The `secure-plugin-v2` branch is a migration candidate for Omarchy's proposed isolated plugin runtime, not the marketplace release and not currently installable on stock Omarchy. It keeps the original `Globe.qml` and `RadioModel.js`, but the host owns both windows and every effect crosses the typed runtime API. Final network and media providers and live multi-surface shell integration remain prerequisites.

The current port renders the globe, accepts drag and zoom, displays at most one bounded 64-station directory response, searches and filters that in-memory set locally, requests playback with opaque station handles, and exposes pause, stop, mute, volume, random selection, favorite, and recent-list controls. Its fixed local palette is not Omarchy theme-aware.

## Compatibility gaps

| Winner behavior | Secure preview today |
| --- | --- |
| Progressive cached world catalog of up to 5,000 stations | One provider response capped at 64 stations; no progressive expansion, background refresh, retry, or persistent directory cache |
| Remote Radio Browser refresh for search and country browsing | Search and country filtering operate only on the current 64-record in-memory set |
| Favorites and recent stations persist as usable station records | Only UUID lists are stored; after restart, an entry is reconstructed only if that station happens to be in the current bounded response, so full persistence parity is not met |
| Random tuning asks Radio Browser for a fresh station while excluding the current and recent UUIDs | Selects locally from the current bounded set and may repeat a recent station |
| Playlist previous/next, failed-stream auto-skip, and MPRIS integration | Not implemented by the port or proved for the intended media provider |
| `/`, arrow keys, Enter, Space, `R`, `F`, `+`/`-`, `M`, and Escape behavior | Up/Down and J/K, Enter, Space, `R`, and `F` are present; search focus, keyboard volume/mute, clear/close on Escape, and focus restoration are missing |
| Omarchy theme colors, typography, spacing, and light/dark globe adaptation | Replaced with fixed plugin-local Qt Quick colors and controls so isolated QML does not import a privileged shell presentation module |
| Bar middle click starts a random station | The authenticated surface API intentionally accepts only `open`, `toggle`, and `dismiss`; middle click currently toggles the atlas, and random remains an action inside it |
| Starting a station records a Radio Browser click | No click-count operation is declared or sent |
| Screensaver opening dismisses the atlas | No observation permission or sanitized observation provider is requested; this behavior is absent |
| Playing station drives country focus and rich track/playlist presentation | Basic bounded title and playback state remain; automatic country focus and playlist presentation are absent |
| Click-through behavior outside the desktop panel | Intended to be host-owned surface policy; not yet proved in a live shell generation |

See `secure-v2/PORTING.md` for the security boundary and validation status.

## Controls

| Input | Action |
| --- | --- |
| Drag globe | Rotate |
| Wheel over globe | Zoom |
| Click signal | Play station |
| Click country | Filter the bounded in-memory directory by country |
| Up / Down or J / K | Move through stations |
| Enter | Play selected station |
| Space | Play or pause |
| `R` | Tune a random station |
| `F` | Favorite selected station |

On the bar, left or middle press requests an authenticated atlas toggle, right press requests stop through the media provider, and the mouse wheel adjusts radio volume.

## Data and privacy

Station data is intended to come from the community-run [Radio Browser](https://www.radio-browser.info/) through a trusted `network.fetch` provider restricted to the declared HTTPS origin and `GET`. The isolated QML receives bounded station metadata and opaque playback handles, never raw stream URLs. A separate trusted media provider must resolve those handles and own playback. Neither final provider is included or live-proved by this plugin branch.

The QML requests a private, bounded storage entry for favorite UUIDs, recent UUIDs, and volume. It cannot select a host path. Labels are rendered as plain text. The port does not call Radio Browser's click-count endpoint.

Map geometry comes from public-domain Natural Earth data.

## Development

```bash
./tests/run
qmllint BarWidget.qml Globe.qml RadioAtlas.qml
```
