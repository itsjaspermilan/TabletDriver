import Foundation
import os

private let logger = Logger(subsystem: "com.tabletdriver.app", category: "storage")

/// Loads and saves the small JSON settings files under Application Support.
///
/// Writes are atomic, and a file that exists but no longer decodes is moved
/// aside rather than treated as "no settings yet" -- otherwise the very next
/// save silently overwrote the user's only copy with defaults.
enum PersistedJSON {
    static func load<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            let backup = url.appendingPathExtension("corrupt")
            logger.error("\(url.lastPathComponent, privacy: .public) failed to decode (\(error.localizedDescription, privacy: .public)); moving it to \(backup.lastPathComponent, privacy: .public)")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: url, to: backup)
            return nil
        }
    }

    static func save<T: Encodable>(_ value: T, to url: URL) {
        do {
            let data = try JSONEncoder().encode(value)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: .atomic)
        } catch {
            logger.error("failed to save \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}
