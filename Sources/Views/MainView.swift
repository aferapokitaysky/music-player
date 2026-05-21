import SwiftUI

struct MainView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showSettings = false
    @State private var isHoveringControls = false
    @State private var isWindowKey = true
    @State private var newPlaylistName = ""
    @State private var showNewPlaylistField = false
    @State private var isCreatePlaylistHovered = false
    @State private var isSettingsCloseHovered = false

    private var palette: Palette { themeManager.theme.palette }

    var body: some View {
        ZStack {
            palette.appTint.ignoresSafeArea()
            ambientBackdrop.allowsHitTesting(false)
            
            // Cosmic Bass Dust background layer
            CosmicDustView(isPlaying: viewModel.isPlaying, palette: palette)
                .allowsHitTesting(false)
                .ignoresSafeArea()

            HStack(spacing: 0) {
                if !viewModel.sidebarCollapsed {
                    albumsColumn
                        .frame(width: 200)
                        .background(palette.sidebar.opacity(viewModel.uiOpacity))
                        .transition(.move(edge: .leading).combined(with: .opacity))

                    Rectangle().fill(palette.divider).frame(width: 1)
                }

                tracksColumn
                    .frame(width: 360)
                    .background(palette.sidebar.opacity(viewModel.uiOpacity * 0.9))

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
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
            if let window = notification.object as? NSWindow, window == WindowController.shared.window {
                isWindowKey = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { notification in
            if let window = notification.object as? NSWindow, window == WindowController.shared.window {
                isWindowKey = false
            }
        }
    }

    // MARK: - Backdrop
    private var ambientBackdrop: some View {
        let colors = viewModel.currentAmbientColors.isEmpty
            ? (viewModel.currentTrack?.ambientColors ?? [palette.accent, palette.accentSecondary])
            : viewModel.currentAmbientColors
        return AmbientBackdropView(
            isPlaying: viewModel.isPlaying,
            ambientColors: colors,
            isDark: themeManager.theme == .dark
        )
    }

    // MARK: - Column 1 — Albums
    private var albumsColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack(alignment: .topLeading) {
                WindowDragArea().frame(height: 44)
                Spacer().frame(width: 80, height: 44)
            }

            // Brand
            HStack(spacing: 10) {
                AestheticLogoView(size: 44, color: palette.textPrimary)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Aferapokitaysky")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                    Text("Player · Pro")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(palette.textTertiary)
                }
            }
            .padding(.horizontal, 14)

            // Library header with Create Playlist button
            HStack(spacing: 0) {
                sectionLabel("БИБЛИОТЕКА")
                Spacer()
                Button(action: {
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.72)) {
                        showNewPlaylistField.toggle()
                        if !showNewPlaylistField { newPlaylistName = "" }
                    }
                }) {
                    Image(systemName: showNewPlaylistField ? "xmark" : "plus")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(isCreatePlaylistHovered ? palette.textPrimary : palette.textSecondary)
                        .frame(width: 22, height: 22)
                        .background(
                            Circle()
                                .fill(isCreatePlaylistHovered ? palette.inset : Color.clear)
                        )
                        .overlay(
                            Circle()
                                .stroke(isCreatePlaylistHovered ? palette.stroke : Color.clear, lineWidth: 1)
                        )
                        .scaleEffect(isCreatePlaylistHovered ? 1.18 : 1.0)
                        .shadow(color: isCreatePlaylistHovered ? palette.glow.opacity(0.2) : .clear, radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 14)
                .onHover { h in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.65)) {
                        isCreatePlaylistHovered = h
                    }
                }
                .help(showNewPlaylistField ? "Отмена" : "Создать плейлист")
            }

            // Inline new playlist field
            if showNewPlaylistField {
                HStack(spacing: 8) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(palette.accent)

                    TextField("Название плейлиста", text: $newPlaylistName, onCommit: {
                        createNewPlaylist()
                    })
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(palette.textPrimary)

                    let canCreate = !newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    Button(action: { createNewPlaylist() }) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(canCreate ? palette.textPrimary : palette.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canCreate)
                    .help("Создать")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(palette.inset.opacity(0.85))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(palette.accent.opacity(0.35), lineWidth: 1)
                )
                .padding(.horizontal, 8)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.95, anchor: .top)),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(viewModel.albums) { album in
                        AlbumRowView(album: album, viewModel: viewModel)
                            .environmentObject(themeManager)
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

                Button(action: {
                    withAnimation(.spring(response: 0.44, dampingFraction: 0.78)) {
                        showSettings.toggle()
                    }
                }) {
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

                Button(action: {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.62)) {
                        viewModel.sidebarCollapsed = true
                    }
                }) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(palette.textTertiary)
                        .frame(width: 28, height: 28)
                        .rotationEffect(.degrees(viewModel.sidebarCollapsed ? 180 : 0))
                }
                .buttonStyle(.plain)
                .help("Скрыть альбомы")
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }



    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .heavy, design: .monospaced))
            .tracking(1.5)
            .foregroundColor(palette.textTertiary)
            .padding(.horizontal, 14)
    }

    // MARK: - Column 2 — Tracks of selected album
    private var tracksColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topLeading) {
                WindowDragArea().frame(height: 44)
                
                HStack(spacing: 12) {
                    if viewModel.sidebarCollapsed {
                        Spacer().frame(width: 80)

                        Button(action: {
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.62)) {
                                viewModel.sidebarCollapsed = false
                            }
                        }) {
                            Image(systemName: "sidebar.left")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(palette.textSecondary)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(palette.inset))
                                .overlay(Circle().stroke(palette.stroke, lineWidth: 1))
                                .rotationEffect(.degrees(viewModel.sidebarCollapsed ? 180 : 0))
                        }
                        .buttonStyle(.plain)
                        .help("Показать альбомы")
                    }

                    Spacer()

                    searchToggleButton
                }
                .padding(.horizontal, 14)
                .frame(height: 44)
            }

            if viewModel.showSearchBar {
                searchPanel
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.98, anchor: .top)),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }

            if viewModel.showSearchBar && (!viewModel.searchResults.isEmpty || viewModel.isSearching || !viewModel.searchStatus.isEmpty) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Результаты поиска")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                        Spacer()
                        if !viewModel.searchStatus.isEmpty {
                            Text(viewModel.searchStatus)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(palette.textTertiary)
                        }
                    }
                    Text("\(viewModel.searchResults.count) треков найдено")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(palette.textTertiary)
                }
                .padding(.horizontal, 14)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 4) {
                        ForEach(viewModel.searchResults) { track in
                            TrackRowView(track: track, album: viewModel.searchAlbum, viewModel: viewModel, showsSearchAddButton: true)
                                .environmentObject(themeManager)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 12)
                }
            } else if let album = viewModel.selectedAlbum {
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
                            TrackRowView(track: track, album: album, viewModel: viewModel)
                                .environmentObject(themeManager)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 12)
                }
            } else {
                Spacer()
                Text("Создайте плейлист или найдите трек")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(palette.textTertiary)
                    .frame(maxWidth: .infinity)
                Spacer()
            }
        }
    }

    private var searchToggleButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                if viewModel.showSearchBar {
                    closeSearch()
                } else {
                    viewModel.showSearchBar = true
                }
            }
        }) {
            HStack(spacing: 7) {
                Image(systemName: viewModel.showSearchBar ? "xmark" : "magnifyingglass")
                    .font(.system(size: 11, weight: .bold))

                if !viewModel.showSearchBar {
                    Text("Поиск")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                }
            }
            .foregroundColor(viewModel.showSearchBar
                             ? (themeManager.theme == .dark ? .black : .white)
                             : palette.textSecondary)
            .frame(width: viewModel.showSearchBar ? 28 : nil, height: 28)
            .padding(.horizontal, viewModel.showSearchBar ? 0 : 10)
            .background(
                Capsule()
                    .fill(viewModel.showSearchBar ? palette.textPrimary : palette.inset)
            )
            .overlay(
                Capsule()
                    .stroke(viewModel.showSearchBar ? palette.textPrimary.opacity(0.35) : palette.stroke, lineWidth: 1)
            )
            .shadow(color: viewModel.showSearchBar ? palette.glow.opacity(0.35) : .clear, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .help(viewModel.showSearchBar ? "Скрыть поиск" : "Открыть поиск")
    }

    private var searchPanel: some View {
        VStack(spacing: 10) {
            HStack(spacing: 9) {
                ZStack {
                    Circle()
                        .fill(palette.textPrimary.opacity(0.12))
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(palette.textPrimary)
                }
                .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Поиск треков")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundColor(palette.textPrimary)
                    Text(viewModel.searchSource == .soundCloud ? "SoundCloud" : "Spotify preview")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(palette.textTertiary)
                }

                Spacer()
            }

            HStack(spacing: 0) {
                searchSourceButton(source: .soundCloud, title: "SoundCloud", logo: AnyView(SoundCloudLogo(size: 12)))
                searchSourceButton(source: .spotify, title: "Spotify", logo: AnyView(SpotifyLogo(size: 12)))
            }
            .padding(3)
            .background(RoundedRectangle(cornerRadius: 8).fill(palette.inset))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.stroke, lineWidth: 1))

            // Tip: hover a track in search results → tap ••• to add to a playlist

            HStack(spacing: 8) {
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(palette.textSecondary)

                    TextField(viewModel.searchSource == .soundCloud ? "Поиск в SoundCloud..." : "Поиск в Spotify...", text: $viewModel.searchQuery, onCommit: {
                        viewModel.executeSearch()
                    })
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(palette.textPrimary)

                    if !viewModel.searchQuery.isEmpty {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                viewModel.clearSearch()
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(palette.textTertiary)
                        }
                        .buttonStyle(.plain)
                        .help("Очистить")
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 9).fill(palette.inset))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(palette.stroke, lineWidth: 1))

                if viewModel.isSearching {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.62)
                        .frame(width: 28, height: 28)
                } else {
                    let canSearch = !viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    Button(action: { viewModel.executeSearch() }) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(canSearch ? palette.textPrimary : palette.textTertiary)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSearch)
                    .help("Найти")
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(palette.cardElevated.opacity(themeManager.theme == .dark ? 0.74 : 0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(palette.strokeStrong.opacity(0.72), lineWidth: 1)
        )
        .shadow(color: palette.cardShadow.opacity(0.18), radius: 14, x: 0, y: 8)
        .padding(.horizontal, 14)
    }

    private func searchSourceButton(source: SearchSource, title: String, logo: AnyView) -> some View {
        let isActive = viewModel.searchSource == source

        return Button(action: {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                viewModel.searchSource = source
                viewModel.resetSearch(keepingQuery: true)
            }
        }) {
            HStack(spacing: 6) {
                logo
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive ? palette.textPrimary.opacity(0.12) : Color.clear)
            )
            .foregroundColor(isActive ? palette.textPrimary : palette.textSecondary)
        }
        .buttonStyle(.plain)
    }

    private func closeSearch() {
        viewModel.showSearchBar = false
        viewModel.clearSearch()
    }

    private func createNewPlaylist() {
        let name = newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        _ = viewModel.createLocalPlaylist(named: name)
        newPlaylistName = ""
        withAnimation(.spring(response: 0.30, dampingFraction: 0.72)) {
            showNewPlaylistField = false
        }
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
                            .id(track.id + "_title")
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                        Text(track.artist)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(palette.textSecondary)
                            .lineLimit(1)
                            .id(track.id + "_artist")
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    } else {
                        Text("Нет трека")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(palette.textTertiary)
                    }
                    Spacer()
                }
                .animation(.spring(response: 0.42, dampingFraction: 0.76), value: viewModel.currentTrack)
                Spacer()
            }
            .padding(.horizontal, 22)

            VisualizerView(hfState: viewModel.hfState, isPlaying: viewModel.isPlaying)
                .environmentObject(themeManager)

            PlayerControls(viewModel: viewModel)
                .environmentObject(themeManager)
                .padding(.horizontal, 18)

            Spacer(minLength: 0)
        }
    }

    private var albumArt: some View {
        AlbumArtView(
            hfState: viewModel.hfState,
            isPlaying: viewModel.isPlaying,
            currentTrack: viewModel.currentTrack,
            palette: palette,
            togglePlayPauseAction: { viewModel.togglePlayPause() }
        )
    }

    // MARK: - Settings overlay
    private var settingsOverlay: some View {
        ZStack {
            Color.black.opacity(themeManager.theme == .dark ? 0.55 : 0.30)
                .edgesIgnoringSafeArea(.all)
                .transition(.opacity)
                .onTapGesture {
                    withAnimation(.spring(response: 0.44, dampingFraction: 0.78)) {
                        showSettings = false
                    }
                }

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
                    Button(action: {
                        withAnimation(.spring(response: 0.44, dampingFraction: 0.78)) {
                            showSettings = false
                        }
                    }) {
                        Image(systemName: isSettingsCloseHovered ? "xmark.circle.fill" : "xmark.circle")
                            .font(.title3)
                            .foregroundColor(isSettingsCloseHovered ? Color.red.opacity(0.85) : palette.textTertiary)
                            .scaleEffect(isSettingsCloseHovered ? 1.18 : 1.0)
                            .shadow(color: isSettingsCloseHovered ? Color.red.opacity(0.3) : .clear, radius: 6, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                    .onHover { h in
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.65)) {
                            isSettingsCloseHovered = h
                        }
                    }
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

                Rectangle().fill(palette.divider).frame(height: 1)

                // UI panel opacity slider
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.dashed")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(palette.accent)
                        Text("ПРОЗРАЧНОСТЬ UI ПАНЕЛЕЙ")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(palette.textSecondary)
                    }

                    HStack(spacing: 12) {
                        Slider(value: $viewModel.uiOpacity, in: 0.15...0.95)
                            .accentColor(palette.accent)

                        Text("\(Int(viewModel.uiOpacity * 100))%")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(palette.textSecondary)
                            .frame(width: 36, alignment: .trailing)
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
            .transition(
                .asymmetric(
                    insertion: .modifier(
                        active: RotationPerspectiveModifier(angle: -35, scale: 0.9, opacity: 0),
                        identity: RotationPerspectiveModifier(angle: 0, scale: 1, opacity: 1)
                    ),
                    removal: .modifier(
                        active: RotationPerspectiveModifier(angle: 35, scale: 0.9, opacity: 0),
                        identity: RotationPerspectiveModifier(angle: 0, scale: 1, opacity: 1)
                    )
                )
            )
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

// MARK: - Standalone High-Performance Breathing Backglow Backdrop View
struct AmbientBackdropView: View {
    let isPlaying: Bool
    let ambientColors: [Color]
    let isDark: Bool
    
    @State private var ambientBreath: Double = 0.95

    var body: some View {
        let dynamicBreath = ambientBreath

        return ZStack {
            Circle().fill(ambientColors[0].opacity((isDark ? 0.12 : 0.10) * (dynamicBreath * 0.8 + 0.2)))
                .frame(width: 360 * dynamicBreath, height: 360 * dynamicBreath)
                .blur(radius: 90)
                .offset(x: -260, y: -180)
            Circle().fill(ambientColors[1].opacity((isDark ? 0.10 : 0.08) * (dynamicBreath * 0.8 + 0.2)))
                .frame(width: 380 * dynamicBreath, height: 380 * dynamicBreath)
                .blur(radius: 100)
                .offset(x: 320, y: 220)
        }
        .animation(.easeInOut(duration: 1.5), value: ambientColors)
        .onAppear {
            withAnimation(.easeInOut(duration: 6.0).repeatForever(autoreverses: true)) {
                ambientBreath = 1.12
            }
        }
    }
}

// MARK: - Standalone High-Frequency 3D Parallax Album Art View
struct AlbumArtView: View {
    @ObservedObject var hfState: HighFrequencyState
    let isPlaying: Bool
    let currentTrack: Track?
    let palette: Palette
    let togglePlayPauseAction: () -> Void

    @State private var artGlowPhase: Double = 0
    @State private var isHoveringArt = false
    @State private var parallaxOffset: CGSize = .zero

    var body: some View {
        let intensity = hfState.visualizerBars.reduce(0.0, +) / max(1.0, Double(hfState.visualizerBars.count))
        let dynamicScale = 1.0 + (isPlaying ? intensity * 0.08 : 0.0)
        let dynamicBlur = 22 + (isPlaying ? CGFloat(intensity * 18.0) : 0.0)
        let dynamicOpacity = isPlaying ? (0.40 + 0.25 * artGlowPhase + intensity * 0.35) : 0.12
        let artSize: CGFloat = 160

        return ZStack {
            // Ambient glowing back shadow matching the album art colors
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(colors: palette.accentGradient,
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: artSize, height: artSize)
                .blur(radius: dynamicBlur)
                .opacity(dynamicOpacity)
                .scaleEffect(dynamicScale)

            // High-fidelity square album art card (no vinyl, matches the new premium spec)
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(palette.inset)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(palette.strokeStrong, lineWidth: 1)
                    )

                if let track = currentTrack {
                    Group {
                        if let url = track.albumArtUrl, url.hasPrefix("http") {
                            AsyncImage(url: URL(string: url)) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                ProgressView().scaleEffect(0.6)
                            }
                        } else {
                            ZStack {
                                LinearGradient(
                                    colors: [palette.accent.opacity(0.35), palette.accentSecondary.opacity(0.35)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                Image(systemName: track.albumArtUrl ?? "music.note")
                                    .font(.system(size: 38, weight: .bold))
                                    .foregroundColor(palette.textPrimary)
                            }
                        }
                    }
                    .frame(width: artSize - 8, height: artSize - 8)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    
                    // Specular gloss reflection overlay matching main UI
                    LinearGradient(
                        colors: [.white.opacity(0.24), .clear, .white.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: artSize - 8, height: artSize - 8)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .blendMode(.overlay)
                    .allowsHitTesting(false)
                }
            }
            .frame(width: artSize, height: artSize)
            .scaleEffect(dynamicScale)
        }
        .frame(width: artSize, height: artSize)
        .scaleEffect(isHoveringArt ? 1.06 : 1.0)
        .offset(y: isPlaying ? CGFloat(sin(artGlowPhase * .pi * 2.0) * 5.0) : 0.0)
        .rotationEffect(.degrees(isPlaying ? cos(artGlowPhase * .pi * 2.0) * 2.0 : 0.0))
        .rotation3DEffect(.degrees(Double(parallaxOffset.width / 5.0)), axis: (x: 0, y: 1, z: 0))
        .rotation3DEffect(.degrees(Double(-parallaxOffset.height / 5.0)), axis: (x: 1, y: 0, z: 0))
        .shadow(color: palette.accent.opacity(isHoveringArt ? 0.25 : 0.0), radius: 15, x: 0, y: 8)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { val in
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.65)) {
                        parallaxOffset = CGSize(width: val.location.x - artSize/2, height: val.location.y - artSize/2)
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                        parallaxOffset = .zero
                    }
                }
        )
        .onHover { hovering in
            withAnimation(.spring(response: 0.32, dampingFraction: 0.68)) {
                isHoveringArt = hovering
            }
        }
        .onTapGesture(count: 2) {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.45)) {
                togglePlayPauseAction()
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                artGlowPhase = 1
            }
        }
    }
}

// MARK: - Transitions
struct RotationPerspectiveModifier: ViewModifier {
    let angle: Double
    let scale: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(angle), axis: (x: 1, y: -0.2, z: 0), anchor: .center, perspective: 0.6)
            .scaleEffect(scale)
            .opacity(opacity)
    }
}
