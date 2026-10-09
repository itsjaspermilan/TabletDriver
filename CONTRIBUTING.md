# Contributing a new tablet

Adding support for a tablet this driver doesn't yet know about means
implementing one `TabletProfile` and adding it to a registry — nothing
else in the driver needs to change. `Sources/TabletDriverKit/Profiles/DecoMini7V2Profile.swift`
is a complete, working example to copy from.

## 1. Find your tablet's USB vendor ID and product ID

With the tablet plugged in:

```bash
system_profiler SPUSBDataType | grep -B6 -i "your tablet's name"
```

or

```bash
ioreg -p IOUSB -w0 | grep -B2 -A10 -i "your tablet's name"
```

Look for `Vendor ID` and `Product ID` (they may be printed in hex like
`0x28bd` or decimal like `10429` — `TabletProfile.vendorID`/`.productID`
are plain `Int`, hex literals like `0x28BD` are fine).

## 2. Check whether OpenTabletDriver already supports it

This is the fastest path. Search
[OpenTabletDriver's device configs](https://github.com/OpenTabletDriver/OpenTabletDriver/tree/avalonia/OpenTabletDriver.Configurations/Configurations)
(note: many newer devices are on the `avalonia` branch, not `master`) for
your exact model name. If it's there, the JSON config gives you:

- `DigitizerIdentifiers[0].VendorID` / `.ProductID`
- `InputReportLength` / `OutputReportLength`
- `OutputInitReport` (a base64 string — decode it to get the wake-up report bytes, if present)
- `Specifications.Digitizer.MaxX` / `.MaxY`
- `Specifications.Pen.MaxPressure`
- `Specifications.AuxiliaryButtons.ButtonCount` (express keys)
- `ReportParser` — the C# class name, e.g. `XP_PenReportParser`. Find that
  class and the report struct it dispatches to
  (`OpenTabletDriver.Configurations/Parsers/<Vendor>/`) — that's your byte
  layout to port to Swift. `DecoMini7V2Profile.swift`'s doc comment shows
  exactly which OTD files were ported for that device; do the same for
  yours.

## 3. If OTD doesn't have it: capture and read the raw reports yourself

Build and run the app (`scripts/package-app.sh`), then watch the unified
log while moving the pen and pressing buttons:

```bash
log stream --predicate 'subsystem == "com.tabletdriver.app"' --style compact
```

`DeviceMonitor` logs the first 20 raw input reports as hex automatically.
Move the pen in one direction and watch which bytes change monotonically
(that's your X or Y axis), press harder and watch which bytes climb
(pressure), and press each express key/pen button to see which bit
flips. This is genuinely trial-and-error — expect to spend real time on
it. `DecoMini7V2Profile`'s comments explain what a working byte layout
looks like once you have one.

## 4. Implement `TabletProfile`

Create `Sources/TabletDriverKit/Profiles/YourTabletProfile.swift`:

```swift
public struct YourTabletProfile: TabletProfile {
    public let name = "Your Tablet Name"
    public let vendorID = 0x....
    public let productID = 0x....
    public let inputReportLength = ...
    public let outputReportLength = ...
    public let outputInitReport: [UInt8] = [...] // [] if not needed
    public let maxX: Double = ...
    public let maxY: Double = ...
    public let maxPressure: UInt16 = ...
    public let auxButtonCount = ...
    public let penButtonCount = ...

    public init() {}

    public func isOutOfRange(_ report: [UInt8]) -> Bool { ... }
    public func isAuxReport(_ report: [UInt8]) -> Bool { ... }
    public func parsePenReport(_ report: [UInt8]) -> PenReport? { ... }
    public func parseAuxReport(_ report: [UInt8]) -> AuxReport { ... }
}
```

`parsePenReport` must return `PenReport.x`/`.y`/`.pressure` already
normalized to `0...1` (divide by your `maxX`/`maxY`/`maxPressure`) — the
rest of the driver (cursor mapping, click emulation, the Pressure Test page) is
written entirely in normalized terms and doesn't know or care which
tablet is connected.

## 5. Register it

Add your profile to `Sources/TabletDriverKit/Profiles/TabletProfileRegistry.swift`:

```swift
public static let all: [TabletProfile] = [
    DecoMini7V2Profile(),
    YourTabletProfile()
]
```

## 6. Write unit tests for the parsing logic

Add `Tests/TabletDriverKitTests/YourTabletProfileTests.swift` following
`DecoMini7V2ProfileTests` — construct a few known byte arrays by hand
(pick simple values you can compute the expected normalized result for)
and assert `parsePenReport`/`parseAuxReport`/`isOutOfRange`/`isAuxReport`
return what you expect. Run with `swift test`. This is what actually
proves your byte-offset reasoning is right, independent of whether the
physical tablet happens to behave the way you assumed.

## 7. Test it against the real hardware

Rebuild, launch, and open Settings → Pressure Test. Move the pen and confirm
position/pressure/tilt update live and correctly, then press each express
key and pen button and confirm the right dot lights up. This is the same
tool used to validate the original Deco mini7 V2 support.

## 8. Send a pull request

One profile per PR is easiest to review. Mention which OTD config (if any)
you ported from, or how you reverse-engineered the layout if not.

## A note on licensing

Byte-level report layouts and device identifiers ported from
OpenTabletDriver are factual descriptions of a device's own USB protocol —
translating them into Swift for this project is consistent with OTD's
LGPL-3.0 license, but please still credit the source file(s) in your new
profile's doc comment, the way `DecoMini7V2Profile` does.
