import SwiftUI

struct TrackRowView: View {
    let track: Track
    let album: Album
    @ObservedObject var viewModel: PlayerViewModel
    var showsSearchAddButton = false
    @EnvironmentObject var themeManager: ThemeManager

    @State private var isHovered = false
    @State private var isDotsHovered = false
    @State private var isQuickAddHovered = false
    @State private var isTrashHovered = false
    @State private var showCreatePlaylistPopover = false
    @State private var newPlaylistName = ""
    @State private var showDeleteConfirmation = false

    private var palette: Palette { themeManager.theme.palette }

    var body: some View {
        let isActive = viewModel.currentTrack == track
        HStack(spacing: 10) {
            // Album art thumbnail
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

            // Track info
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

            // Action buttons area
            if showsSearchAddButton {
                // 3-dot menu button (shown on hover)
                if isHovered || isDotsHovered || isQuickAddHovered {
                    HStack(spacing: 6) {
                        quickAddButton
                        dotsMenuButton
                    }
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.7).combined(with: .opacity),
                            removal: .scale(scale: 0.7).combined(with: .opacity)
                        ))
                }
            } else {
                // Trash button for library tracks (shown on hover)
                if isHovered || isTrashHovered {
                    trashButton
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.7).combined(with: .opacity),
                            removal: .scale(scale: 0.7).combined(with: .opacity)
                        ))
                }
            }

            // Duration
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
                .stroke(isActive ? palette.accent.opacity(0.85) : (isHovered ? palette.strokeStrong.opacity(0.40) : Color.clear),
                        lineWidth: isActive ? 1.5 : 1.0)
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
            if showsSearchAddButton {
                // Add to playlist submenu
                if viewModel.localPlaylists.isEmpty {
                    Button {
                        _ = viewModel.createLocalPlaylist(named: "Мой плейлист")
                        viewModel.addTrackToSearchTargetPlaylist(track)
                    } label: {
                        Label("Создать плейлист и добавить", systemImage: "plus.circle")
                    }
                } else {
                    ForEach(viewModel.localPlaylists) { pl in
                        Button {
                            viewModel.addTrack(track, toLocalPlaylist: pl.id)
                        } label: {
                            Label("Добавить в «\(pl.name)»", systemImage: "music.note.list")
                        }
                    }
                    Divider()
                    Button {
                        _ = viewModel.createLocalPlaylist(named: "Новый плейлист")
                        viewModel.addTrackToSearchTargetPlaylist(track)
                    } label: {
                        Label("Создать новый плейлист", systemImage: "plus.circle")
                    }
                }
            } else {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Удалить из плейлиста", systemImage: "trash")
                }
            }
        }
        .alert("Удалить трек?", isPresented: $showDeleteConfirmation) {
            Button("Удалить", role: .destructive) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                    viewModel.deleteTrackLocally(track.id, from: album.id)
                }
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("«\(track.title)» будет удален из «\(album.name)».")
        }
    }

    // MARK: - Fast add button
    private var quickAddButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                viewModel.addTrackToSearchTargetPlaylist(track)
            }
        }) {
            Image(systemName: isQuickAddHovered ? "plus.circle.fill" : "plus.circle")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(isQuickAddHovered ? palette.textPrimary : palette.textSecondary)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(isQuickAddHovered ? palette.textPrimary.opacity(0.15) : palette.inset)
                )
                .overlay(
                    Circle()
                        .stroke(isQuickAddHovered ? palette.strokeStrong : palette.stroke, lineWidth: 1)
                )
                .scaleEffect(isQuickAddHovered ? 1.12 : 1.0)
                .shadow(color: isQuickAddHovered ? palette.glow.opacity(0.25) : .clear, radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .onHover { h in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.65)) {
                isQuickAddHovered = h
            }
        }
        .help("Добавить в выбранный плейлист")
    }

    // MARK: - 3-dot menu button
    private var dotsMenuButton: some View {
        Menu {
            if viewModel.localPlaylists.isEmpty {
                Button {
                    _ = viewModel.createLocalPlaylist(named: "Мой плейлист")
                    viewModel.addTrackToSearchTargetPlaylist(track)
                } label: {
                    Label("Создать плейлист и добавить", systemImage: "plus.circle")
                }
            } else {
                ForEach(viewModel.localPlaylists) { pl in
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                            viewModel.addTrack(track, toLocalPlaylist: pl.id)
                        }
                    } label: {
                        Label("В «\(pl.name)»", systemImage: "music.note.list")
                    }
                }
                Divider()
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                        _ = viewModel.createLocalPlaylist(named: "Новый плейлист")
                        viewModel.addTrackToSearchTargetPlaylist(track)
                    }
                } label: {
                    Label("Создать новый плейлист", systemImage: "plus.circle.fill")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(isDotsHovered ? palette.textPrimary : palette.textSecondary)
                .rotationEffect(.degrees(90))
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(isDotsHovered ? palette.textPrimary.opacity(0.15) : palette.inset)
                )
                .overlay(
                    Circle()
                        .stroke(isDotsHovered ? palette.strokeStrong : palette.stroke, lineWidth: 1)
                )
                .scaleEffect(isDotsHovered ? 1.12 : 1.0)
                .shadow(color: isDotsHovered ? palette.glow.opacity(0.25) : .clear, radius: 6, x: 0, y: 2)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .onHover { h in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.65)) {
                isDotsHovered = h
            }
        }
        .help("Добавить в плейлист")
    }

    // MARK: - Trash button for library tracks
    private var trashButton: some View {
        Button(action: {
            showDeleteConfirmation = true
        }) {
            Image(systemName: isTrashHovered ? "trash.fill" : "trash")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(isTrashHovered ? Color.red : palette.textTertiary)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(isTrashHovered ? Color.red.opacity(0.15) : palette.inset)
                )
                .overlay(
                    Circle()
                        .stroke(isTrashHovered ? Color.red.opacity(0.5) : palette.stroke, lineWidth: 1)
                )
                .scaleEffect(isTrashHovered ? 1.15 : 1.0)
                .shadow(color: isTrashHovered ? Color.red.opacity(0.3) : .clear, radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .onHover { h in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.65)) {
                isTrashHovered = h
            }
        }
        .help("Удалить трек")
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
