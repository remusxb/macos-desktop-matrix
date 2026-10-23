# Standards

The rules this repository's code follows. Each has a number it keeps; a new rule takes the next free one and
a removed rule's number isn't reused. The tag after a rule says what holds it: **compiler**, **swift-format**,
**test** (with its name), or **review** when only a reader can. A rule a tool could check but none does yet is
a gap to close, not a reason to rely on review: write the check (S29).

Architecture, and why it's shaped this way: [ARCHITECTURE.md](ARCHITECTURE.md).

## Layout and dependencies

- **S1 Four modules, one direction.** `DesktopMatrix` (the app) depends on `DesktopMatrixSystem` and
  `DesktopMatrixUI`, which both depend only on `DesktopMatrixCore`. Core imports nothing but Foundation,
  CoreGraphics and os. *(compiler: Package.swift; test: coreImportsOnlyFoundationCoreGraphicsAndOS)*
- **S2 `main.swift` is wiring only:** build the parts, connect them, start. What the app does lives in
  `AppController`. *(review)*
- **S3 Code lives in the lowest module that can hold it.** Logic that doesn't need macOS goes in Core, where
  it's tested without macOS. *(review)*
- **S4 Private macOS symbols are declared once,** in `DesktopMatrixSystem/SkyLight.swift`, and looked up at
  runtime. *(test: onlySkyLightLooksUpPrivateSymbols)*
- **S5 A missing private symbol turns off the feature that needs it,** logged once; it never stops the app
  from launching. *(review)*

## Interfaces and construction

- **S6 The consumer declares the interface it needs,** listing only what it calls: `AppController`'s are in
  `DesktopMatrix/Interfaces.swift`, and the real types conform there. *(review)*
- **S7 Dependencies come in through `init`.** No singletons, no global mutable state; statics are constants.
  *(compiler, under Swift 6, for unprotected global state; review)*
- **S8 An adapter wraps one macOS facility** (desktops, switching, hotkeys, capture, pinning, the settings
  file, permissions) and holds no app logic. *(review)*

## Types and invariants

- **S9 Parse at the boundary.** Text from the settings file, a text field or a key press becomes a `KeyCombo`
  or a `Config` once; nothing past that point handles the raw string. *(review)*
- **S10 Prefer a type that can't hold a wrong value to a check.** A `KeyCombo` can't exist without ctrl, alt
  or cmd; a `Grid` has at least one tile. *(test: rejectsWhatCantBeBound, aGridHasAtLeastOneTile)*
- **S11 Settings files keep loading.** A change to `Config` reads every file an earlier version wrote.
  *(test: readsFilesFromEarlierVersions)*

## Concurrency

- **S12 Swift 6 language mode, complete concurrency checking,** in every target. *(compiler)*
- **S13 Whatever touches AppKit or the app's state is `@MainActor`.** A callback from C or AppKit that arrives
  on the main thread enters with `MainActor.assumeIsolated`, and says so. *(compiler; review)*
- **S14 `nonisolated(unsafe)` and `@preconcurrency`** only for system APIs not annotated yet. *(review)*

## Errors and logging

- **S15 One logger:** `Log.app` (`os.Logger`); no `print` or `NSLog`. *(test: nothingPrintsInsteadOfLogging)*
- **S16 A failure is logged once, where it's handled,** and the app carries on with that feature off. A
  missing permission, symbol or file never crashes it. *(review)*
- **S17 A log message says what failed and what that costs,** in lowercase. A value is `.public` only if it
  holds nothing personal: the app's own paths, combos, desktop numbers, error descriptions. *(review)*

## Constants

- **S18 A value with meaning gets a name in the type that owns it** (`Timing`, `Style`, `SymbolicHotKey`,
  `TileLayout`, `DockSwipe.Field`), even when it's used once: timings, sizes, private field ids, preference
  keys. There's no global constants file. *(review)*

## Code style

- **S19 `make fmt`, then a clean `make lint`,** against the repository's `.swift-format`. *(swift-format)*
- **S20 Every public declaration has a doc comment.** *(swift-format: AllPublicDeclarationsHaveDocumentation)*
- **S21 A comment says why;** it never restates the code. *(review)*
- **S22 No `try!`, no implicitly unwrapped optionals;** a force unwrap only on a value that can't fail, such as
  a literal, never on input. *(swift-format: NeverUseForceTry, NeverUseImplicitlyUnwrappedOptionals; review)*
- **S23 Access is as narrow as works:** private by default, internal across files, public only for what another
  module uses. *(compiler for cross-module use; review)*
- **S24 Names read as English at the call site;** no Manager, Helper or Util, no abbreviations beyond ID and
  URL. *(review)*

## Tests

- **S25 Logic has tests in its own module's test target;** `AppController` is tested through fakes of its
  interfaces. *(review)*
- **S26 Tests check behaviour** (what switches, what shows, what's saved), not how it's done. *(review)*
- **S27 A third-party binary format is pinned by golden bytes** kept in the test and reviewed like code: the
  IOHID swipe payload. *(test: hidPayloadMatchesTheGoldenBytes)*
- **S28 A rewrite that must not change behaviour** lands next to the old code with a test comparing their
  output, for one commit; the next commit deletes the old code. That's how the C swipe code became Swift.
  *(review)*
- **S29 What can be checked mechanically becomes a check** (a lint rule, a test, a guard test that reads the
  sources) rather than a sentence here. *(review)*

## Changes

- **S30 `make check` passes before every commit,** and CI runs it on every push and pull request. *(CI)*
- **S31 A change to the architecture updates [ARCHITECTURE.md](ARCHITECTURE.md) in the same commit;** a change
  a user would notice adds a line to [CHANGELOG.md](../CHANGELOG.md). *(review)*

## Definition of done

1. `make check` passes.
2. A change to System or UI is seen working on a real Mac: tests with fakes don't prove what macOS does.
3. The docs and the changelog say what changed.
