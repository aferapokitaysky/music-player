import SwiftUI

struct PlayerControls: View {
    @ObservedObject var viewModel: PlayerViewModel
    @EnvironmentObject var themeManager: ThemeManager

    @State private var isHoveringVolume = false

    private var palette: Palette { themeManager.theme.palette }

    var body: some View {
        VStack(spacing: 14) {
            PlaybackTimelineView(hfState: viewModel.hfState, viewModel: viewModel, palette: palette)
                .padding(.horizontal, 16)

            // Primary controls
            HStack(spacing: 22) {
                ControlIconButton(
                    system: "shuffle",
                    size: 14,
                    active: viewModel.isShuffle,
                    accentColor: palette.accent,
                    palette: palette,
                    action: { viewModel.toggleShuffle() }
                )

                ControlIconButton(
                    system: "backward.fill",
                    size: 18,
                    active: false,
                    accentColor: nil,
                    palette: palette,
                    action: { viewModel.prevTrack() }
                )

                // Animated elastic Play/Pause
                PlayPauseButton(viewModel: viewModel, hfState: viewModel.hfState, palette: palette)

                ControlIconButton(
                    system: "forward.fill",
                    size: 18,
                    active: false,
                    accentColor: nil,
                    palette: palette,
                    action: { viewModel.nextTrack() }
                )

                ControlIconButton(
                    system: "repeat",
                    size: 14,
                    active: viewModel.isRepeat,
                    accentColor: palette.accentSecondary,
                    palette: palette,
                    action: { viewModel.toggleRepeat() }
                )
            }

            // Volume
            HStack(spacing: 10) {
                Image(systemName: volumeIcon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(palette.textSecondary)
                    .frame(width: 16)

                GeometryReader { geo in
                    let trackHeight: CGFloat = isHoveringVolume ? 7 : 4
                    let knobSize: CGFloat = isHoveringVolume ? 14 : 9

                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(palette.inset)
                            .frame(height: trackHeight)
                        Capsule()
                            .fill(palette.textPrimary.opacity(0.85))
                            .frame(width: geo.size.width * CGFloat(viewModel.volume), height: trackHeight)
                        Circle()
                            .fill(palette.textPrimary)
                            .frame(width: knobSize, height: knobSize)
                            .shadow(color: palette.cardShadow, radius: isHoveringVolume ? 3 : 2)
                            .offset(x: max(0, min(geo.size.width - knobSize, geo.size.width * CGFloat(viewModel.volume) - knobSize / 2.0)))
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let percentage = Double(value.location.x / geo.size.width)
                                viewModel.volume = max(0, min(1.0, percentage))
                            }
                    )
                    .onHover { hovering in
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.65)) {
                            isHoveringVolume = hovering
                        }
                    }
                }
                .frame(height: isHoveringVolume ? 16 : 12)

                Text("\(Int(viewModel.volume * 100))")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(palette.textTertiary)
                    .frame(width: 22, alignment: .trailing)
            }
            .frame(maxWidth: 220)
            .padding(.top, 2)
        }
        .padding(.vertical, 8)
    }

    private var volumeIcon: String {
        if viewModel.volume == 0 { return "speaker.slash.fill" }
        if viewModel.volume < 0.3 { return "speaker.wave.1.fill" }
        if viewModel.volume < 0.7 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    private func formatTime(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Reusable Animated Control Button
struct ControlIconButton: View {
    let system: String
    var size: CGFloat = 14
    let active: Bool
    let accentColor: Color?
    let palette: Palette
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        let highlight = accentColor ?? palette.accent
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: size, weight: .bold))
                .foregroundColor(active ? highlight : (isHovered ? palette.accent : palette.textPrimary.opacity(0.85)))
                .frame(width: 36, height: 36)
                .background(
                    Circle().fill(active ? highlight.opacity(0.18) : (isHovered ? palette.cardElevated : Color.clear))
                )
                .overlay(
                    Circle().stroke(active ? highlight.opacity(0.45) : (isHovered ? palette.strokeStrong : Color.clear), lineWidth: 1)
                )
                .shadow(color: active ? highlight.opacity(0.55) : (isHovered ? palette.glow.opacity(0.3) : .clear), radius: isHovered ? 8 : 6)
                .scaleEffect(isHovered ? 1.12 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(response: 0.24, dampingFraction: 0.54)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Reusable Bouncy Play/Pause Button
struct PlayPauseButton: View {
    @ObservedObject var viewModel: PlayerViewModel
    @ObservedObject var hfState: HighFrequencyState
    let palette: Palette
    @State private var isHovered = false

    var body: some View {
        let intensity = hfState.visualizerBars.reduce(0.0, +) / max(1.0, Double(hfState.visualizerBars.count))
        let dynamicGlow = viewModel.isPlaying ? CGFloat(intensity * 14.0) : 0.0

        Button(action: { viewModel.togglePlayPause() }) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: viewModel.isPlaying ? palette.pauseGradient : palette.playGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 58, height: 58)
                    .shadow(
                        color: (viewModel.isPlaying ? palette.accentSecondary : palette.accent).opacity(isHovered ? 0.85 : 0.55),
                        radius: (isHovered ? 18 : 14) + dynamicGlow, x: 0, y: isHovered ? 8 : 6
                    )

                Circle()
                    .strokeBorder(Color.white.opacity(0.20), lineWidth: 1)
                    .frame(width: 58, height: 58)

                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundColor(viewModel.isPlaying ? palette.pauseIconColor : palette.playIconColor)
                    .offset(x: viewModel.isPlaying ? 0 : 2)
            }
            .scaleEffect(isHovered ? 1.08 : 1.0)
            .scaleEffect(viewModel.isPlaying ? 0.95 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.52), value: isHovered)
            .animation(.spring(response: 0.32, dampingFraction: 0.45), value: viewModel.isPlaying)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Decoupled Playback Timeline View (10 FPS redraws isolated)
struct PlaybackTimelineView: View {
    @ObservedObject var hfState: HighFrequencyState
    @ObservedObject var viewModel: PlayerViewModel
    let palette: Palette

    @State private var isHoveringTimeline = false

    var body: some View {
        let duration = viewModel.currentTrack?.duration ?? 0.0
        let progress = duration > 0 ? hfState.currentTime / duration : 0.0
        let trackHeight: CGFloat = isHoveringTimeline ? 9 : 5
        let knobSize: CGFloat = isHoveringTimeline ? 18 : 13

        return VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(palette.inset)
                        .frame(height: trackHeight)
                        .overlay(
                            Capsule().stroke(palette.stroke, lineWidth: 1)
                        )

                    Capsule()
                        .fill(LinearGradient(colors: palette.progressGradient,
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(progress))),
                               height: trackHeight)
                        .shadow(color: palette.glow, radius: isHoveringTimeline ? 6 : 3)

                    Circle()
                        .fill(palette.textPrimary)
                        .frame(width: knobSize, height: knobSize)
                        .overlay(
                            Circle()
                                .stroke(LinearGradient(colors: palette.progressGradient,
                                                       startPoint: .leading, endPoint: .trailing),
                                        lineWidth: 2)
                        )
                        .shadow(color: palette.cardShadow, radius: isHoveringTimeline ? 4 : 2, x: 0, y: isHoveringTimeline ? 3 : 1)
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
                .onHover { hovering in
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.65)) {
                        isHoveringTimeline = hovering
                    }
                }
            }
            .frame(height: isHoveringTimeline ? 18 : 14)

            HStack {
                Text(formatTime(hfState.currentTime))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(palette.textSecondary)
                Spacer()
                Text("-" + formatTime(max(0, duration - hfState.currentTime)))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(palette.textTertiary)
                Spacer()
                Text(formatTime(duration))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(palette.textSecondary)
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && seconds.isFinite else { return "0:00" }
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}
