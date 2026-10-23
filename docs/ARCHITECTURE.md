# Architecture

Workspace Matrix is a menu bar app that lays macOS's own desktops out as a grid. It never emulates desktops:
it reads where macOS is and asks macOS to switch, so Mission Control, swipes and the grid always agree.

## Modules

```mermaid
flowchart TD
    App["WorkspaceMatrix<br/>main.swift: wiring<br/>AppController: what the app does"]
    UI["WorkspaceMatrixUI<br/>Overlay, Settings, StatusMenu"]
    System["WorkspaceMatrixSystem<br/>Desktops, DesktopSwitcher, DockSwipe,<br/>HotKeys, ScreenCapture, DesktopPinning,<br/>ConfigFile, Permissions, SkyLight"]
    Core["WorkspaceMatrixCore<br/>Grid, KeyCombo, Config,<br/>Navigator, TileLayout, Log"]
    App --> UI
    App --> System
    UI --> Core
    System --> Core
```

| module | holds | may import |
|---|---|---|
| Core | the logic that doesn't need macOS: grid steps, key combos, settings and their file format, the switch queue, tile geometry | Foundation, CoreGraphics, os |
| System | one adapter per macOS facility; every private call | Core, AppKit, Carbon, ScreenCaptureKit |
| UI | the grid HUD, the settings window, the menu bar icon | Core, AppKit, SwiftUI |
| App | `AppController` and the interfaces it needs; `main.swift`, which builds everything and connects it | all of the above |

System and UI don't know about each other: where one needs the other, the app passes it in (the HUD is pinned
above the desktops by a function from System, handed to it as a closure). `AppController` sees System and UI
only through the interfaces in `Interfaces.swift`, so its tests run on fakes.

## A key press

```mermaid
sequenceDiagram
    participant K as HotKeys
    participant A as AppController
    participant N as Navigator
    participant S as DesktopSwitcher
    participant M as macOS
    K->>A: ctrl+cmd+right
    A->>A: grid step from the current desktop, shown on the HUD at once
    A->>N: request(desktop)
    N->>S: switchTo(desktop), unless a switch is still landing
    S->>M: the desktop shortcut (Normal) or a synthetic swipe (Instant)
    M-->>A: active space changed
    A->>N: arrived(at:)
    N-->>A: there, or a stop on the way: then it jumps to the latest request
    A->>A: keep the HUD up, refresh that desktop's preview
```

- **The Navigator** exists because macOS drops desktop shortcuts pressed while it's still switching. Presses
  that arrive mid-switch are folded into one jump to the last one, and a switch that never lands is retried
  once.
- **The HUD shows only for the app's keys.** Every desktop change, by any means, still updates the position
  and the previews.
- **Previews:** at launch, each desktop's preview is composed from its windows over the wallpaper, like
  Mission Control does; after that a screenshot replaces it whenever you arrive on or leave that desktop.

## Private APIs

macOS has no public API for desktops. These are the private ones, all declared in `SkyLight.swift` and looked
up at runtime; none needs System Integrity Protection off.

| call | for | without it |
|---|---|---|
| `SLSMainConnectionID`, `SLSGetActiveSpace`, `SLSCopyManagedDisplaySpaces` | which desktop is active, how many there are | the app can't tell where you are; keys don't move |
| `SLSCopySpacesForWindows` | which desktop a window is on, for previews at launch | tiles stay empty until visited |
| `SLSSpaceCreate`, `SLSSpaceSetAbsoluteLevel`, `SLSShowSpaces`, `SLSAddWindowsToSpaces` | a space of the HUD's own above the desktops, so it stays still while they slide | the HUD slides with the desktops |
| undocumented CGEvent gesture fields and the IOHID payload (`DockSwipe`) | Instant switching | Normal switching still works |

Instant switching is ported from [InstantSpaceSwitcher](https://github.com/jurplel/InstantSpaceSwitcher)
(MIT); its golden test holds the exact bytes the Dock receives.

## Distribution

`make install` builds the app bundle into `~/Applications`, signs it ad hoc with a fixed designated
requirement (so the permissions macOS granted survive rebuilds), and runs it as a launchd agent at login.
