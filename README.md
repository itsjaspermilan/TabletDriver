# TabletDriver

A minimal, fully native (Swift, no .NET) macOS driver for graphics tablets,
built as an open-source alternative to vendor drivers (XP-Pen, Huion, etc).
Runs as a menu bar app. Built and signed as Apple Silicon (arm64) only — no
Rosetta, no Intel slice.

Currently ships support for the **XP-Pen Deco mini7 V2**. Adding a new
tablet doesn't require touching the driver's core — see
[CONTRIBUTING.md](CONTRIBUTING.md).

## Features

- Cursor movement + click emulation (pressure crossing a configurable
  threshold registers as a click — see "Known limitation" below).
- Configurable express-key and pen-button bindings, including per-app
  overrides (e.g. different bindings in Photoshop vs. Illustrator).
- Map the tablet's active area to a specific display, or to whichever app
  window is currently frontmost.
- A Test Area to confirm the tablet is being read correctly, independent of
  any other app.
- Install/uninstall via a real macOS login item (`SMAppService`), with a
  standalone `scripts/uninstall.sh` for cleanup if the app itself is
  already gone.

## Known limitation: pressure sensitivity

Cursor movement and click-from-pressure work reliably. Genuine graduated
pressure (e.g. brush size scaling continuously with pressure in
Affinity/Photoshop) was investigated and found to require macOS's HID
digitizer pipeline via a virtual HID device — which needs the restricted
`com.apple.developer.hid.virtual.device` entitlement. This was confirmed
blocked (both the classic `IOHIDUserDeviceCreateWithProperties` API and
CoreHID's modern `HIDVirtualDevice` equivalent returned `nil` without it) —
Apple grants this only to specific approved developers/vendors, not
self-assignable by a personal signing identity. This matches
[OpenTabletDriver](https://github.com/OpenTabletDriver/OpenTabletDriver)'s
own known limitation on macOS. Getting real pressure would require
enrolling in the paid Apple Developer Program and requesting that
entitlement from Apple, with no guarantee of approval.

## Credits

Device identifiers, HID report byte layouts, and the macOS permission /
CGEvent posting approach are ported from
[OpenTabletDriver](https://github.com/OpenTabletDriver/OpenTabletDriver)
(LGPL-3.0), specifically:

- `OpenTabletDriver.Configurations/Configurations/**/*.json` — vendor/product IDs, report lengths, wake-up output reports.
- `OpenTabletDriver.Configurations/Parsers/**` — input report byte layouts.
- `OpenTabletDriver.UX.MacOS/PermissionHelper.cs` — Input Monitoring / Accessibility permission check-and-request pattern.
- `OpenTabletDriver.Desktop/Interop/Input/{MacOSAbsolutePointer,MacOSVirtualMouse}.cs` — absolute cursor movement + click emulation via CGEvent.

## Building

Requires Xcode (not just Command Line Tools — SwiftUI's macro plugins
aren't in the CLT-only toolchain) and macOS 14+.

```bash
scripts/package-app.sh
```

Produces `build/TabletDriver.app`, verified arm64-only, signed with a
stable identifier (prefers a real "Apple Development" identity from your
login keychain over ad-hoc signing, since ad-hoc signing is unreliable for
Input Monitoring/Accessibility TCC grants — see CONTRIBUTING.md for why
this matters if you're developing locally). Move it to `/Applications` and
launch it.

### Getting a pre-built copy instead of building

This project is not notarized (that needs a paid Apple Developer Program
membership), so a pre-built `.app` someone shares with you will still show
Gatekeeper's "cannot verify this app" warning — right-click it in Finder
and choose **Open** once to run it. See [Releases](../../releases) for the
latest build, or build from source above if you'd rather not deal with
that dance.

## Testing

```bash
swift test
```

Runs `Tests/TabletDriverKitTests` — unit tests for report parsing
(`TabletProfile` implementations), binding persistence, screen-coordinate
mapping, and the click-emulation state machine. These are pure-logic tests
with no HID hardware or system permissions required, so they run the same
in CI as locally. Please add tests for new `TabletProfile`s the same way
`DecoMini7V2ProfileTests` does (known input bytes → expected parsed
values) — see [CONTRIBUTING.md](CONTRIBUTING.md).

## Uninstall

Use the app's menu bar "Uninstall…" item, or run `scripts/uninstall.sh` if
the app has already been removed.

## Contributing

Want to add support for your own tablet? See
[CONTRIBUTING.md](CONTRIBUTING.md) for a full walkthrough — it doesn't
require touching the driver's core, just implementing one `TabletProfile`.
If you're using Claude to help, point it at [CLAUDE.md](CLAUDE.md) first.
