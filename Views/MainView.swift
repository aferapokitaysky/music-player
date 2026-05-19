import SwiftUI

struct MainView: View {
    @StateObject private var viewModel = PlayerViewModel()
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showSettings = false
    @State private var artGlowPhase: Double = 0

    private var palette: Palette { themeManager.theme.palette }

    var body: some View {
        ZStack {
            palette.appTint.ignoresSafeArea()
            ambientBackdrop.allowsHitTesting(false)

            HStack(spacing: 0) {
                if !viewModel.sidebarCollapsed {
                    albumsColumn
                        .frame(width: 200)
                        .background(palette.sidebar)
                        .transition(.move(edge: .leading).combined(with: .opacity))

                    Rectangle().fill(palette.divider).frame(width: 1)
                }

                tracksColumn
                    .frame(width: 280)
                    .background(palette.sidebar.opacity(0.6))

                Rectangle().fill(palette.divider).frame(width: 1)

                playerColumn
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(minWidth: 980, minHeight: 580)
        .foregroundColor(palette.textPrimary)
        .overlay(Group { if showSettings { settingsOverlay } })
        .animation(.easeInOut(duration: 0.30), value: themeManager.theme)
        .animation(.easeInOut(duration: 0.25), value: viewModel.sidebarCollapsed)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                artGlowPhase = 1
            }
        }
    }

    // MARK: - Backdrop
    private var ambientBackdrop: some View {
        ZStack {
            Circle().fill(palette.accent.opacity(themeManager.theme == .dark ? 0.10 : 0.10))
                .frame(width: 360, height: 360).blur(radius: 90).offset(x: -260, y: -180)
            Circle().fill(palette.accentSecondary.opacity(themeManager.theme == .dark ? 0.10 : 0.08))
                .frame(width: 380, height: 380).blur(radius: 100).offset(x: 320, y: 220)
        }
    }

    // MARK: - Column 1 — Albums
    private var albumsColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack(alignment: .topLeading) {
                WindowDragArea().frame(height: 44)
                HStack(spacing: 8) {
                    trafficLight(color: palette.closeColor)    { WindowController.shared.close() }
                    trafficLight(color: palette.minimizeColor) { WindowController.shared.minimize() }
                    trafficLight(color: palette.maximizeColor) { WindowController.shared.zoom() }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)
            }

            // Brand
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(palette.textPrimary)
                        .frame(width: 28, height: 28)
                    Image(systemName: "waveform")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(themeManager.theme == .dark ? .black : .white)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text("Aesthetic")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                    Text("Player · Pro")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(palette.textTertiary)
                }
            }
            .padding(.horizontal, 14)

            sectionLabel("БИБЛИОТЕКА")

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(viewModel.albums) { album in
                        albumRow(album)
                    }
                }
                .padding(.horizontal, 8)
            }

            Spacer(minLength: 0)

            // Footer
            HStack(spacing: 8) {
                Button(action: { themeManager.toggle() }) {
                    Image(systemName: themeManager.theme == .dark ? "moon.stars.fill" : "sun.max.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(palette.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(palette.inset))
                        .overlay(Circle().stroke(palette.stroke, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .help("Сменить тему")

                Button(action: { withAnimation(.spring()) { showSettings.toggle() } }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(palette.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(palette.inset))
                        .overlay(Circle().stroke(palette.stroke, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .help("Настройки")

                Spacer()

                Button(action: { withAnimation { viewModel.sidebarCollapsed = true } }) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(palette.textTertiary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help("Скрыть альбомы")
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }

    private func albumRow(_ album: Album) -> some View {
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

        return HStack(spacing: 10) {
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
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(palette.stroke, lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                Text(album.name)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .foregroundColor(isSelected ? palette.textPrimary : palette.textPrimary.opacity(0.85))
                Text("\(album.tracks.count) треков")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(palette.textTertiary)
            }
            Spacer(minLength: 0)
            if viewModel.playingAlbumId == album.id {
                Circle()
                    .fill(palette.accent)
                    .frame(width: 5, height: 5)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? palette.accentSoft : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? palette.accent.opacity(0.30) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { viewModel.selectedAlbumId = album.id }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .heavy, design: .monospaced))
            .tracking(1.5)
            .foregroundColor(palette.textTertiary)
            .padding(.horizontal, 14)
    }

    private func trafficLight(color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle().fill(color).frame(width: 12, height: 12)
                Circle().stroke(Color.black.opacity(0.18), lineWidth: 0.5).frame(width: 12, height: 12)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Column 2 — Tracks of selected album
    private var tracksColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topLeading) {
                WindowDragArea().frame(height: 44)
                HStack {
                    if viewModel.sidebarCollapsed {
                        Button(action: { withAnimation { viewModel.sidebarCollapsed = false } }) {
                            Image(systemName: "sidebar.left")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(palette.textSecondary)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(palette.inset))
                                .overlay(Circle().stroke(palette.stroke, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 14)
            }

            if let album = viewModel.selectedAlbum {
                VStack(alignment: .leading, spacing: 4) {
                    Text(album.name)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .lineLimit(2)
                    Text("\(album.tracks.count) треков")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(palette.textTertiary)
                }
                .padding(.horizontal, 14)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 4) {
                        ForEach(album.tracks) { track in
                            trackRow(track, in: album)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 12)
                }
            } else {
                Spacer()
                Text("Выберите альбом")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(palette.textTertiary)
                    .frame(maxWidth: .infinity)
                Spacer()
            }
        }
    }

    private func trackRow(_ track: Track, in album: Album) -> some View {
        let isActive = viewModel.currentTrack == track
        return HStack(spacing: 10) {
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
            Spacer()
            Text(formatDuration(track.duration))
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(palette.textTertiary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isActive ? palette.accentSoft : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isActive ? palette.accent.opacity(0.30) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { viewModel.playTrack(track, in: album) }
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

    // MARK: - Column 3 — Now playing + visualizer + controls
    private var playerColumn: some View {
        VStack(spacing: 14) {
            ZStack {
                WindowDragArea().frame(height: 44)
                HStack {
                    Spacer()
                    Capsule().fill(palette.textTertiary.opacity(0.45))
                        .frame(width: 44, height: 4)
                        .padding(.top, 12)
                    Spacer()
                }
            }

            // Track meta
            HStack(spacing: 22) {
                albumArt
                VStack(alignment: .leading, spacing: 8) {
                    if let track = viewModel.currentTrack {
                        Text("СЕЙЧАС ИГРАЕТ")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .tracking(2)
                            .foregroundColor(palette.textTertiary)
                        Text(track.title)
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .lineLimit(2)
                        Text(track.artist)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(palette.textSecondary)
                            .lineLimit(1)
                    } else {
                        Text("Нет трека")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(palette.textTertiary)
                    }
                    Spacer()
                }
                Spacer()
            }
            .padding(.horizontal, 22)

            VisualizerView(bars: viewModel.visualizerBars, isPlaying: viewModel.isPlaying)
                .environmentObject(themeManager)

            PlayerControls(viewModel: viewModel)
                .environmentObject(themeManager)
                .padding(.horizontal, 18)

            Spacer(minLength: 0)
        }
    }

    private var albumArt: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: palette.accentGradient,
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 138, height: 138)
                .blur(radius: 22)
                .opacity(viewModel.isPlaying ? (0.40 + 0.18 * artGlowPhase) : 0.12)

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(palette.cardElevated)
                .frame(width: 124, height: 124)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(palette.strokeStrong, lineWidth: 1)
                )
                .shadow(color: palette.cardShadow, radius: 18, x: 0, y: 10)

            if let track = viewModel.currentTrack {
                Group {
                    if let url = track.albumArtUrl, url.hasPrefix("http") {
                        AsyncImage(url: URL(string: url)) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: { ProgressView() }
                    } else {
                        ZStack {
                            LinearGradient(colors: [palette.accent.opacity(0.30),
                                                    palette.accentSecondary.opacity(0.30)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                            Image(systemName: track.albumArtUrl ?? "music.note")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(palette.textPrimary)
                        }
                    }
                }
                .frame(width: 112, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .frame(width: 138, height: 138)
    }

    // MARK: - Settings overlay
    private var settingsOverlay: some View {
        ZStack {
            Color.black.opacity(themeManager.theme == .dark ? 0.55 : 0.30)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture { withAnimation(.spring()) { showSettings = false } }

            VStack(spacing: 18) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "link.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(palette.accent)
                        Text("ПОДКЛЮЧЕНИЕ СЕРВИСОВ")
                            .font(.system(size: 12, weight: .heavy, design: .monospaced))
                            .tracking(1.5)
                    }
                    Spacer()
                    Button(action: { withAnimation(.spring()) { showSettings = false } }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(palette.textTertiary)
                    }
                    .buttonStyle(.plain)
                }

                // Spotify
                connectionSection(
                    title: "Spotify Access Token",
                    logo: AnyView(SpotifyLogo(size: 16)),
                    accent: Color.spotifyGreen,
                    placeholder: "Bearer Token...",
                    text: $viewModel.spotifyToken,
                    secure: true,
                    buttonText: "Импортировать плейлист",
                    isLoading: viewModel.isConnecting
                ) {
                    Task { await viewModel.connectSpotify() }
                }

                Rectangle().fill(palette.divider).frame(height: 1)

                // SoundCloud
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        SoundCloudLogo(size: 14)
                        Text("SoundCloud Playlist URL")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(palette.textSecondary)
                    }
                    insetField(placeholder: "URL: профиль / /likes / /sets/...",
                               text: $viewModel.soundCloudUrl, secure: false)

                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(palette.textTertiary)
                        Text("OAuth токен · сохраняется в Keychain")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(palette.textTertiary)
                    }
                    .padding(.top, 4)

                    insetField(placeholder: "OAuth-XXXXXXXXXXXXXX...",
                               text: $viewModel.soundCloudOAuth, secure: true)

                    Text("soundcloud.com → DevTools → Application → Cookies → oauth_token")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(palette.textTertiary)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Button(action: { Task { await viewModel.connectSoundCloud() } }) {
                            HStack {
                                Spacer()
                                if viewModel.isConnecting {
                                    ProgressView().scaleEffect(0.6)
                                } else {
                                    Text("Загрузить")
                                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                                        .foregroundColor(.white)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(LinearGradient(
                                        colors: [Color.soundcloudOrange, Color.soundcloudOrange.opacity(0.75)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                            )
                            .shadow(color: Color.soundcloudOrange.opacity(0.4), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)

                        Button(action: { viewModel.clearLibrary() }) {
                            Text("Сброс")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(palette.textSecondary)
                                .padding(.horizontal, 14).padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(palette.inset))
                                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(palette.stroke, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .help("Очистить кэш и библиотеку")
                    }
                }

                if !viewModel.connectionStatus.isEmpty {
                    Text(viewModel.connectionStatus)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(palette.accent)
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)
                }
            }
            .padding(22)
            .frame(width: 440)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous).fill(palette.cardElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(palette.strokeStrong, lineWidth: 1)
            )
            .shadow(color: palette.cardShadow, radius: 25)
            .transition(.scale(scale: 0.92).combined(with: .opacity))
        }
    }

    private func insetField(placeholder: String, text: Binding<String>, secure: Bool) -> some View {
        Group {
            if secure {
                SecureField(placeholder, text: text).textFieldStyle(.plain)
            } else {
                TextField(placeholder, text: text).textFieldStyle(.plain)
            }
        }
        .font(.system(size: 12, design: .monospaced))
        .foregroundColor(palette.textPrimary)
        .padding(11)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(palette.inset))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(palette.stroke, lineWidth: 1))
    }

    private func connectionSection(
        title: String,
        logo: AnyView,
        accent: Color,
        placeholder: String,
        text: Binding<String>,
        secure: Bool,
        buttonText: String,
        isLoading: Bool,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                logo
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(palette.textSecondary)
            }
            insetField(placeholder: placeholder, text: text, secure: secure)
            Button(action: action) {
                HStack {
                    Spacer()
                    if isLoading { ProgressView().scaleEffect(0.6) }
                    else {
                        Text(buttonText)
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                    }
                    Spacer()
                }
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(LinearGradient(colors: [accent, accent.opacity(0.75)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                )
                .shadow(color: accent.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
        }
    }
}
