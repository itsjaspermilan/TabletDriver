import Foundation

/// Every tablet this driver knows how to talk to. Add your new
/// `TabletProfile` here to make it available -- see CONTRIBUTING.md.
public enum TabletProfileRegistry {
    public static let all: [TabletProfile] = [
        DecoMini7V2Profile()
    ]
}
