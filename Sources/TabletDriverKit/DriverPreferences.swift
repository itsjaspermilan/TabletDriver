import CoreGraphics
import Foundation

/// Persists the click-pressure threshold and screen-mapping target so they
/// survive app restarts (previously these lived only in memory and reset
/// to a hardcoded default on every launch).
public final class DriverPreferences: ObservableObject {
    /// 0...1, normalized against the connected tablet's own maximum
    /// pressure (see `PenReport.pressure`).
    @Published public var clickThreshold: Double {
        didSet { save() }
    }
    @Published public var mappingTarget: ScreenMapper.Target {
        didSet { save() }
    }

    private let fileURL: URL

    public init(applicationSupportDirectory: URL) {
        fileURL = applicationSupportDirectory.appendingPathComponent("preferences.json")

        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(Stored.self, from: data) {
            clickThreshold = decoded.clickThreshold
            mappingTarget = decoded.mappingTarget
        } else {
            clickThreshold = 0.025
            mappingTarget = .display(CGMainDisplayID())
        }
    }

    private func save() {
        let stored = Stored(clickThreshold: clickThreshold, mappingTarget: mappingTarget)
        guard let data = try? JSONEncoder().encode(stored) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: fileURL)
    }

    private struct Stored: Codable {
        var clickThreshold: Double
        var mappingTarget: ScreenMapper.Target
    }
}
