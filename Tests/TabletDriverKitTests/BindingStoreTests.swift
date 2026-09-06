import XCTest
@testable import TabletDriverKit

final class BindingStoreTests: XCTestCase {
    var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BindingStoreTests-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    func testUnsetBindingIsNone() {
        let store = BindingStore(applicationSupportDirectory: tempDirectory)
        XCTAssertEqual(store.binding(context: BindingStore.defaultContext, kind: .expressKey, index: 0), .none)
    }

    func testSetAndReadBindingRoundTrips() {
        let store = BindingStore(applicationSupportDirectory: tempDirectory)
        let action = ExpressKeyAction.keyboardShortcut(modifiers: [.command], keyCode: 6)

        store.setBinding(action, kind: .expressKey, index: 3, context: BindingStore.defaultContext)

        XCTAssertEqual(store.binding(context: BindingStore.defaultContext, kind: .expressKey, index: 3), action)
    }

    func testExpressKeyAndPenButtonNamespacesAreIndependent() {
        let store = BindingStore(applicationSupportDirectory: tempDirectory)
        store.setBinding(.keyboardShortcut(modifiers: [], keyCode: 1), kind: .expressKey, index: 0, context: BindingStore.defaultContext)
        store.setBinding(.keyboardShortcut(modifiers: [], keyCode: 2), kind: .penButton, index: 0, context: BindingStore.defaultContext)

        XCTAssertEqual(store.binding(context: BindingStore.defaultContext, kind: .expressKey, index: 0), .keyboardShortcut(modifiers: [], keyCode: 1))
        XCTAssertEqual(store.binding(context: BindingStore.defaultContext, kind: .penButton, index: 0), .keyboardShortcut(modifiers: [], keyCode: 2))
    }

    func testBindingsForUnknownAppFallsBackToDefault() {
        let store = BindingStore(applicationSupportDirectory: tempDirectory)
        let action = ExpressKeyAction.keyboardShortcut(modifiers: [.shift], keyCode: 10)
        store.setBinding(action, kind: .expressKey, index: 2, context: BindingStore.defaultContext)

        let result = store.bindings(for: "com.unknown.app", kind: .expressKey, count: 4)

        XCTAssertEqual(result, [.none, .none, action, .none])
    }

    func testAppOverrideTakesPrecedenceOverDefault() {
        let store = BindingStore(applicationSupportDirectory: tempDirectory)
        let defaultAction = ExpressKeyAction.keyboardShortcut(modifiers: [.command], keyCode: 1)
        let overrideAction = ExpressKeyAction.keyboardShortcut(modifiers: [.command], keyCode: 2)

        store.setBinding(defaultAction, kind: .expressKey, index: 0, context: BindingStore.defaultContext)
        store.addAppContext("com.example.app")
        store.setBinding(overrideAction, kind: .expressKey, index: 0, context: "com.example.app")

        XCTAssertEqual(store.bindings(for: "com.example.app", kind: .expressKey, count: 1), [overrideAction])
        XCTAssertEqual(store.bindings(for: "com.other.app", kind: .expressKey, count: 1), [defaultAction])
    }

    func testAddAndRemoveAppContext() {
        let store = BindingStore(applicationSupportDirectory: tempDirectory)
        store.addAppContext("com.example.app")
        XCTAssertTrue(store.appContextOrder.contains("com.example.app"))

        store.removeAppContext("com.example.app")
        XCTAssertFalse(store.appContextOrder.contains("com.example.app"))
        XCTAssertEqual(store.bindings(for: "com.example.app", kind: .expressKey, count: 1), [.none])
    }

    func testAddingDefaultContextOrEmptyIdentifierIsNoOp() {
        let store = BindingStore(applicationSupportDirectory: tempDirectory)
        store.addAppContext("")
        store.addAppContext(BindingStore.defaultContext)
        XCTAssertTrue(store.appContextOrder.isEmpty)
    }

    func testPersistsAcrossInstances() {
        let action = ExpressKeyAction.launchApp(bundleIdentifier: "com.example.app")
        do {
            let store = BindingStore(applicationSupportDirectory: tempDirectory)
            store.setBinding(action, kind: .penButton, index: 1, context: BindingStore.defaultContext)
        }

        let reloaded = BindingStore(applicationSupportDirectory: tempDirectory)
        XCTAssertEqual(reloaded.binding(context: BindingStore.defaultContext, kind: .penButton, index: 1), action)
    }
}
