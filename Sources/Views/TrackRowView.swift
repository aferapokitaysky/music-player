import SwiftUI

struct TrackRowView: View {
    let track: Track
    let album: Album
    @ObservedObject var viewModel: PlayerViewModel
    @EnvironmentObject var themeManager: ThemeManager

    @State private var isHovered = false

    private var palette: Palette { themeManager.theme.palette }

    var body: some View {
        let isActive = viewModel.currentTrack == track
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(palette.inset)
                    .frame(width: 36, height: 36)

                if let url = track.albumArtUrl, url.hasPrefix("http"), let u = URL(string: url) {
                    AsyncImage(url: u) { phase in
                        switch phase {
                        case .success(let image): image.resizable().aspectRatio(contentMode: .fill)
                        default: Image(systemName: "music.note").foregroundColor(palette.textTertiary)
                        }
                    }
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                } else {
                    Image(systemName: track.albumArtUrl ?? "music.note")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(palette.textTertiary)
                }

                if isActive {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.black.opacity(0.55))
                        .frame(width: 36, height: 36)
                    if viewModel.isPlaying { activeBars }
                    else { Image(systemName: "play.fill").font(.system(size: 12, weight: .heavy)).foregroundColor(.white) }
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(palette.stroke, lineWidth: 1))
            .scaleEffect(isHovered ? 1.06 : 1.0)

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(isActive ? palette.accent : palette.textPrimary)
                    .lineLimit(1)
                Text(track.artist)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(palette.textTertiary)
                    .lineLimit(1)
            }
            .offset(x: isHovered ? 5 : 0)

            Spacer()

            Text(formatDuration(track.duration))
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(isActive ? palette.accent.opacity(0.85) : palette.textTertiary)
                .scaleEffect(isHovered ? 1.05 : 1.0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isActive ? palette.accent.opacity(0.18) : (isHovered ? palette.inset.opacity(0.4) : Color.clear))
                .shadow(color: isActive ? palette.accent.opacity(0.35) : (isHovered ? palette.cardShadow.opacity(0.08) : .clear),
                        radius: (isActive || isHovered) ? (isHovered ? 10 : 8) : 0,
                        x: 0,
                        y: (isActive || isHovered) ? 3 : 0)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isActive ? palette.accent.opacity(0.85) : (isHovered ? palette.strokeStrong.opacity(0.40) : Color.clear), lineWidth: isActive ? 1.5 : 1.0)
        )
        .contentShape(Rectangle())
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.70), value: isHovered)
        .onTapGesture {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.75)) {
                viewModel.playTrack(track, in: album)
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button(role: .destructive) {
                withAnimation {
                    viewModel.deleteTrackLocally(track.id, from: album.id)
                }
            } label: {
                Label("Удалить локально", systemImage: "trash")
            }
        }
    }

    private var activeBars: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2) {
                ForEach(0..<3) { i in
                    let phase = sin(t * 6.0 + Double(i) * 1.3)
                    let h = CGFloat(6.0 + (phase + 1.0) * 4.0)
                    RoundedRectangle(cornerRadius: 1).fill(Color.white)
                        .frame(width: 2, height: h)
                }
            }
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}
