# CLAUDE.md

Guidance for Claude Code (or any Claude-based assistant) working in this
repository.

## What this project is

A fully native Swift macOS menu-bar driver for graphics tablets (no .NET,
no vendor SDKs), currently supporting the XP-Pen Deco mini7 V2. It's an
open-source alternative to vendor tablet drivers. Real per-app graduated
pressure sensitivity (Affinity, Photoshop, etc.) already works — read
[README.md](README.md)'s "Pressure sensitivity" section and
`CursorPoster.swift`'s doc comment before touching anything pressure-related.
The short version: it needs `CGEventField.mouseEventSubtype` set (in the
right order) plus a spoofed Wacom capability mask on the proximity event,
ported from OpenTabletDriver's `0.6.x` branch (not `master`/`avalonia`,
which don't have this fix). A virtual HID device was also investigated and
confirmed blocked by a restricted, non-self-assignable Apple entitlement —
don't re-suggest that path, it's a dead end that the CGEvent-subtype
approach above turned out not to need anyway.

## Most common task: adding a new tablet

If asked to "add support for tablet X," follow
[CONTRIBUTING.md](CONTRIBUTING.md) exactly. In short:

1. Find the tablet's USB vendor/product ID (`system_profiler SPUSBDataType`
   or `ioreg -p IOUSB -w0`, tablet plugged in).
2. Check OpenTabletDriver's device configs (GitHub, often the `avalonia`
   branch, not `master`) for that exact model — reuse its VID/PID, report
   lengths, wake-up report, and report-parsing byte layout, porting the
   referenced C# parser class to Swift. `Sources/TabletDriverKit/Profiles/DecoMini7V2Profile.swift`
   is the template — its doc comment names exactly which upstream files it
   ported from; do the same for the new one.
3. If OTD doesn't have it, the user needs to physically capture raw HID
   reports for you to interpret — the app already logs the first 20 raw
   input reports as hex (`DeviceMonitor.handleInputReport`). Ask the user
   to run `log stream --predicate 'subsystem == "com.tabletdriver.app"' --style compact`
   while moving the pen/pressing buttons, and paste you the output. Reason
   about it the same way `PenReport`'s existing parsers do (which bytes
   change monotonically with X/Y movement, which climb with pressure,
   which bits flip per button).
4. Implement `TabletProfile` (protocol in `Sources/TabletDriverKit/Profiles/TabletProfile.swift`)
   in a new file under `Sources/TabletDriverKit/Profiles/`, normalizing
   `PenReport.x`/`.y`/`.pressure` to `0...1` in `parsePenReport` — nothing
   else in the driver deals in raw device units.
5. Register the new profile in `TabletProfileRegistry.all`.
6. Write `Tests/TabletDriverKitTests/YourTabletProfileTests.swift` (copy
   `DecoMini7V2ProfileTests`'s structure), run `swift test`, and make sure
   it passes before touching real hardware -- it's what actually proves
   the byte-offset reasoning, independent of the physical device.
7. Build (`scripts/package-app.sh`), install
   (`cp -R build/TabletDriver.app /Applications/`), and verify against the
   Settings → Pressure Test page before declaring it done.

## Architecture map

- `Sources/TabletDriverKit/Profiles/` — one `TabletProfile` per supported
  tablet, plus the registry. This is the only place device-specific
  constants/parsing should live.
- `Sources/TabletDriverKit/HID/DeviceMonitor.swift` — IOKit HID matching
  (against every registered profile's VID/PID at once), seizing, and
  dispatching raw reports to whichever profile matched.
- `Sources/TabletDriverKit/Output/` — `ScreenMapper` (tablet-area → screen
  coordinates, works in normalized 0...1 space), `CursorPoster` (CGEvent
  cursor/click emulation *and* real per-app pressure sensitivity —
  read its doc comment before changing anything here), `ShortcutExecutor`
  (express-key/pen-button action execution).
- `Sources/TabletDriverKit/Mapping/BindingStore.swift` — persisted
  per-app express-key/pen-button bindings.
- `Sources/TabletDriverKit/DriverController.swift` — wires HID input to
  output; the one class that owns the whole pipeline.
- `Sources/TabletDriverApp/` — the SwiftUI menu-bar app and Settings UI.
- `scripts/package-app.sh` — builds, verifies arm64-only, signs (prefers a
  real "Apple Development" identity over ad-hoc — see below), packages.
- `scripts/uninstall.sh` — standalone cleanup script.

## Environment quirks worth knowing before debugging

These cost real time to discover the first time; don't rediscover them:

- **Never launch or kill the app yourself from a coding-agent shell** to
  test a permissions flow. macOS attributes Input Monitoring/Accessibility
  grants to whatever process launched the app; launching from an agent's
  shell instead of Finder/the user's own Terminal reassigns that
  attribution and can even cause macOS to record a fresh *denial*,
  clobbering a working grant. Ask the user to launch it themselves and
  report back; read logs (`log show`) to verify, don't launch to verify.
- **Ad-hoc code signing (`codesign --sign -`) breaks TCC permission
  persistence** — Input Monitoring/Accessibility grants won't reliably
  survive rebuilds without a real signing identity with a stable Team ID.
  `scripts/package-app.sh` already prefers any "Apple Development" identity
  found in the login keychain; don't revert that to ad-hoc signing.
- **IOHIDDevice as a Dictionary key is unsafe.** `IOHIDManager` fires its
  own internal "initial enumeration" callback for already-connected
  devices *in addition to* any manual catch-up loop you write for
  already-present devices — using `IOHIDDevice`'s derived `Hashable`
  across those two call paths corrupted a `Dictionary`'s storage in this
  project's history (crashed with a bogus allocation size). Key any
  per-device state by `Unmanaged.passUnretained(device).toOpaque()`
  instead.
- **`IOHIDDeviceSetReport` (the synchronous variant) can block for ~5
  seconds** per HID interface that doesn't support the report being sent
  (common — a composite tablet exposes several interfaces and usually
  only one accepts a given vendor command). Don't "fix" the resulting
  beachball by dispatching the call onto a background GCD queue — IOKit
  HID calls aren't safe from a different thread than the one the device
  is scheduled on, and doing this silently broke the tablet's real
  mode-switch in this project's history. Use the async
  `IOHIDDeviceSetReportWithCallback` instead.
- **Never call methods on a `@StateObject` from a SwiftUI `App`'s
  `init()`.** SwiftUI can create a second, throwaway instance before the
  real one is installed on a view — in this project that meant two
  `DeviceMonitor`s both trying to seize the same HID device, and crashed
  with SIGSEGV. Do first-run setup in a `.task {}` attached to the
  scene's content instead.
- **`Slider(value:in:step:)` with a small `step` over a large range hangs
  the UI.** SwiftUI computes tick-mark label layout proportional to
  range/step; a slider like `Slider(value:in: 1...16383, step: 1)` pegged
  the main thread indefinitely in this project's history. Omit `step`
  unless you actually need discrete increments, and if you do, keep the
  number of steps small.
- **When reading a reference project's source (e.g. OpenTabletDriver) to
  port a technique, check which branch its actual releases are cut from,
  not just `master`/the default branch.** OTD's real releases come from a
  `0.6.x` branch; `master`/`avalonia` are an in-progress rewrite that is
  missing real fixes (including the macOS pressure-sensitivity one this
  project needed). Reading only the default branch produced a confident,
  fully-researched, *wrong* conclusion earlier in this project's history.
- **`CGEvent` tablet fields must be set in the right order.** Fields are
  stored in a type/subtype-determined union; setting
  `CGEventField.mouseEventSubtype` *after* the other tablet fields
  silently drops them. Set subtype first. See `CursorPoster.swift`.

## Code style

Match the existing codebase: no comments explaining *what* code does
(identifiers should already make that clear); a short comment only for a
genuinely non-obvious constraint or historical gotcha (see the examples
above — that's the bar). Small, focused files per concern rather than one
large file. No premature abstraction for hypothetical future tablets
beyond the `TabletProfile` seam that already exists.
