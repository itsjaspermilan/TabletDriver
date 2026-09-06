import SwiftUI
import TabletDriverKit

/// Draws strokes straight from the raw HID pen data -- bypassing the OS
/// cursor/click emulation entirely -- so you can visually confirm the
/// tablet is actually reporting position/pressure, independent of whether
/// any other app renders it.
struct TestAreaView: View {
    @ObservedObject var driver: DriverController

    @State private var strokes: [[CGPoint]] = []
    @State private var isDrawing = false

    private let canvasSize = CGSize(width: 412, height: 190)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            liveReadout

            Text("Draw here with the pen to confirm position and buttons are read correctly.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Canvas { context, size in
                for stroke in strokes {
                    guard stroke.count > 1 else { continue }
                    var path = Path()
                    path.move(to: stroke[0])
                    for point in stroke.dropFirst() {
                        path.addLine(to: point)
                    }
                    context.stroke(path, with: .color(.accentColor), lineWidth: 2)
                }
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
            .background(Color(nsColor: .textBackgroundColor))
            .border(Color.secondary.opacity(0.3))

            Button("Clear") { strokes.removeAll() }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onReceive(driver.$lastPenReport) { pen in
            guard let pen else { return }
            handle(pen)
        }
    }

    private var liveReadout: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
            GridRow {
                Text("Position").foregroundStyle(.secondary)
                Text(driver.lastPenReport.map { String(format: "%.0f%%, %.0f%%", $0.x * 100, $0.y * 100) } ?? "--")
            }
            GridRow {
                Text("Pressure").foregroundStyle(.secondary)
                HStack {
                    Text(driver.lastPenReport.map { String(format: "%.0f%%", $0.pressure * 100) } ?? "--")
                    ProgressView(value: driver.lastPenReport?.pressure ?? 0, total: 1)
                        .frame(width: 120)
                }
            }
            GridRow {
                Text("Tilt").foregroundStyle(.secondary)
                Text(driver.lastPenReport.map { "\($0.tiltX)°, \($0.tiltY)°" } ?? "--")
            }
            GridRow {
                Text("Eraser").foregroundStyle(.secondary)
                Text(driver.lastPenReport?.eraser == true ? "Active" : "--")
            }
            GridRow {
                Text("Pen buttons").foregroundStyle(.secondary)
                buttonDots(driver.lastPenButtons)
            }
            GridRow {
                Text("Express keys").foregroundStyle(.secondary)
                buttonDots(driver.lastAuxButtons)
            }
        }
    }

    private func buttonDots(_ states: [Bool]) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<states.count, id: \.self) { index in
                Circle()
                    .fill(states[index] ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(width: 10, height: 10)
            }
        }
    }

    private func handle(_ pen: PenReport) {
        let point = CGPoint(x: pen.x * canvasSize.width, y: pen.y * canvasSize.height)

        if pen.pressure > 0 {
            if !isDrawing {
                strokes.append([])
                isDrawing = true
            }
            strokes[strokes.count - 1].append(point)
        } else {
            isDrawing = false
        }
    }
}
