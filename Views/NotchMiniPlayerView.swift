import SwiftUI

struct NotchMiniPlayerView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isHovered = false
    
    private var palette: Palette { themeManager.theme.palette }
    
    var body: some View {
        VStack(spacing: 0) {
            // Spacer clearing the physical notch bezel
            Spacer().frame(height: 38)
            
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
            .padding(.horizontal, isHovered ? 16 : 8)
            // Premium upscaled capsule size: collapsed width 190 -> expanded width 450, height 82
            .frame(width: isHovered ? 450 : 190, height: isHovered ? 82 : 12)
            .background(
                RoundedRectangle(cornerRadius: isHovered ? 24 : 6, style: .continuous)
                    .fill(palette.cardElevated.opacity(themeManager.theme == .dark ? 0.90 : 0.72))
                    .overlay(
                        RoundedRectangle(cornerRadius: isHovered ? 24 : 6, style: .continuous)
                            .stroke(palette.stroke, lineWidth: 1)
                    )
            )
            .shadow(color: palette.cardShadow.opacity(isHovered ? 0.40 : 0.0), radius: isHovered ? 16 : 0, y: isHovered ? 10 : 0)
            
            Spacer(minLength: 0)
        }
        .frame(width: 500, height: 180)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.spring(response: 0.36, dampingFraction: 0.72)) {
                isHovered = hovering
            }
        }
    }
    
    // MARK: - Collapsed
    private var collapsedContent: some View {
        Spacer()
    }
    
    // MARK: - Expanded (Frosted Glassmorphic matches primary UI)
    private var expandedContent: some View {
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
                NotchBarsVisualizer(bars: viewModel.visualizerBars, color: palette.accent)
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
    let bars: [Double]
    let color: Color
    
    var body: some View {
        Canvas(rendersAsynchronously: true) { ctx, size in
            let n = min(bars.count, 22)
            guard n > 0 else { return }
            let spacing: CGFloat = 1.5
            let barWidth = (size.width - spacing * CGFloat(n - 1)) / CGFloat(n)
            
            for i in 0..<n {
                let x = CGFloat(i) * (barWidth + spacing)
                let h = size.height * CGFloat(bars[i] * 0.9)
                let y = size.height - h
                
                let rect = CGRect(x: x, y: y, width: barWidth, height: max(1.5, h))
                let path = Path(roundedRect: rect, cornerRadius: 0.8)
                ctx.fill(path, with: .color(color))
            }
        }
    }
}
