# Workspace Matrix

Your macOS desktops as a grid. Move between them with `ctrl+cmd+arrows`, like GNOME's
Workspace Matrix, with a HUD that shows where you are and a preview of every desktop.

![The grid while switching desktops](docs/overlay.png)

## Features

- **Real desktops**: the grid is the native macOS desktops (Spaces), the same ones Mission Control
  and trackpad swipes show. Nothing is hidden or emulated.
- **Any grid**: 3×3, 4×4, 2×5... up to the 16 desktops macOS allows.
- **Previews** of every desktop, composed from its windows at launch and refreshed with a screenshot
  each time you arrive on or leave a desktop.
- **Instant switching** (optional): no slide animation.
- **The grid stays put** in the middle of the screen while the desktop changes underneath, and it also
  shows up when you switch some other way (swipes, Mission Control, your desktop shortcuts).
- **No lost presses**: presses made while macOS is still switching are folded into one jump to the
  last one, so the grid never runs ahead of the screen.
- **Settings** from the menu bar icon, applied as you change them, with key combo recording.

<img src="docs/settings.png" width="420" alt="Settings window">

## Requirements

- macOS 14 or later (developed on macOS 27).
- A Swift toolchain: Xcode, or the Command Line Tools (`xcode-select --install`).
- For Normal switching, the "Switch to Desktop N" shortcuts enabled in System Settings → Keyboard →
  Keyboard Shortcuts → Mission Control. The app presses them for you; Instant switching doesn't need them.

## Install

```sh
git clone https://github.com/remusxb/macos-workspace-matrix.git
cd macos-workspace-matrix
make install
```

This builds `~/Applications/WorkspaceMatrix.app` and starts it now and at every login. macOS then asks
for two permissions for **Workspace Matrix** in System Settings → Privacy & Security:

- **Accessibility**, to switch desktops.
- **Screen & System Audio Recording**, for the previews (optional: without it tiles show their number).

Run `make restart` after granting them. `make uninstall` removes the app and the login item.

## Settings

Menu bar icon → Settings…. Everything is saved to `~/.config/workspace-matrix/config.json`, which you
can also edit by hand (then `make restart`); every field is optional, see `config.example.json`.

| field | default | |
|---|---|---|
| `rows`, `cols` | `3`, `3` | grid size; tiles past the last desktop can't be reached |
| `wrap` | `false` | moving off an edge wraps around to the other side |
| `keys` | `ctrl+cmd+up/down/left/right` | combos for `up`, `down`, `left`, `right` |
| `tileWidth` | `160` | tile width in points, shrunk so the grid never exceeds 90% of the screen |
| `hideAfter` | `0.6` | seconds the grid stays after the last move |
| `instant` | `false` | switch desktops with no slide animation |

A combo is `modifier+...+key` with at least one of `ctrl`, `cmd`, `alt` (plus `shift` if you like),
and a key from `a`–`z`, `0`–`9`, `up`, `down`, `left`, `right`. Errors go to
`~/Library/Logs/workspace-matrix.log`.

## How it works

- It reads which desktop you're on through read-only private SkyLight calls, the way Spaces
  indicator apps do.
- Normal switching presses your own "Switch to Desktop N" shortcut. Instant switching posts a
  synthetic trackpad swipe so fast that macOS skips the animation, using code from
  [InstantSpaceSwitcher](https://github.com/jurplel/InstantSpaceSwitcher).
- The grid lives in its own always-visible space above the desktops, so it doesn't slide with them.

None of this needs System Integrity Protection turned off, but private APIs can change with any macOS
update.

## Limitations

- One display: the grid follows the main screen's desktops.
- It can't add or remove desktops (macOS has no API for it): use Mission Control's **+**.
- Windows move between desktops the usual way, by dragging them in Mission Control.

## Develop

```sh
make test
swift run
```

## Credits

Instant switching is vendored from [InstantSpaceSwitcher](https://github.com/jurplel/InstantSpaceSwitcher)
by jurplel, under the MIT license (`Sources/ISS/LICENSE`).

## License

[MIT](LICENSE)
