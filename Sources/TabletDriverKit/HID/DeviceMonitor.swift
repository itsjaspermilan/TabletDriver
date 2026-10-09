import Foundation
import IOKit.hid
import os

private let logger = Logger(subsystem: "com.tabletdriver.app", category: "hid")

/// Opens whichever connected device matches one of the given
/// `TabletProfile`s as a raw HID device (bypassing macOS's generic
/// HID/mouse handling, mirroring OpenTabletDriver's `IOHIDManager` +
/// seize-on-open approach on macOS) and dispatches parsed pen/aux reports.
public final class DeviceMonitor {
    public var onPenReport: ((PenReport) -> Void)?
    public var onAuxReport: ((AuxReport) -> Void)?
    public var onDeviceConnected: ((TabletProfile) -> Void)?
    public var onDeviceDisconnected: (() -> Void)?
    public var onPenOutOfRange: (() -> Void)?

    private let profiles: [TabletProfile]
    private var manager: IOHIDManager?

    private struct ManagedDevice {
        let profile: TabletProfile
        let buffer: UnsafeMutablePointer<UInt8>
    }
    // Keyed by the device's raw CF pointer identity rather than IOHIDDevice
    // itself as a Dictionary key -- IOHIDManager fires its own internal
    // "initial enumeration" callback in addition to the manual catch-up
    // loop below for already-connected devices, and using IOHIDDevice's
    // derived Hashable conformance across those two call paths corrupted
    // this dictionary's storage (crashed with a bogus allocation size).
    // Raw pointer identity has no such ambiguity.
    private var devices: [UnsafeMutableRawPointer: ManagedDevice] = [:]

    private func key(for device: IOHIDDevice) -> UnsafeMutableRawPointer {
        Unmanaged.passUnretained(device).toOpaque()
    }

    public init(profiles: [TabletProfile]) {
        self.profiles = profiles
    }

    public func start() {
        logger.log("start() called, matching \(self.profiles.count) known tablet profile(s)")

        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = manager

        let matching: [[String: Any]] = profiles.map {
            [kIOHIDVendorIDKey: $0.vendorID, kIOHIDProductIDKey: $0.productID]
        }
        IOHIDManagerSetDeviceMatchingMultiple(manager, matching as CFArray)

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, deviceMatchedCallback, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, deviceRemovedCallback, context)

        // `.commonModes`, not `.defaultMode`: AppKit switches the main run
        // loop to `.eventTrackingRunLoopMode` for the duration of any mouse
        // button press anywhere in the frontmost app (even one we posted
        // ourselves), and a source scheduled only on `.defaultMode` goes
        // completely silent for as long as that tracking session lasts.
        // That starved our own HID input callback the instant a click
        // began, so no further tablet reports -- including the one meant
        // to release that same click -- could be processed until a real
        // mouse click elsewhere ended the tracking session from outside;
        // IOKit keeps queuing reports underneath regardless, so everything
        // backed up during the freeze then played back in a rapid burst.
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        logger.log("IOHIDManagerOpen result=\(openResult)")

        if let existingDevices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> {
            logger.log("already-matched devices at open time: \(existingDevices.count)")
            // The matching callback only reliably fires for devices that
            // connect *after* this point; a tablet already plugged in
            // before the app launched needs to be picked up explicitly
            // here, or it never gets seized until unplug/replug.
            for device in existingDevices {
                handleDeviceMatched(device)
            }
        }
    }

    public func stop() {
        for managed in devices.values {
            managed.buffer.deallocate()
        }
        devices.removeAll()
        if let manager {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        manager = nil
    }

    private func profile(for device: IOHIDDevice) -> TabletProfile? {
        let vid = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? Int
        let pid = IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? Int
        return profiles.first { $0.vendorID == vid && $0.productID == pid }
    }

    fileprivate func handleDeviceMatched(_ device: IOHIDDevice) {
        let deviceKey = key(for: device)
        guard devices[deviceKey] == nil else {
            logger.log("device matched again while already open, ignoring")
            return
        }
        guard let profile = profile(for: device) else {
            logger.error("matched device has no corresponding TabletProfile, ignoring")
            return
        }

        let product = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? "?"
        let usagePage = IOHIDDeviceGetProperty(device, kIOHIDPrimaryUsagePageKey as CFString) as? Int ?? -1
        logger.log("device matched: \(product, privacy: .public) (\(profile.name, privacy: .public)), usagePage=\(UInt32(bitPattern: Int32(usagePage)), format: .hex)")

        // Real per-app pressure turned out not to depend on seize state at
        // all -- it needed the correct CGEvent fields (see CursorPoster).
        // Seizing exclusively is kept since it avoids any chance of macOS's
        // own generic HID pipeline fighting over cursor position.
        let seizeResult = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
        logger.log("IOHIDDeviceOpen (seize) result=\(seizeResult)")
        guard seizeResult == kIOReturnSuccess else { return }

        let bufferLength = profile.inputReportLength
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferLength)
        devices[deviceKey] = ManagedDevice(profile: profile, buffer: buffer)

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(device, buffer, bufferLength, inputReportCallback, context)
        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)

        logger.log("registered input report callback, buffer length=\(bufferLength)")
        onDeviceConnected?(profile)

        // Only one of a tablet's matched interfaces typically accepts this
        // vendor "wake" report; the others take several seconds to time
        // out. Using the async IOKit API (rather than calling the blocking
        // API from a background GCD queue, which raced the device's real
        // mode-switch and silently broke continuous streaming) avoids
        // blocking the main thread without moving IOHIDDevice calls off
        // the run loop/thread the device is actually scheduled on.
        if !profile.outputInitReport.isEmpty {
            sendWakeReport(to: device, profile: profile)
        }
    }

    fileprivate func handleDeviceRemoved(_ device: IOHIDDevice) {
        logger.log("device removed")
        if let managed = devices.removeValue(forKey: key(for: device)) {
            managed.buffer.deallocate()
        }
        onDeviceDisconnected?()
    }

    private var reportLogCount = 0

    fileprivate func handleInputReport(sender: UnsafeMutableRawPointer, bytes: UnsafePointer<UInt8>, length: CFIndex) {
        guard let managed = devices[sender] else { return }
        let profile = managed.profile
        let raw = Array(UnsafeBufferPointer(start: bytes, count: length))

        if reportLogCount < 20 {
            reportLogCount += 1
            let hex = raw.map { String(format: "%02x", $0) }.joined(separator: " ")
            logger.log("input report (\(length) bytes): \(hex, privacy: .public)")
        }

        if profile.isOutOfRange(raw) {
            onPenOutOfRange?()
            return
        }
        if profile.isAuxReport(raw) {
            onAuxReport?(profile.parseAuxReport(raw))
            return
        }
        if let pen = profile.parsePenReport(raw) {
            onPenReport?(pen)
        }
    }

    private func sendWakeReport(to device: IOHIDDevice, profile: TabletProfile) {
        var report = profile.outputInitReport
        report.append(contentsOf: repeatElement(0, count: max(0, profile.outputReportLength - report.count)))

        let ctx = WakeReportContext(report: report)
        let contextPtr = Unmanaged.passRetained(ctx).toOpaque()

        let submitResult = IOHIDDeviceSetReportWithCallback(
            device,
            kIOHIDReportTypeOutput,
            CFIndex(profile.outputInitReport[0]),
            ctx.buffer,
            ctx.length,
            5.0,
            wakeReportCompletionCallback,
            contextPtr
        )
        logger.log("sendWakeReport (async) submit result=\(submitResult)")
    }
}

/// Owns a stable buffer for the duration of an in-flight async
/// `IOHIDDeviceSetReportWithCallback` call -- a Swift Array's transient
/// buffer pointer isn't valid once the closure that produced it returns,
/// which an async completion outlives.
private final class WakeReportContext {
    let buffer: UnsafeMutablePointer<UInt8>
    let length: Int

    init(report: [UInt8]) {
        length = report.count
        buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
        buffer.update(from: report, count: length)
    }

    deinit {
        buffer.deallocate()
    }
}

private func wakeReportCompletionCallback(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    type: IOHIDReportType,
    reportID: UInt32,
    report: UnsafeMutablePointer<UInt8>,
    length: CFIndex
) {
    guard let context else { return }
    logger.log("sendWakeReport (async) completion result=\(result)")
    Unmanaged<WakeReportContext>.fromOpaque(context).release()
}

private func deviceMatchedCallback(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    device: IOHIDDevice
) {
    guard let context else { return }
    let monitor = Unmanaged<DeviceMonitor>.fromOpaque(context).takeUnretainedValue()
    monitor.handleDeviceMatched(device)
}

private func deviceRemovedCallback(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    device: IOHIDDevice
) {
    guard let context else { return }
    let monitor = Unmanaged<DeviceMonitor>.fromOpaque(context).takeUnretainedValue()
    monitor.handleDeviceRemoved(device)
}

private func inputReportCallback(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    type: IOHIDReportType,
    reportID: UInt32,
    report: UnsafeMutablePointer<UInt8>,
    length: CFIndex
) {
    guard let context, let sender else { return }
    let monitor = Unmanaged<DeviceMonitor>.fromOpaque(context).takeUnretainedValue()
    monitor.handleInputReport(sender: sender, bytes: report, length: length)
}
