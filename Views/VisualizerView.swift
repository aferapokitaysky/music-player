import SwiftUI

enum VisualizerMode: String {
    case bars
    case wave
}

struct VisualizerView: View {
    let bars: [Double]
    let isPlaying: Bool
    @State var mode: VisualizerMode = .bars
    @EnvironmentObject var themeManager: ThemeManager

    private var palette: Palette { themeManager.theme.palette }

    var body: some View {
        VStack(spacing: 10) {
            header
            // Visualizer container — single Canvas redraw, no per-cell animations.
            ZStack {
                if mode == .bars {
                    BarsCanvas(bars: bars, isDark: themeManager.theme == .dark, palette: palette)
                } else {
                    WaveCanvas(bars: bars, palette: palette)
                }
            }
            .frame(minHeight: 130)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(palette.cardElevated.opacity(themeManager.theme == .dark ? 1.0 : 0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(palette.stroke, lineWidth: 1)
            )
            .padding(.horizontal, 18)
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(isPlaying ? palette.accent : palette.textTertiary)
                    .frame(width: 6, height: 6)
                Text("AUDIO SPECTRUM")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.6)
                    .foregroundColor(palette.textTertiary)
            }
            Spacer()
            HStack(spacing: 0) {
                segmentButton(title: "BARS", selected: mode == .bars) { mode = .bars }
                segmentButton(title: "WAVE", selected: mode == .wave) { mode = .wave }
            }
            .padding(3)
            .background(Capsule().fill(palette.inset))
            .overlay(Capsule().stroke(palette.stroke, lineWidth: 1))
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }

    private func segmentButton(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .tracking(1.4)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .foregroundColor(selected
                                 ? (themeManager.theme == .dark ? .black : .white)
                                 : palette.textSecondary)
                .background(
                    Capsule().fill(selected ? palette.textPrimary : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Bars Canvas (single-pass draw)
struct BarsCanvas: View {
    let bars: [Double]
    let isDark: Bool
    let palette: Palette

    var body: some View {
        Canvas(rendersAsynchronously: true) { ctx, size in
            let n = bars.count
            guard n > 0 else { return }
            let cellCount = 14
            let hPad: CGFloat = 14
            let vPad: CGFloat = 14
            let spacing: CGFloat = 3
            let cellGap: CGFloat = 2

            let totalSpacing = spacing * CGFloat(n - 1)
            let barWidth = max(2.0, (size.width - totalSpacing - hPad * 2) / CGFloat(n))
            let cellHeight = max(1, (size.height - vPad * 2 - cellGap * CGFloat(cellCount - 1)) / CGFloat(cellCount))

            // Top white, bottom dim — monochrome gradient (or inverted in light)
            let topShade: Double = isDark ? 1.00 : 0.00
            let midShade: Double = isDark ? 0.78 : 0.30
            let lowShade: Double = isDark ? 0.45 : 0.55

            for i in 0..<n {
                let x = hPad + CGFloat(i) * (barWidth + spacing)
                let activeCells = Int(bars[i] * Double(cellCount))

                for c in 0..<cellCount {
                    let cellIndex = (cellCount - 1) - c   // 0 = bottom
                    let isActive = cellIndex <= activeCells
                    let y = vPad + CGFloat(c) * (cellHeight + cellGap)
                    let rect = CGRect(x: x, y: y, width: barWidth, height: cellHeight)
                    let path = Path(roundedRect: rect, cornerRadius: 1.5)

                    if isActive {
                        let t = Double(cellIndex) / Double(cellCount - 1)
                        let shade: Double
                        if t > 0.66 { shade = topShade }
                        else if t > 0.33 { shade = midShade }
                        else { shade = lowShade }
                        ctx.fill(path, with: .color(Color(white: shade)))
                    } else {
                        ctx.fill(path, with: .color(Color(white: isDark ? 1.0 : 0.0).opacity(0.06)))
                    }
                }
            }
            _ = palette // silence unused
        }
        .drawingGroup() // CoreAnimation backed for speed
    }
}

// MARK: - Wave Canvas
struct WaveCanvas: View {
    let bars: [Double]
    let palette: Palette

    var body: some View {
        TimelineView(.animation) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate
            Canvas(rendersAsynchronously: true) { ctx, size in
                drawWave(ctx: ctx, size: size, phaseOffset: 0,
                         baseColor: palette.accent, lineWidth: 3, opacity: 0.95, time: phase)
                drawWave(ctx: ctx, size: size, phaseOffset: .pi * 0.5,
                         baseColor: palette.accentSecondary, lineWidth: 2.5, opacity: 0.7, time: phase)
                drawWave(ctx: ctx, size: size, phaseOffset: .pi * 1.1,
                         baseColor: palette.textPrimary, lineWidth: 1.2, opacity: 0.85, time: phase)
            }
            .drawingGroup()
        }
    }

    private func drawWave(ctx: GraphicsContext, size: CGSize,
                          phaseOffset: Double, baseColor: Color,
                          lineWidth: CGFloat, opacity: Double, time: Double) {
        guard bars.count > 1 else { return }
        var path = Path()
        let w = size.width
        let h = size.height
        let midY = h / 2.0
        let step = w / CGFloat(bars.count - 1)

        for i in 0..<bars.count {
            let x = CGFloat(i) * step
            let barVal = bars[i]
            let sineFactor = sin(Double(i) * 0.4 + phaseOffset + time * 1.1)
            let yOffset = CGFloat(barVal) * (h / 2.2) * CGFloat(sineFactor)
            let y = midY + yOffset

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                let prevX = CGFloat(i - 1) * step
                let prevBarVal = bars[i - 1]
                let prevSine = sin(Double(i - 1) * 0.4 + phaseOffset + time * 1.1)
                let prevY = midY + CGFloat(prevBarVal) * (h / 2.2) * CGFloat(prevSine)
                let cx1 = prevX + step / 2.0
                let cy1 = prevY
                let cx2 = prevX + step / 2.0
                let cy2 = y
                path.addCurve(
                    to: CGPoint(x: x, y: y),
                    control1: CGPoint(x: cx1, y: cy1),
                    control2: CGPoint(x: cx2, y: cy2)
                )
            }
        }
        ctx.stroke(path, with: .color(baseColor.opacity(opacity)),
                   style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
    }
}
