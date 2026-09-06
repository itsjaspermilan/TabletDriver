import XCTest
@testable import TabletDriverKit

final class KeyCodeNamesTests: XCTestCase {
    func testKnownKeyCodeName() {
        XCTAssertEqual(KeyCodeNames.name(for: 0), "A")
        XCTAssertEqual(KeyCodeNames.name(for: 36), "Return")
    }

    func testUnknownKeyCodeFallsBackToNumericLabel() {
        XCTAssertEqual(KeyCodeNames.name(for: 9999), "Key 9999")
    }

    func testDescriptionOrdersModifiersConsistently() {
        // Order should always be control, option, shift, command, regardless
        // of the order they're passed in.
        let description = KeyCodeNames.description(modifiers: [.command, .shift, .control], keyCode: 0)
        XCTAssertEqual(description, "⌃⇧⌘A")
    }

    func testDescriptionForActionVariants() {
        XCTAssertEqual(KeyCodeNames.description(for: .none), "None")
        XCTAssertEqual(
            KeyCodeNames.description(for: .keyboardShortcut(modifiers: [.command], keyCode: 6)),
            "⌘Z"
        )
        XCTAssertEqual(
            KeyCodeNames.description(for: .launchApp(bundleIdentifier: "com.example.app")),
            "Launch com.example.app"
        )
    }
}
