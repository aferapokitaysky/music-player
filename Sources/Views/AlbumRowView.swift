import SwiftUI

struct AlbumRowView: View {
    let album: Album
    @ObservedObject var viewModel: PlayerViewModel
    @EnvironmentObject var themeManager: ThemeManager

    @State private var isHovered = false

    private var palette: Palette { themeManager.theme.palette }

    var body: some View {
        let isSelected = album.id == viewModel.selectedAlbumId
        let icon: String = {
            switch album.kind {
            case .likes: return "heart.fill"
            case .playlist: return "music.note.list"
            case .uploads: return "square.and.arrow.up.fill"
            case .demo: return "sparkles"
            case .spotify: return "music.note.house.fill"
            case .custom: return "music.note"
            }
        }()
        let iconColor: Color = {
            switch album.kind {
            case .likes: return Color(red: 1.0, green: 0.36, blue: 0.42)
            case .spotify: return Color.spotifyGreen
            default: return palette.textSecondary
            }
        }()

        let isSpotify = album.kind == .spotify
        let isSoundCloud = [.likes, .uploads, .playlist].contains(album.kind) || album.id.hasPrefix("sc_")

        HStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(palette.inset)
                        .frame(width: 32, height: 32)
                    if let url = album.artworkUrl, url.hasPrefix("http"), let u = URL(string: url) {
                        AsyncImage(url: u) { phase in
                            switch phase {
                            case .success(let img): img.resizable().aspectRatio(contentMode: .fill)
                            default: Image(systemName: icon).foregroundColor(iconColor).font(.system(size: 13, weight: .bold))
                            }
                        }
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    } else {
                        Image(systemName: icon).foregroundColor(iconColor).font(.system(size: 13, weight: .bold))
                    }
                }
                .frame(width: 32, height: 32)
                
                if isSpotify {
                    SpotifyLogo(size: 9)
                        .padding(1)
                        .background(Circle().fill(palette.cardElevated))
                        .offset(x: 3, y: 3)
                } else if isSoundCloud {
                    SoundCloudLogo(size: 9)
                        .padding(1)
                        .background(Circle().fill(palette.cardElevated))
                        .offset(x: 3, y: 3)
                }
            }
            .scaleEffect(isHovered ? 1.08 : 1.0)

            VStack(alignment: .leading, spacing: 2) {
                Text(album.name)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .foregroundColor(isSelected ? palette.textPrimary : palette.textPrimary.opacity(0.85))
                Text("\(album.tracks.count) треков")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(palette.textTertiary)
            }
            .offset(x: isHovered ? 4 : 0)

            Spacer(minLength: 0)

            if viewModel.playingAlbumId == album.id {
                Circle()
                    .fill(palette.accent)
                    .frame(width: 5, height: 5)
                    .shadow(color: palette.glow, radius: 4)
                    .scaleEffect(isHovered ? 1.2 : 1.0)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? palette.accentSoft : (isHovered ? palette.inset.opacity(0.4) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? palette.accent.opacity(0.30) : (isHovered ? palette.stroke : Color.clear), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .scaleEffect(isHovered ? 1.025 : 1.0)
        .shadow(color: isHovered ? palette.cardShadow.opacity(0.12) : .clear,
                radius: isHovered ? 5 : 0,
                x: 0,
                y: isHovered ? 3 : 0)
        .animation(.spring(response: 0.25, dampingFraction: 0.70), value: isHovered)
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                viewModel.selectedAlbumId = album.id
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            if album.kind != .demo {
                Button(role: .destructive) {
                    withAnimation {
                        viewModel.deleteAlbumLocally(album.id)
                    }
                } label: {
                    Label("Удалить локально", systemImage: "trash")
                }
            }
        }
    }
}
