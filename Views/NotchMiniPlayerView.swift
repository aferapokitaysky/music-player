import SwiftUI

struct NotchMiniPlayerView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @ObservedObject var themeManager = ThemeManager.shared
    @State private var isHovered = false
    
    private var palette: Palette { themeManager.theme.palette }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                if isHovered {
                    expandedContent
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.96)),
                            removal: .opacity
                        ))
                } else {
                    collapsedContent
                }
            }
            .padding(.top, isHovered ? 36 : 0) // Safe 36pt top padding to clear MacBook Air/Pro physical notch bezels
            .padding(.horizontal, isHovered ? 16 : 8)
            // Collapsed size is 172x32, matching standard physical MacBook notch curves
            // Expanded size is 460x138, fitting perfectly below the notch area
            .frame(width: isHovered ? 460 : 172, height: isHovered ? 138 : 32)
            .background(
                ZStack {
                    VisualEffectView(
                        material: themeManager.theme.nsMaterial,
                        blendingMode: .behindWindow
                    )
                    
                    if isHovered {
                        AmbientBackdropView(
                            isPlaying: viewModel.isPlaying,
                            ambientColors: palette.accentGradient,
                            isDark: themeManager.theme == .dark
                        )
                        .scaleEffect(0.6)
                        .opacity(0.35)
                        .allowsHitTesting(false)
                        
                        CosmicDustView(isPlaying: viewModel.isPlaying, palette: palette)
                            .allowsHitTesting(false)
                    }
                }
                .clipShape(
                    CustomRoundedCorner(
                        topLeft: 0,
                        topRight: 0,
                        bottomLeft: isHovered ? 24 : 12,
                        bottomRight: isHovered ? 24 : 12
                    )
                )
                .background(
                    CustomRoundedCorner(
                        topLeft: 0,
                        topRight: 0,
                        bottomLeft: isHovered ? 24 : 12,
                        bottomRight: isHovered ? 24 : 12
                    )
                    .fill(palette.sidebar.opacity(themeManager.theme == .dark ? 0.30 : 0.45))
                )
                .overlay(
                    CustomRoundedCorner(
                        topLeft: 0,
                        topRight: 0,
                        bottomLeft: isHovered ? 24 : 12,
                        bottomRight: isHovered ? 24 : 12
                    )
                    .stroke(palette.strokeStrong, lineWidth: 1.2)
                )
                .opacity(isHovered ? 1.0 : 0.0) // 100% invisible when collapsed, revealing only the physical screen notch bezel!
            )
            .shadow(color: palette.cardShadow.opacity(isHovered ? 0.40 : 0.0), radius: isHovered ? 16 : 0, y: isHovered ? 10 : 0)
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(.spring(response: 0.36, dampingFraction: 0.72)) {
                    isHovered = hovering
                }
            }
            
            Spacer(minLength: 0)
        }
        .frame(width: 500, height: 180)
    }
    
    // MARK: - Collapsed
    private var collapsedContent: some View {
        Spacer()
    }
    
    // MARK: - Expanded (Frosted Solid Cool Gray matches primary UI)
    private var expandedContent: some View {
        VStack(spacing: 8) {
            // Row 1: Cover Art, Metadata, Real-time visualizer, and Playback Controls
            HStack(spacing: 14) {
                // Square Album Art with Rounded Corners (no vinyl, matches main UI)
                albumArtCover
                    .frame(width: 56, height: 56)
                
                // Track details
                VStack(alignment: .leading, spacing: 3) {
                    if let track = viewModel.currentTrack {
                        Text(track.title)
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundColor(palette.textPrimary)
                            .lineLimit(1)
                        Text(track.artist)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(palette.textSecondary)
                            .lineLimit(1)
                    } else {
                        Text("Нет трека")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(palette.textTertiary)
                    }
                    
                    // Micro bars visualizer
                    NotchBarsVisualizer(hfState: viewModel.hfState, color: palette.accent)
                        .frame(height: 16)
                        .padding(.top, 2)
                }
                
                Spacer(minLength: 6)
                
                // Sleek Control Buttons (perfect main UI style, includes backward skip)
                HStack(spacing: 9) {
                    Button(action: {
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.60)) {
                            viewModel.prevTrack()
                        }
                    }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(palette.textSecondary)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(palette.inset))
                            .overlay(Circle().stroke(palette.stroke, lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.60)) {
                            viewModel.togglePlayPause()
                        }
                    }) {
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 12, weight: .black))
                            .foregroundColor(themeManager.theme == .dark ? .black : .white)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(palette.textPrimary))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.60)) {
                            viewModel.nextTrack()
                        }
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(palette.textSecondary)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(palette.inset))
                            .overlay(Circle().stroke(palette.stroke, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Row 2: Sleek Interactive Volume Control Slider
            HStack(spacing: 10) {
                Image(systemName: viewModel.volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(palette.textSecondary)
                    .frame(width: 14)
                
                GeometryReader { geo in
                    let progress = CGFloat(viewModel.volume)
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(palette.inset)
                            .frame(height: 4)
                            .overlay(
                                Capsule().stroke(palette.stroke, lineWidth: 0.5)
                            )
                        
                        Capsule()
                            .fill(palette.textPrimary.opacity(0.85))
                            .frame(width: max(0, min(geo.size.width, geo.size.width * progress)), height: 4)
                        
                        Circle()
                            .fill(palette.textPrimary)
                            .frame(width: 10, height: 10)
                            .shadow(color: palette.cardShadow, radius: 2)
                            .offset(x: max(0, min(geo.size.width - 10, geo.size.width * progress - 5)))
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let percentage = Double(value.location.x / geo.size.width)
                                viewModel.volume = max(0, min(1.0, percentage))
                            }
                    )
                }
                .frame(height: 10)
                
                Text("\(Int(viewModel.volume * 100))%")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(palette.textSecondary)
                    .frame(width: 30, alignment: .trailing)
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)
        }
    }
    
    // MARK: - Square Album Art Cover (Specular gloss overlay)
    private var albumArtCover: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(palette.inset)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(palette.strokeStrong, lineWidth: 1)
                )
                
            if let track = viewModel.currentTrack {
                Group {
                    if let url = track.albumArtUrl, url.hasPrefix("http") {
                        AsyncImage(url: URL(string: url)) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            ProgressView().scaleEffect(0.5)
                        }
                    } else {
                        ZStack {
                            LinearGradient(colors: [palette.accent.opacity(0.35), palette.accentSecondary.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            Image(systemName: track.albumArtUrl ?? "music.note")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(palette.textPrimary)
                        }
                    }
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                
                // Specular gloss reflection overlay matching main UI
                LinearGradient(
                    colors: [.white.opacity(0.24), .clear, .white.opacity(0.10)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .blendMode(.overlay)
                .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - Miniature Bars Visualizer View
struct NotchBarsVisualizer: View {
    @ObservedObject var hfState: HighFrequencyState
    let color: Color
    
    var body: some View {
        Canvas(rendersAsynchronously: true) { ctx, size in
            let n = min(hfState.visualizerBars.count, 22)
            guard n > 0 else { return }
            let spacing: CGFloat = 1.5
            let barWidth = (size.width - spacing * CGFloat(n - 1)) / CGFloat(n)
            
            for i in 0..<n {
                let x = CGFloat(i) * (barWidth + spacing)
                let h = size.height * CGFloat(hfState.visualizerBars[i] * 0.9)
                let y = size.height - h
                
                let rect = CGRect(x: x, y: y, width: barWidth, height: max(1.5, h))
                let path = Path(roundedRect: rect, cornerRadius: 0.8)
                ctx.fill(path, with: .color(color))
            }
        }
    }
}

// MARK: - Custom Rounded Corner Shape
struct CustomRoundedCorner: Shape {
    var topLeft: CGFloat = 0
    var topRight: CGFloat = 0
    var bottomLeft: CGFloat = 0
    var bottomRight: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        let tr = min(min(self.topRight, h/2), w/2)
        let tl = min(min(self.topLeft, h/2), w/2)
        let br = min(min(self.bottomRight, h/2), w/2)
        let bl = min(min(self.bottomLeft, h/2), w/2)

        path.move(to: CGPoint(x: w / 2, y: 0))
        path.addLine(to: CGPoint(x: w - tr, y: 0))
        path.addArc(center: CGPoint(x: w - tr, y: tr), radius: tr,
                    startAngle: Angle(degrees: -90), endAngle: Angle(degrees: 0), clockwise: false)

        path.addLine(to: CGPoint(x: w, y: h - br))
        path.addArc(center: CGPoint(x: w - br, y: h - br), radius: br,
                    startAngle: Angle(degrees: 0), endAngle: Angle(degrees: 90), clockwise: false)

        path.addLine(to: CGPoint(x: bl, y: h))
        path.addArc(center: CGPoint(x: bl, y: h - bl), radius: bl,
                    startAngle: Angle(degrees: 90), endAngle: Angle(degrees: 180), clockwise: false)

        path.addLine(to: CGPoint(x: 0, y: tl))
        path.addArc(center: CGPoint(x: tl, y: tl), radius: tl,
                    startAngle: Angle(degrees: 180), endAngle: Angle(degrees: 270), clockwise: false)

        path.closeSubpath()
        return path
    }
}

// MARK: - Native macOS Glassmorphic Visual Effect View
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
