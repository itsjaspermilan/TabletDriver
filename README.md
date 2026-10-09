# TabletDriver

A minimal, fully native (Swift, no .NET) macOS driver for graphics tablets,
built as an open-source alternative to vendor drivers (XP-Pen, Huion, etc).
Runs as a menu bar app. Built and signed as Apple Silicon (arm64) only — no
Rosetta, no Intel slice.

Currently ships support for the **XP-Pen Deco mini7 V2**. Adding a new
tablet doesn't require touching the driver's core — see
[CONTRIBUTING.md](CONTRIBUTING.md).

## Features

- Cursor movement + genuine graduated pressure sensitivity (brush size/
  opacity in Affinity, Photoshop, etc. respond continuously to pressure,
  not just an on/off click threshold — see "Pressure sensitivity" below).
- Configurable express-key and pen-button bindings, including per-app
  overrides (e.g. different bindings in Photoshop vs. Illustrator).
- Map the tablet's active area to a specific display, or to whichever app
  window is currently frontmost.
- A Pressure Test page to confirm the tablet is being read correctly, independent of
  any other app.
- Install/uninstall via a real macOS login item (`SMAppService`), with a
  standalone `scripts/uninstall.sh` for cleanup if the app itself is
  already gone.

## Pressure sensitivity

Real per-app graduated pressure took real effort to get right, so it's
worth documenting how it actually works. macOS's native tablet-pointer
`CGEvent` mechanism can carry genuine pressure/tilt on an ordinary
mouse-type event, but two things have to be true for Adobe-class apps
(Affinity, Photoshop, etc.) to trust it:

1. `CGEventField.mouseEventSubtype` must be set to mark the event as a
   tablet point/proximity event *before* any other tablet field is set —
   fields live in a type/subtype-determined union, so setting them in the
   wrong order silently drops the values.
2. The proximity event must carry a Wacom-specific capability bitmask and
   a stable nonzero device ID. Per-app support for third-party (non-Wacom)
   tablet pressure on macOS is inconsistent enough that Adobe-class apps
   apparently gate real pressure recognition on seeing this mask — see
   `CursorPoster.swift`'s doc comment for the exact bits and why.

This was ported from a real fix in
[OpenTabletDriver](https://github.com/OpenTabletDriver/OpenTabletDriver)'s
`0.6.x` release branch (PR #3761, "Fix support for pressure sensitivity in
Adobe software on macOS") — note that OTD's `master`/`avalonia` branches
(an in-progress rewrite) do *not* contain this fix, only the `0.6.x`
branch actual releases are cut from; two earlier attempts in this
project's history failed because they were based on reading the wrong
branch. A virtual HID device (the "textbook correct" approach) was also
investigated and confirmed blocked by the restricted
`com.apple.developer.hid.virtual.device` entitlement (both the classic
`IOHIDUserDeviceCreateWithProperties` API and CoreHID's modern
`HIDVirtualDevice` returned `nil` without it) — the CGEvent-subtype
approach above turned out to not need it at all.

## Credits

Device identifiers, HID report byte layouts, and the macOS permission /
CGEvent posting approach are ported from
[OpenTabletDriver](https://github.com/OpenTabletDriver/OpenTabletDriver)
(LGPL-3.0), specifically:

- `OpenTabletDriver.Configurations/Configurations/**/*.json` — vendor/product IDs, report lengths, wake-up output reports.
- `OpenTabletDriver.Configurations/Parsers/**` — input report byte layouts.
- `OpenTabletDriver.UX.MacOS/PermissionHelper.cs` — Input Monitoring / Accessibility permission check-and-request pattern.
- `OpenTabletDriver.Desktop/Interop/Input/{MacOSAbsolutePointer,MacOSVirtualMouse}.cs` — absolute cursor movement + click emulation via CGEvent.
- `OpenTabletDriver.Desktop/Interop/Input/MacOSVirtualMouse.cs` on the `0.6.x` branch specifically (PR #3761) — the `mouseEventSubtype`/Wacom-capability-mask technique behind real pressure sensitivity.

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

### Sharing a build

```bash
VERSION=1.1 scripts/package-release.sh
```

Produces `build/TabletDriver-1.1.dmg` and `.zip` that anyone on an Apple
Silicon Mac (macOS 14+) can install. Without a paid "Developer ID
Application" identity the build is ad-hoc signed, so the recipient has to
approve it once:

1. Drag TabletDriver into Applications and try to open it.
2. Open **System Settings → Privacy & Security**, scroll down, and click
   **Open Anyway** (or run `xattr -cr /Applications/TabletDriver.app` in
   Terminal before the first launch).
3. Grant Input Monitoring and Accessibility when prompted.

With a Developer ID identity in your keychain the script uses it
automatically, and setting `NOTARY_PROFILE=<notarytool keychain profile>`
also notarizes and staples it so recipients see no warning at all.

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
