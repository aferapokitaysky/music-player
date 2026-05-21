import SwiftUI

struct NotchMiniPlayerView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @ObservedObject var themeManager = ThemeManager.shared
    @State private var isHovered = false
    @State private var isActuallyHovering = false
    @State private var isHoveringTimeline = false
    @State private var isHoveringVolume = false
    
    @State private var isVolumeExpanded = false
    
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
            // Expanded size is 500x156 (without volume slider) or 500x196 (with volume slider), fitting perfectly below the notch area
            .frame(width: isHovered ? 500 : 172, height: isHovered ? (isVolumeExpanded ? 196 : 156) : 32)
            .background(
                ZStack {
                    VisualEffectView(
                        material: themeManager.theme.nsMaterial,
                        blendingMode: .withinWindow,
                        cornerRadius: isHovered ? 24 : 12
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
                .mask(
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
            .clipShape(
                CustomRoundedCorner(
                    topLeft: 0,
                    topRight: 0,
                    bottomLeft: isHovered ? 24 : 12,
                    bottomRight: isHovered ? 24 : 12
                )
            )
            .shadow(color: palette.cardShadow.opacity(isHovered ? 0.40 : 0.0), radius: isHovered ? 16 : 0, y: isHovered ? 10 : 0)
            .contentShape(Rectangle())
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NotchHoverStateChanged"))) { notification in
                if let expanded = notification.object as? Bool {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.72)) {
                        isHovered = expanded
                        if !expanded {
                            isVolumeExpanded = false
                        }
                    }
                }
            }
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    // MARK: - Collapsed
    private var collapsedContent: some View {
        HStack {
            Spacer()
            AestheticLogoView(size: 16, color: .white)
            Spacer()
        }
    }
    
    // MARK: - Expanded (Frosted Solid Cool Gray matches primary UI)
    private var expandedContent: some View {
        VStack(spacing: 8) {
            // Brand Header Row
            HStack(spacing: 6) {
                AestheticLogoView(size: 11, color: palette.textPrimary)
                Text("Aferapokitaysky")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .foregroundColor(palette.textPrimary)
                Spacer()
                if viewModel.isShuffle {
                    Image(systemName: "shuffle")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(palette.accent)
                }
                if viewModel.isRepeat {
                    Image(systemName: "repeat")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(palette.accentSecondary)
                }
            }
            .padding(.horizontal, 4)
            .opacity(0.85)

            // Row 1: Cover Art, Metadata, and Playback Controls + Vol
            HStack(spacing: 12) {
                // Square Album Art with Rounded Corners
                albumArtCover
                    .frame(width: 54, height: 54)
                
                // Track details
                VStack(alignment: .leading, spacing: 1) {
                    if let track = viewModel.currentTrack {
                        Text(track.title)
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundColor(palette.textPrimary)
                            .lineLimit(1)
                        Text(track.artist)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(palette.textSecondary)
                            .lineLimit(1)
                    } else {
                        Text("Нет трека")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(palette.textTertiary)
                    }
                    
                    // Micro bars visualizer
                    NotchBarsVisualizer(hfState: viewModel.hfState, color: palette.accent)
                        .frame(height: 12)
                        .padding(.top, 2)
                }
                
                Spacer(minLength: 4)
                
                // Playback Controls (compact and super premium)
                HStack(spacing: 8) {
                    Button(action: {
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.60)) {
                            viewModel.prevTrack()
                        }
                    }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(palette.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(palette.inset))
                            .overlay(Circle().stroke(palette.stroke, lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.60)) {
                            viewModel.togglePlayPause()
                        }
                    }) {
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(themeManager.theme == .dark ? .black : .white)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(palette.textPrimary))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.60)) {
                            viewModel.nextTrack()
                        }
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(palette.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(palette.inset))
                            .overlay(Circle().stroke(palette.stroke, lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Spacer(minLength: 0)
            
            // Row 2: Gorgeous Playback Timeline / Seek Slider
            HStack(spacing: 8) {
                Text(formatTime(viewModel.hfState.currentTime))
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(palette.textSecondary)
                    .frame(width: 28, alignment: .leading)
                
                GeometryReader { geo in
                    let duration = viewModel.currentTrack?.duration ?? 0.0
                    let progress = duration > 0 ? viewModel.hfState.currentTime / duration : 0.0
                    let trackHeight: CGFloat = isHoveringTimeline ? 6 : 4
                    let knobSize: CGFloat = isHoveringTimeline ? 12 : 8
                    
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(palette.inset)
                            .frame(height: trackHeight)
                            .overlay(
                                Capsule().stroke(palette.stroke, lineWidth: 0.5)
                            )
                        
                        Capsule()
                            .fill(LinearGradient(colors: palette.progressGradient, startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(progress))), height: trackHeight)
                            .shadow(color: palette.glow.opacity(0.6), radius: isHoveringTimeline ? 4 : 2)
                        
                        Circle()
                            .fill(palette.textPrimary)
                            .frame(width: knobSize, height: knobSize)
                            .overlay(
                                Circle()
                                    .stroke(LinearGradient(colors: palette.progressGradient, startPoint: .leading, endPoint: .trailing), lineWidth: 1.5)
                            )
                            .shadow(color: palette.cardShadow, radius: isHoveringTimeline ? 3 : 1)
                            .offset(x: max(0, min(geo.size.width - knobSize, geo.size.width * CGFloat(progress) - knobSize / 2.0)))
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard duration > 0 else { return }
                                let percentage = Double(value.location.x / geo.size.width)
                                let targetTime = max(0, min(duration, percentage * duration))
                                viewModel.seek(to: targetTime)
                            }
                    )
                }
                .frame(height: 12)
                .onHover { hovering in
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        isHoveringTimeline = hovering
                    }
                }
                
                let duration = viewModel.currentTrack?.duration ?? 0.0
                Text("-" + formatTime(max(0, duration - viewModel.hfState.currentTime)))
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(palette.textSecondary)
                    .frame(width: 32, alignment: .trailing)
                
                // Volume button next to track timeline (dynamic toggle)
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        isVolumeExpanded.toggle()
                    }
                }) {
                    Image(systemName: isVolumeExpanded ? "speaker.wave.3.fill" : volumeIcon(viewModel.volume))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(isVolumeExpanded ? palette.accent : palette.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(isVolumeExpanded ? palette.cardElevated : palette.inset))
                        .overlay(Circle().stroke(isVolumeExpanded ? palette.accent.opacity(0.5) : palette.stroke, lineWidth: 0.8))
                        .scaleEffect(isVolumeExpanded ? 1.08 : 1.0)
                }
                .buttonStyle(.plain)
                .frame(width: 28, height: 28)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 6)
            
            // Row 3: Beautiful Integrated Horizontal Volume Slider
            if isVolumeExpanded {
                horizontalVolumeRow
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)).combined(with: .scale(scale: 0.98)),
                        removal: .opacity.combined(with: .move(edge: .bottom)).combined(with: .scale(scale: 0.98))
                    ))
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && seconds.isFinite else { return "0:00" }
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
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
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                
                // Specular gloss reflection overlay matching main UI
                LinearGradient(
                    colors: [.white.opacity(0.24), .clear, .white.opacity(0.10)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .blendMode(.overlay)
                .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Row 3: Beautiful Integrated Horizontal Volume Slider
    private var horizontalVolumeRow: some View {
        HStack(spacing: 10) {
            // Clickable speaker icon for mute
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                    if viewModel.volume > 0 {
                        viewModel.volume = 0
                    } else {
                        viewModel.volume = 0.5
                    }
                }
            }) {
                Image(systemName: volumeIcon(viewModel.volume))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(palette.textSecondary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            
            // Capsule progress bar with DragGesture
            GeometryReader { geo in
                let progress = CGFloat(viewModel.volume)
                let trackHeight: CGFloat = 5
                let knobSize: CGFloat = 9
                
                ZStack(alignment: .leading) {
                    // Track Background
                    Capsule()
                        .fill(palette.inset)
                        .frame(height: trackHeight)
                        .overlay(Capsule().stroke(palette.stroke, lineWidth: 0.5))
                    
                    // Track Fill
                    Capsule()
                        .fill(LinearGradient(colors: palette.progressGradient, startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(0, min(geo.size.width, geo.size.width * progress)), height: trackHeight)
                        .shadow(color: palette.glow.opacity(0.4), radius: 2)
                    
                    // Knob
                    Circle()
                        .fill(palette.textPrimary)
                        .frame(width: knobSize, height: knobSize)
                        .overlay(
                            Circle()
                                .stroke(LinearGradient(colors: palette.progressGradient, startPoint: .leading, endPoint: .trailing), lineWidth: 1.2)
                        )
                        .shadow(color: palette.cardShadow, radius: 2)
                        .offset(x: max(0, min(geo.size.width - knobSize, geo.size.width * progress - knobSize / 2.0)))
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let percentage = Double(value.location.x / geo.size.width)
                            viewModel.volume = max(0, min(1.0, percentage))
                        }
                )
            }
            .frame(height: 12)
            
            // Percentage indicator
            Text("\(Int(viewModel.volume * 100))%")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(palette.textSecondary)
                .frame(width: 32, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(palette.inset.opacity(0.30))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(palette.stroke, lineWidth: 0.6)
                )
        )
        .padding(.horizontal, 4)
        .padding(.bottom, 6)
    }
    private func volumeIcon(_ vol: Double) -> String {
        if vol == 0 { return "speaker.slash.fill" }
        if vol < 0.3 { return "speaker.wave.1.fill" }
        if vol < 0.7 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
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
class RoundedVisualEffectView: NSVisualEffectView {
    var bottomRadius: CGFloat = 0 {
        didSet { if oldValue != bottomRadius { needsLayout = true } }
    }
    
    override func layout() {
        super.layout()
        guard bounds.width > 0 && bounds.height > 0 else { return }
        
        let image = NSImage(size: bounds.size)
        image.lockFocus()
        NSColor.clear.set()
        NSRect(origin: .zero, size: bounds.size).fill()
        
        let path = NSBezierPath()
        let w = bounds.width
        let h = bounds.height
        let r = bottomRadius
        
        path.move(to: NSPoint(x: 0, y: h))
        path.line(to: NSPoint(x: w, y: h))
        path.line(to: NSPoint(x: w, y: r))
        path.appendArc(withCenter: NSPoint(x: w - r, y: r), radius: r, startAngle: 0, endAngle: 270, clockwise: true)
        path.line(to: NSPoint(x: r, y: 0))
        path.appendArc(withCenter: NSPoint(x: r, y: r), radius: r, startAngle: 270, endAngle: 180, clockwise: true)
        path.close()
        
        NSColor.black.set()
        path.fill()
        
        image.unlockFocus()
        image.isTemplate = true
        self.maskImage = image
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    let cornerRadius: CGFloat
    
    func makeNSView(context: Context) -> RoundedVisualEffectView {
        let view = RoundedVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.bottomRadius = cornerRadius
        return view
    }
    
    func updateNSView(_ nsView: RoundedVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.bottomRadius = cornerRadius
    }
}
