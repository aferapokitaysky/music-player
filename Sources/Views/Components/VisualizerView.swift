import SwiftUI

enum VisualizerMode: String, CaseIterable {
    case bars
    case wave
    case circle
    case dots
}

struct VisualizerView: View {
    @ObservedObject var hfState: HighFrequencyState
    let isPlaying: Bool
    @AppStorage("visualizerMode") var mode: VisualizerMode = .bars
    @EnvironmentObject var themeManager: ThemeManager
    @Namespace private var visualizerNamespace

    private var palette: Palette { themeManager.theme.palette }

    var body: some View {
        VStack(spacing: 10) {
            header
            // Visualizer container — single Canvas redraw, no per-cell animations.
            ZStack {
                switch mode {
                case .bars:
                    BarsCanvas(bars: hfState.visualizerBars, isDark: themeManager.theme == .dark, palette: palette)
                case .wave:
                    WaveCanvas(bars: hfState.visualizerBars, isPlaying: isPlaying, palette: palette)
                case .circle:
                    CircleCanvas(bars: hfState.visualizerBars, palette: palette)
                case .dots:
                    DotsCanvas(bars: hfState.visualizerBars, palette: palette)
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
                ForEach(VisualizerMode.allCases, id: \.self) { m in
                    Button(action: {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                            mode = m
                        }
                    }) {
                        Text(m.rawValue.uppercased())
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .tracking(1.2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .foregroundColor(mode == m
                                             ? (themeManager.theme == .dark ? .black : .white)
                                             : palette.textSecondary)
                            .background(
                                ZStack {
                                    if mode == m {
                                        Capsule()
                                            .fill(palette.textPrimary)
                                            .matchedGeometryEffect(id: "activeSegment", in: visualizerNamespace)
                                    }
                                }
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(Capsule().fill(palette.inset))
            .overlay(Capsule().stroke(palette.stroke, lineWidth: 1))
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
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

            for i in 0..<n {
                let x = hPad + CGFloat(i) * (barWidth + spacing)
                let activeCells = Int(bars[i] * Double(cellCount))

                for c in 0..<cellCount {
                    let cellIndex = (cellCount - 1) - c   // 0 = bottom
                    let isActive = cellIndex < activeCells
                    let y = vPad + CGFloat(c) * (cellHeight + cellGap)
                    let rect = CGRect(x: x, y: y, width: barWidth, height: cellHeight)
                    let path = Path(roundedRect: rect, cornerRadius: 1.5)

                    if isActive {
                        let t = Double(cellIndex) / Double(cellCount - 1)
                        let color: Color
                        if t > 0.66 {
                            color = palette.accent
                        } else if t > 0.33 {
                            color = palette.accentSecondary
                        } else {
                            color = palette.accentSecondary.opacity(0.65)
                        }
                        ctx.fill(path, with: .color(color))
                    } else {
                        ctx.fill(path, with: .color(palette.textPrimary.opacity(0.04)))
                    }
                }
            }
            _ = isDark // silence unused
        }
        .drawingGroup() // CoreAnimation backed for speed
    }
}

// MARK: - Wave Canvas
struct WaveCanvas: View {
    let bars: [Double]
    let isPlaying: Bool
    let palette: Palette

    var body: some View {
        Group {
            if isPlaying {
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
            } else {
                Canvas(rendersAsynchronously: true) { ctx, size in
                    drawWave(ctx: ctx, size: size, phaseOffset: 0,
                             baseColor: palette.accent, lineWidth: 3, opacity: 0.95, time: 0.0)
                    drawWave(ctx: ctx, size: size, phaseOffset: .pi * 0.5,
                             baseColor: palette.accentSecondary, lineWidth: 2.5, opacity: 0.7, time: 0.0)
                    drawWave(ctx: ctx, size: size, phaseOffset: .pi * 1.1,
                             baseColor: palette.textPrimary, lineWidth: 1.2, opacity: 0.85, time: 0.0)
                }
                .drawingGroup()
            }
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
        
        // Premium Triple-Pass Neon Glowing Laser Ribbon Effect
        // 1. Wide ambient glow background layer
        ctx.stroke(path, with: .color(baseColor.opacity(opacity * 0.16)),
                   style: StrokeStyle(lineWidth: lineWidth * 3.6, lineCap: .round, lineJoin: .round))
        
        // 2. Focused vibrant core glow layer
        ctx.stroke(path, with: .color(baseColor.opacity(opacity * 0.42)),
                   style: StrokeStyle(lineWidth: lineWidth * 1.8, lineCap: .round, lineJoin: .round))
        
        // 3. High-intensity sharp white core core layer
        ctx.stroke(path, with: .color(baseColor.opacity(opacity)),
                   style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
    }
}

// MARK: - Circle Canvas
struct CircleCanvas: View {
    let bars: [Double]
    let palette: Palette

    var body: some View {
        Canvas(rendersAsynchronously: true) { ctx, size in
            let n = bars.count
            guard n > 0 else { return }
            
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let maxRadius = min(size.width, size.height) / 2.3
            let minRadius = maxRadius * 0.40
            
            // Draw a soft ambient glow circle in the middle
            let innerPath = Path(ellipseIn: CGRect(
                x: center.x - minRadius,
                y: center.y - minRadius,
                width: minRadius * 2,
                height: minRadius * 2
            ))
            ctx.fill(innerPath, with: .color(palette.accent.opacity(0.04)))
            ctx.stroke(innerPath, with: .color(palette.accent.opacity(0.15)), lineWidth: 1)
            
            let angleStep = (2.0 * Double.pi) / Double(n)
            
            for i in 0..<n {
                let angle = Double(i) * angleStep
                let barVal = bars[i]
                
                let startX = center.x + CGFloat(cos(angle)) * minRadius
                let startY = center.y + CGFloat(sin(angle)) * minRadius
                
                let length = (maxRadius - minRadius) * CGFloat(barVal)
                let endX = center.x + CGFloat(cos(angle)) * (minRadius + max(2.0, length))
                let endY = center.y + CGFloat(sin(angle)) * (minRadius + max(2.0, length))
                
                var path = Path()
                path.move(to: CGPoint(x: startX, y: startY))
                path.addLine(to: CGPoint(x: endX, y: endY))
                
                let color = palette.accent.opacity(0.4 + barVal * 0.6)
                ctx.stroke(
                    path,
                    with: .color(color),
                    style: StrokeStyle(lineWidth: max(1.5, min(4.0, (2.0 * .pi * minRadius) / CGFloat(n) - 1.0)), lineCap: .round)
                )
            }
        }
        .drawingGroup()
    }
}

// MARK: - Dots Canvas
struct DotsCanvas: View {
    let bars: [Double]
    let palette: Palette

    var body: some View {
        Canvas(rendersAsynchronously: true) { ctx, size in
            let n = bars.count
            guard n > 0 else { return }
            
            let dotsPerColumn = 10
            let hPad: CGFloat = 14
            let vPad: CGFloat = 14
            let spacing: CGFloat = 4
            let dotGap: CGFloat = 3
            
            let totalSpacing = spacing * CGFloat(n - 1)
            let colWidth = max(2.0, (size.width - totalSpacing - hPad * 2) / CGFloat(n))
            let dotHeight = max(2.0, (size.height - vPad * 2 - dotGap * CGFloat(dotsPerColumn - 1)) / CGFloat(dotsPerColumn))
            let dotSize = min(colWidth, dotHeight)
            
            for i in 0..<n {
                let x = hPad + CGFloat(i) * (colWidth + spacing) + (colWidth - dotSize) / 2
                let activeDots = Int(bars[i] * Double(dotsPerColumn))
                
                for d in 0..<dotsPerColumn {
                    let dotIndex = (dotsPerColumn - 1) - d // 0 = bottom
                    let isActive = dotIndex < activeDots
                    let y = vPad + CGFloat(d) * (dotSize + dotGap) + (dotHeight - dotSize) / 2
                    
                    let rect = CGRect(x: x, y: y, width: dotSize, height: dotSize)
                    let path = Path(ellipseIn: rect)
                    
                    if isActive {
                        let t = Double(dotIndex) / Double(dotsPerColumn - 1)
                        let color = palette.accent.opacity(0.35 + t * 0.65)
                        ctx.fill(path, with: .color(color))
                    } else {
                        ctx.fill(path, with: .color(palette.textPrimary.opacity(0.04)))
                    }
                }
            }
        }
        .drawingGroup()
    }
}
