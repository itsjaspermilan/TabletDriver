import AppKit
import SwiftUI
import TabletDriverKit

/// Captures the next real key press (via a local NSEvent monitor) instead
/// of restricting the user to a fixed preset list.
final class ShortcutRecorderModel: ObservableObject {
    @Published var isRecording = false
    private var monitor: Any?

    func startRecording(onCapture: @escaping (ExpressKeyAction) -> Void) {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else { return event }
            let modifiers: [KeyModifier] = [
                event.modifierFlags.contains(.command) ? .command : nil,
                event.modifierFlags.contains(.option) ? .option : nil,
                event.modifierFlags.contains(.control) ? .control : nil,
                event.modifierFlags.contains(.shift) ? .shift : nil
            ].compactMap { $0 }

            onCapture(.keyboardShortcut(modifiers: modifiers, keyCode: event.keyCode))
            self.stopRecording()
            return nil
        }
    }

    func stopRecording() {
        isRecording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }
}

struct ShortcutRecorderButton: View {
    let action: ExpressKeyAction
    let onCapture: (ExpressKeyAction) -> Void
    @StateObject private var recorder = ShortcutRecorderModel()

    var body: some View {
        Button(recorder.isRecording ? "Press any key…" : KeyCodeNames.description(for: action)) {
            if recorder.isRecording {
                recorder.stopRecording()
            } else {
                recorder.startRecording { newAction in
                    onCapture(newAction)
                }
            }
        }
        .foregroundStyle(recorder.isRecording ? .orange : .primary)
        .onDisappear { recorder.stopRecording() }
    }
}
