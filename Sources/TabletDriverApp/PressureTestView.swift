import SwiftUI
import TabletDriverKit

/// Draws straight from the raw HID pen data -- bypassing the OS cursor and
/// click emulation entirely -- so you can confirm the tablet is reporting
/// position and graduated pressure independent of any other app.
struct PressureTestView: View {
    @ObservedObject var driver: DriverController

    @State private var strokes: [[Sample]] = []
    @State private var history: [Double] = []
    @State private var peak = 0.0
    @State private var isDrawing = false

    private struct Sample {
        let point: CGPoint
        let pressure: Double
    }

    private let historyLength = 200

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Pressure Test").font(.largeTitle.weight(.bold))
                Spacer()
                Button("Clear") {
                    strokes.removeAll()
                    peak = 0
                }
                .glassButton()
            }

            GlassContainer {
                HStack(alignment: .top, spacing: 16) {
                    canvas
                    sidePanel.frame(width: 220)
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 8)
        .padding(.bottom, 28)
        .onReceive(driver.$lastPenReport) { pen in
            guard let pen else { return }
            handle(pen)
        }
    }

    private var pressure: Double { driver.lastPenReport?.pressure ?? 0 }

    private var canvas: some View {
        Canvas { context, size in
            for stroke in strokes {
                for (a, b) in zip(stroke, stroke.dropFirst()) {
                    var path = Path()
                    path.move(to: CGPoint(x: a.point.x * size.width, y: a.point.y * size.height))
                    path.addLine(to: CGPoint(x: b.point.x * size.width, y: b.point.y * size.height))
                    let level = (a.pressure + b.pressure) / 2
                    context.stroke(
                        path,
                        with: .color(strokeColor(level)),
                        style: StrokeStyle(lineWidth: 1 + level * 16, lineCap: .round)
                    )
                }
            }

            if let pen = driver.lastPenReport {
                let center = CGPoint(x: pen.x * size.width, y: pen.y * size.height)
                let radius = 6 + pen.pressure * 14
                context.stroke(
                    Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                    with: .color(.white.opacity(0.8)),
                    lineWidth: 1.5
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            if strokes.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "scribble.variable").font(.largeTitle)
                    Text("Draw with the pen")
                        .font(.headline)
                    Text("Press lightly, then harder — line width follows pressure.")
                        .font(.callout)
                }
                .foregroundStyle(.white.opacity(0.5))
                .allowsHitTesting(false)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .glassCard()
    }

    private var sidePanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Pressure").font(.caption).foregroundStyle(.secondary)
                Text("\(Int(pressure * 100))%")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                gauge
                HStack {
                    Text("Peak \(Int(peak * 100))%")
                    Spacer()
                    Text("Click at \(Int(driver.clickThreshold * 100))%")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Last few seconds").font(.caption).foregroundStyle(.secondary)
                graph.frame(height: 70)
            }

            Divider()

            readoutRow("Position", driver.lastPenReport.map { String(format: "%.0f%%, %.0f%%", $0.x * 100, $0.y * 100) } ?? "--")
            readoutRow("Tilt", driver.lastPenReport.map { "\($0.tiltX)°, \($0.tiltY)°" } ?? "--")
            readoutRow("Eraser", driver.lastPenReport?.eraser == true ? "Active" : "--")
            VStack(alignment: .leading, spacing: 6) {
                Text("Pen buttons").font(.caption).foregroundStyle(.secondary)
                buttonDots(driver.lastPenButtons)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Express keys").font(.caption).foregroundStyle(.secondary)
                buttonDots(driver.lastAuxButtons)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxHeight: .infinity, alignment: .top)
        .glassCard()
    }

    private var gauge: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.1))
                Capsule()
                    .fill(LinearGradient(colors: [.cyan, .indigo, .pink], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(8, proxy.size.width * pressure))
                    .animation(.easeOut(duration: 0.08), value: pressure)
                Rectangle()
                    .fill(.primary.opacity(0.6))
                    .frame(width: 2, height: 14)
                    .offset(x: proxy.size.width * driver.clickThreshold - 1)
            }
        }
        .frame(height: 12)
    }

    private var graph: some View {
        Canvas { context, size in
            guard history.count > 1 else { return }
            let step = size.width / CGFloat(historyLength - 1)
            let offset = CGFloat(historyLength - history.count) * step
            var line = Path()
            for (index, value) in history.enumerated() {
                let point = CGPoint(x: offset + CGFloat(index) * step, y: size.height * (1 - value))
                if index == 0 { line.move(to: point) } else { line.addLine(to: point) }
            }
            var fill = line
            fill.addLine(to: CGPoint(x: size.width, y: size.height))
            fill.addLine(to: CGPoint(x: offset, y: size.height))
            fill.closeSubpath()
            context.fill(fill, with: .linearGradient(
                Gradient(colors: [.indigo.opacity(0.5), .indigo.opacity(0)]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: size.height)
            ))
            context.stroke(line, with: .color(.indigo), lineWidth: 1.5)
        }
        .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func readoutRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit()
        }
    }

    private func buttonDots(_ states: [Bool]) -> some View {
        HStack(spacing: 5) {
            ForEach(0..<states.count, id: \.self) { index in
                Circle()
                    .fill(states[index] ? Color.accentColor : Color.primary.opacity(0.15))
                    .frame(width: 11, height: 11)
            }
        }
    }

    private func strokeColor(_ level: Double) -> Color {
        Color(hue: 0.55 + 0.4 * level, saturation: 0.7, brightness: 1)
    }

    private func handle(_ pen: PenReport) {
        history.append(pen.pressure)
        if history.count > historyLength { history.removeFirst(history.count - historyLength) }
        peak = max(peak, pen.pressure)

        let sample = Sample(point: CGPoint(x: pen.x, y: pen.y), pressure: pen.pressure)
        if pen.pressure > 0 {
            if !isDrawing {
                strokes.append([])
                isDrawing = true
            }
            strokes[strokes.count - 1].append(sample)
        } else {
            isDrawing = false
        }
    }
}
