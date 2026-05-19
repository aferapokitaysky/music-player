import SwiftUI

struct PlayerControls: View {
    @ObservedObject var viewModel: PlayerViewModel
    @EnvironmentObject var themeManager: ThemeManager

    private var palette: Palette { themeManager.theme.palette }

    var body: some View {
        VStack(spacing: 14) {
            // Timeline
            VStack(spacing: 6) {
                GeometryReader { geo in
                    let progress = (viewModel.currentTrack?.duration ?? 0) > 0
                        ? viewModel.currentTime / (viewModel.currentTrack?.duration ?? 1)
                        : 0.0

                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(palette.inset)
                            .frame(height: 6)
                            .overlay(
                                Capsule().stroke(palette.stroke, lineWidth: 1)
                            )

                        Capsule()
                            .fill(LinearGradient(colors: palette.progressGradient,
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(progress))),
                                   height: 6)
                            .shadow(color: palette.glow, radius: 4)

                        Circle()
                            .fill(palette.textPrimary)
                            .frame(width: 14, height: 14)
                            .overlay(
                                Circle()
                                    .stroke(LinearGradient(colors: palette.progressGradient,
                                                           startPoint: .leading, endPoint: .trailing),
                                            lineWidth: 2)
                            )
                            .shadow(color: palette.cardShadow, radius: 3, x: 0, y: 2)
                            .offset(x: max(0, min(geo.size.width - 14, geo.size.width * CGFloat(progress) - 7)))
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let duration = viewModel.currentTrack?.duration ?? 0.0
                                guard duration > 0 else { return }
                                let percentage = Double(value.location.x / geo.size.width)
                                let targetTime = max(0, min(duration, percentage * duration))
                                viewModel.seek(to: targetTime)
                            }
                    )
                }
                .frame(height: 14)

                HStack {
                    Text(formatTime(viewModel.currentTime))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(palette.textSecondary)
                    Spacer()
                    Text("-" + formatTime(max(0, (viewModel.currentTrack?.duration ?? 0) - viewModel.currentTime)))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(palette.textTertiary)
                    Spacer()
                    Text(formatTime(viewModel.currentTrack?.duration ?? 0.0))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(palette.textSecondary)
                }
            }
            .padding(.horizontal, 16)

            // Primary controls
            HStack(spacing: 22) {
                iconButton(
                    "shuffle",
                    active: viewModel.isShuffle,
                    accent: palette.accent
                ) { viewModel.toggleShuffle() }

                iconButton("backward.fill", size: 18) { viewModel.prevTrack() }

                // Big play/pause
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
                                color: (viewModel.isPlaying ? palette.accentSecondary : palette.accent).opacity(0.55),
                                radius: 14, x: 0, y: 6
                            )

                        Circle()
                            .strokeBorder(Color.white.opacity(0.20), lineWidth: 1)
                            .frame(width: 58, height: 58)

                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundColor(.white)
                            .offset(x: viewModel.isPlaying ? 0 : 2)
                    }
                }
                .buttonStyle(.plain)

                iconButton("forward.fill", size: 18) { viewModel.nextTrack() }

                iconButton(
                    "repeat",
                    active: viewModel.isRepeat,
                    accent: palette.accentSecondary
                ) { viewModel.toggleRepeat() }
            }

            // Volume
            HStack(spacing: 10) {
                Image(systemName: volumeIcon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(palette.textSecondary)
                    .frame(width: 16)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(palette.inset)
                            .frame(height: 4)
                        Capsule()
                            .fill(palette.textPrimary.opacity(0.85))
                            .frame(width: geo.size.width * CGFloat(viewModel.volume), height: 4)
                        Circle()
                            .fill(palette.textPrimary)
                            .frame(width: 10, height: 10)
                            .shadow(color: palette.cardShadow, radius: 2)
                            .offset(x: max(0, min(geo.size.width - 10, geo.size.width * CGFloat(viewModel.volume) - 5)))
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
                .frame(height: 12)

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

    // MARK: - Helpers
    private func iconButton(_ system: String,
                            size: CGFloat = 14,
                            active: Bool = false,
                            accent: Color? = nil,
                            action: @escaping () -> Void) -> some View {
        let highlight = accent ?? palette.accent
        return Button(action: action) {
            Image(systemName: system)
                .font(.system(size: size, weight: .bold))
                .foregroundColor(active ? highlight : palette.textPrimary.opacity(0.85))
                .frame(width: 36, height: 36)
                .background(
                    Circle().fill(active ? highlight.opacity(0.18) : Color.clear)
                )
                .overlay(
                    Circle().stroke(active ? highlight.opacity(0.45) : Color.clear, lineWidth: 1)
                )
                .shadow(color: active ? highlight.opacity(0.55) : .clear, radius: 6)
        }
        .buttonStyle(.plain)
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
