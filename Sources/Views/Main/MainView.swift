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
    @State private var showResetConfirmation = false
    @State private var settingsTab = 0
    @State private var hoveredColorKey: String? = nil
    @State private var hoveredNotchKey: String? = nil
    @State private var previewMode = 0
    @State private var showApplySuccess = false

    @FocusState private var isSearchInputFocused: Bool
    @State private var isSearchCloseHovered = false
    @State private var hoveredSearchTab: String? = nil
    @State private var isClearButtonHovered = false
    @State private var isPlaylistPickerHovered = false
    @AppStorage("recentSearchQueries") var recentQueriesStr: String = ""
    @AppStorage("layoutOrderString") var layoutOrderString: String = "albums|tracks|player"
    @AppStorage("playerLayoutOrderString") var playerLayoutOrderString: String = "meta|visualizer|controls"

    @AppStorage("customAccent") var customAccent: String = "#FF5500"
    @AppStorage("customSidebar") var customSidebar: String = "#111111"
    @AppStorage("customAppTint") var customAppTint: String = "#000000"
    @AppStorage("customCard") var customCard: String = "#222222"
    @AppStorage("customTextPrimary") var customTextPrimary: String = "#FFFFFF"
    @AppStorage("customProgress") var customProgress: String = "#FF5500"
    @AppStorage("customGlow") var customGlow: String = "#FF5500"

    @AppStorage("notchBackgroundStyle") var notchBackgroundStyle: Int = 0
    @AppStorage("notchCustomColor") var notchCustomColor: String = "#000000"
    @AppStorage("notchParticlesEnabled") var notchParticlesEnabled: Bool = true
    @AppStorage("notchVisualizerEnabled") var notchVisualizerEnabled: Bool = true
    @AppStorage("notchVisualizerColor") var notchVisualizerColor: String = "#FFFFFF"

    private var palette: Palette { themeManager.theme.palette }

    private func colorBinding(for hex: Binding<String>, key: String) -> Binding<Color> {
        Binding<Color>(
            get: { Color(hex: hex.wrappedValue) },
            set: { newColor in
                let hexStr = newColor.toHex()
                hex.wrappedValue = hexStr
                UserDefaults.standard.set(hexStr, forKey: key)
                UserDefaults.standard.synchronize()
                themeManager.forceRefresh()
                NotificationCenter.default.post(name: .themeDidChange, object: themeManager.theme)
            }
        )
    }
    private var totalTrackCount: Int {
        viewModel.albums.reduce(0) { $0 + $1.tracks.count }
    }

    var body: some View {
        ZStack {
            palette.appTint.ignoresSafeArea()

            if viewModel.visualEffectsEnabled {
                ambientBackdrop.allowsHitTesting(false)

                CosmicDustView(hfState: viewModel.hfState, isPlaying: viewModel.isPlaying, palette: palette)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }

            HStack(spacing: 0) {
                ForEach(visibleBlocks, id: \.self) { block in
                    switch block {
                    case .albums:
                        albumsColumn
                            .frame(width: 200)
                            .background(palette.sidebar.opacity(viewModel.uiOpacity))
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    case .tracks:
                        tracksColumn
                            .frame(width: 360)
                            .background(palette.sidebar.opacity(viewModel.uiOpacity * 0.9))
                    case .player:
                        playerColumn
                            .frame(maxWidth: .infinity)
                    }
                    
                    if block != visibleBlocks.last {
                        Rectangle().fill(palette.divider).frame(width: 1)
                    }
                }
            }
        }
        .frame(minWidth: 980, minHeight: 580)
        .foregroundColor(palette.textPrimary)
        .overlay(Group { if showSettings { settingsOverlay } })
        .overlay(Group { if viewModel.showSearchBar { spotlightSearchOverlay } })
        .alert("Сбросить библиотеку?", isPresented: $showResetConfirmation) {
            Button("Сбросить", role: .destructive) {
                viewModel.clearLibrary()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Будут очищены локальная библиотека, кэш подключений и сохраненные токены.")
        }
        .animation(.easeInOut(duration: 0.30), value: themeManager.theme)
        .animation(.easeInOut(duration: 0.25), value: viewModel.sidebarCollapsed)
        .onReceive(viewModel.$showSearchBar) { show in
            if show {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isSearchInputFocused = true
                }
            } else {
                isSearchInputFocused = false
            }
        }
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

            // Brand & Collapse Button
            HStack(spacing: 10) {
                AestheticLogoView(size: 38, color: palette.textPrimary)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Aferapokitaysky")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .tracking(0.3)
                    Text("Player · Pro")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(palette.textTertiary)
                }
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.62)) {
                        viewModel.sidebarCollapsed = true
                    }
                }) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(palette.textSecondary)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(palette.inset))
                        .overlay(Circle().stroke(palette.stroke, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .help("Скрыть альбомы")
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
                    if viewModel.albums.isEmpty {
                        sidebarEmptyState
                    } else {
                        ForEach(viewModel.albums) { album in
                            AlbumRowView(album: album, viewModel: viewModel)
                                .environmentObject(themeManager)
                        }
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
                
                HStack(spacing: 8) {
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

                    searchToggleButton
                    
                    Spacer()
                }
                .padding(.horizontal, 14)
                .frame(height: 44)
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
                            TrackRowView(track: track, album: album, viewModel: viewModel)
                                .environmentObject(themeManager)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 12)
                }
            } else {
                Spacer()
                emptyTracksState
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
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .bold))

                Text("Поиск")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
            }
            .foregroundColor(viewModel.showSearchBar ? palette.accent : palette.textSecondary)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(
                Capsule()
                    .fill(viewModel.showSearchBar ? palette.accent.opacity(0.15) : palette.inset)
            )
            .overlay(
                Capsule()
                    .stroke(viewModel.showSearchBar ? palette.accent.opacity(0.4) : palette.stroke, lineWidth: 1)
            )
            .shadow(color: viewModel.showSearchBar ? palette.glow.opacity(0.2) : .clear, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .help("Поиск треков (Spotlight)")
    }

    // MARK: - Recent Searches Helpers
    private var recentQueries: [String] {
        recentQueriesStr.split(separator: "|").map(String.init)
    }

    private func addRecentQuery(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var current = recentQueries
        if let idx = current.firstIndex(of: trimmed) {
            current.remove(at: idx)
        }
        current.insert(trimmed, at: 0)
        if current.count > 5 {
            current = Array(current.prefix(5))
        }
        recentQueriesStr = current.joined(separator: "|")
    }

    private func clearRecentQueries() {
        withAnimation(.easeInOut(duration: 0.2)) {
            recentQueriesStr = ""
        }
    }

    // MARK: - Layout Ordering computed properties and helpers
    private var layoutOrder: [LayoutBlock] {
        let parts = layoutOrderString.split(separator: "|").map(String.init)
        let parsed = parts.compactMap { LayoutBlock(rawValue: $0) }
        if parsed.count == 3 {
            return parsed
        }
        return [.albums, .tracks, .player]
    }

    private var visibleBlocks: [LayoutBlock] {
        layoutOrder.filter { block in
            if block == .albums {
                return !viewModel.sidebarCollapsed
            }
            return true
        }
    }

    private func moveBlockLeft(_ block: LayoutBlock) {
        var order = layoutOrder
        guard let idx = order.firstIndex(of: block), idx > 0 else { return }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
            order.swapAt(idx, idx - 1)
            layoutOrderString = order.map { $0.rawValue }.joined(separator: "|")
        }
    }

    private func moveBlockRight(_ block: LayoutBlock) {
        var order = layoutOrder
        guard let idx = order.firstIndex(of: block), idx < order.count - 1 else { return }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
            order.swapAt(idx, idx + 1)
            layoutOrderString = order.map { $0.rawValue }.joined(separator: "|")
        }
    }

    // MARK: - Player Column Vertical Layout computed properties and helpers
    private var playerLayoutOrder: [PlayerBlock] {
        let parts = playerLayoutOrderString.split(separator: "|").map(String.init)
        let parsed = parts.compactMap { PlayerBlock(rawValue: $0) }
        if parsed.count == 3 {
            return parsed
        }
        return [.meta, .visualizer, .controls]
    }

    private func movePlayerBlockUp(_ block: PlayerBlock) {
        var order = playerLayoutOrder
        guard let idx = order.firstIndex(of: block), idx > 0 else { return }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
            order.swapAt(idx, idx - 1)
            playerLayoutOrderString = order.map { $0.rawValue }.joined(separator: "|")
        }
    }

    private func movePlayerBlockDown(_ block: PlayerBlock) {
        var order = playerLayoutOrder
        guard let idx = order.firstIndex(of: block), idx < order.count - 1 else { return }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
            order.swapAt(idx, idx + 1)
            playerLayoutOrderString = order.map { $0.rawValue }.joined(separator: "|")
        }
    }

    // MARK: - Spotlight Search Overlay
    private var searchBrandColor: Color {
        viewModel.searchSource == .spotify 
            ? Color(red: 29/255.0, green: 185/255.0, blue: 84/255.0) 
            : Color(red: 255/255.0, green: 85/255.0, blue: 0/255.0)
    }

    private var spotlightSearchOverlay: some View {
        ZStack {
            // 1. Full screen blur and darken backdrop
            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow, cornerRadius: 0)
                .edgesIgnoringSafeArea(.all)
                .transition(.opacity)
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                        closeSearch()
                    }
                }
            
            Color.black.opacity(themeManager.theme == .dark ? 0.50 : 0.25)
                .edgesIgnoringSafeArea(.all)
                .transition(.opacity)
                .allowsHitTesting(false)

            // 2. Volumetric Ambient Glow Halo
            Circle()
                .fill(RadialGradient(
                    colors: [searchBrandColor.opacity(themeManager.theme == .dark ? 0.22 : 0.15), Color.clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 240
                ))
                .frame(width: 480, height: 480)
                .blur(radius: 40)
                .offset(y: -40)
                .allowsHitTesting(false)
                .transition(.opacity.combined(with: .scale(scale: 0.85)))

            // 3. Central Spotlight Floating Card
            VStack(spacing: 0) {
                // Input header
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(searchBrandColor.opacity(0.12))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(searchBrandColor)
                    }
                    
                    TextField(viewModel.searchSource == .soundCloud ? "Поиск треков в SoundCloud..." : "Поиск треков в Spotify...", text: $viewModel.searchQuery, onCommit: {
                        addRecentQuery(viewModel.searchQuery)
                        viewModel.executeSearch()
                    })
                    .focused($isSearchInputFocused)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(palette.textPrimary)
                    
                    if viewModel.isSearching {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.7)
                            .accentColor(searchBrandColor)
                            .frame(width: 32, height: 32)
                    } else if !viewModel.searchQuery.isEmpty {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                viewModel.clearSearch()
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(isClearButtonHovered ? palette.textPrimary : palette.textTertiary)
                        }
                        .buttonStyle(.plain)
                        .onHover { isClearButtonHovered = $0 }
                        .transition(.opacity)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(palette.inset.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isSearchInputFocused ? searchBrandColor.opacity(0.75) : palette.stroke, lineWidth: 1.5)
                )
                .padding([.top, .horizontal], 16)
                
                // Switchers Row: Tabs + Destination Picker
                HStack(spacing: 12) {
                    // Sources Tabs
                    HStack(spacing: 6) {
                        spotlightSourceButton(source: .soundCloud, title: "SoundCloud", logo: AnyView(SoundCloudLogo(size: 12)), brandColor: Color(red: 255/255.0, green: 85/255.0, blue: 0/255.0))
                        spotlightSourceButton(source: .spotify, title: "Spotify", logo: AnyView(SpotifyLogo(size: 12)), brandColor: Color(red: 29/255.0, green: 185/255.0, blue: 84/255.0))
                    }
                    .padding(3)
                    .background(RoundedRectangle(cornerRadius: 10).fill(palette.inset.opacity(0.4)))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(palette.stroke, lineWidth: 1))
                    
                    Spacer()
                    
                    // Destination Playlist Picker
                    if !viewModel.localPlaylists.isEmpty {
                        spotlightTargetPicker
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

                Divider().background(palette.divider).padding(.horizontal, 16)

                // Results or Empty State list
                ZStack {
                    if viewModel.searchResults.isEmpty {
                        VStack(spacing: 0) {
                            if viewModel.searchQuery.isEmpty {
                                if recentQueries.isEmpty && viewModel.recentSearchTracks.isEmpty {
                                    // Completely empty onboarding state
                                    Spacer()
                                    
                                    // Futuristic Holographic Search Icon
                                    ZStack {
                                        Circle()
                                            .fill(searchBrandColor.opacity(0.06))
                                            .frame(width: 80, height: 80)
                                            .scaleEffect(isSearchInputFocused ? 1.08 : 1.0)
                                            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isSearchInputFocused)
                                        
                                        Circle()
                                            .stroke(searchBrandColor.opacity(0.15), lineWidth: 1.5)
                                            .frame(width: 80, height: 80)
                                        
                                        Image(systemName: viewModel.searchSource == .soundCloud ? "waveform.and.mic" : "music.note.house.fill")
                                            .font(.system(size: 32))
                                            .foregroundColor(searchBrandColor.opacity(0.85))
                                    }
                                    
                                    VStack(spacing: 4) {
                                        Text("ВВЕДИТЕ ЗАПРОС")
                                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                            .tracking(1.5)
                                            .foregroundColor(palette.textPrimary)
                                        
                                        Text("Введите название трека или имя артиста для поиска на \(viewModel.searchSource == .soundCloud ? "SoundCloud" : "Spotify")")
                                            .font(.system(size: 10, weight: .medium, design: .rounded))
                                            .foregroundColor(palette.textTertiary)
                                            .multilineTextAlignment(.center)
                                            .frame(maxWidth: 320)
                                    }
                                    .padding(.top, 12)
                                    
                                    Spacer()
                                } else {
                                    // Display horizontal text queries history
                                    if !recentQueries.isEmpty {
                                        VStack(alignment: .leading, spacing: 10) {
                                            HStack {
                                                Text("НЕДАВНИЕ ЗАПРОСЫ")
                                                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                                    .tracking(1.5)
                                                    .foregroundColor(palette.textTertiary)
                                                
                                                Spacer()
                                                
                                                Button(action: clearRecentQueries) {
                                                    Image(systemName: "trash")
                                                        .font(.system(size: 10))
                                                        .foregroundColor(palette.textTertiary)
                                                }
                                                .buttonStyle(.plain)
                                                .help("Очистить историю")
                                            }
                                            .padding(.horizontal, 16)
                                            
                                            ScrollView(.horizontal, showsIndicators: false) {
                                                HStack(spacing: 8) {
                                                    ForEach(recentQueries, id: \.self) { query in
                                                        Button(action: {
                                                            withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                                                                viewModel.searchQuery = query
                                                                addRecentQuery(query)
                                                                viewModel.executeSearch()
                                                            }
                                                        }) {
                                                            HStack(spacing: 5) {
                                                                Image(systemName: "clock.arrow.circlepath")
                                                                    .font(.system(size: 8))
                                                                Text(query)
                                                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                                            }
                                                            .padding(.horizontal, 10)
                                                            .padding(.vertical, 6)
                                                            .foregroundColor(palette.textPrimary)
                                                            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(searchBrandColor.opacity(0.12)))
                                                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(searchBrandColor.opacity(0.3), lineWidth: 1))
                                                        }
                                                        .buttonStyle(.plain)
                                                    }
                                                }
                                                .padding(.horizontal, 16)
                                            }
                                        }
                                        .padding(.top, 14)
                                    }
                                    
                                    // Display vertical play history
                                    if !viewModel.recentSearchTracks.isEmpty {
                                        VStack(alignment: .leading, spacing: 10) {
                                            HStack {
                                                Text("ИСТОРИЯ ЗАПУСКОВ")
                                                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                                    .tracking(1.5)
                                                    .foregroundColor(palette.textTertiary)
                                                
                                                Spacer()
                                                
                                                Button(action: {
                                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                                                        viewModel.clearSearchHistory()
                                                    }
                                                }) {
                                                    Image(systemName: "trash")
                                                        .font(.system(size: 10))
                                                        .foregroundColor(palette.textTertiary)
                                                }
                                                .buttonStyle(.plain)
                                                .help("Очистить историю запусков")
                                            }
                                            .padding(.horizontal, 16)
                                            
                                            ScrollView(.vertical, showsIndicators: false) {
                                                VStack(spacing: 4) {
                                                    ForEach(viewModel.recentSearchTracks) { track in
                                                        SpotlightTrackRow(track: track, album: viewModel.searchHistoryAlbum, viewModel: viewModel, brandColor: searchBrandColor)
                                                            .environmentObject(themeManager)
                                                    }
                                                }
                                                .padding(.horizontal, 10)
                                            }
                                        }
                                        .padding(.top, 18)
                                    }
                                    
                                    Spacer(minLength: 12)
                                }
                            } else {
                                // Searching but nothing found state
                                Spacer()
                                
                                ZStack {
                                    Circle()
                                        .fill(searchBrandColor.opacity(0.06))
                                        .frame(width: 80, height: 80)
                                    
                                    Circle()
                                        .stroke(searchBrandColor.opacity(0.15), lineWidth: 1.5)
                                        .frame(width: 80, height: 80)
                                    
                                    Image(systemName: "exclamationmark.bubble")
                                        .font(.system(size: 32))
                                        .foregroundColor(searchBrandColor.opacity(0.85))
                                }
                                
                                VStack(spacing: 4) {
                                    Text("НИЧЕГО НЕ НАЙДЕНО")
                                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                        .tracking(1.5)
                                        .foregroundColor(palette.textPrimary)
                                    
                                    Text("По вашему запросу ничего не найдено. Попробуйте изменить формулировку.")
                                        .font(.system(size: 10, weight: .medium, design: .rounded))
                                        .foregroundColor(palette.textTertiary)
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: 320)
                                }
                                .padding(.top, 12)
                                
                                Spacer()
                            }
                        }
                        .transition(.opacity)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("РЕЗУЛЬТАТЫ ПОИСКА")
                                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                    .tracking(1.5)
                                    .foregroundColor(palette.textTertiary)
                                
                                Spacer()
                                
                                if !viewModel.searchStatus.isEmpty {
                                    HStack(spacing: 6) {
                                        Circle().fill(searchBrandColor).frame(width: 4, height: 4)
                                        Text(viewModel.searchStatus)
                                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                                            .foregroundColor(searchBrandColor)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(searchBrandColor.opacity(0.12)))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                            ScrollView(.vertical, showsIndicators: false) {
                                VStack(spacing: 4) {
                                    ForEach(viewModel.searchResults) { track in
                                        SpotlightTrackRow(track: track, album: viewModel.searchAlbum, viewModel: viewModel, brandColor: searchBrandColor)
                                            .environmentObject(themeManager)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.bottom, 12)
                            }
                        }
                        .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider().background(palette.divider)

                // Keycap Guides Legend Footer
                HStack(spacing: 16) {
                    KeycapView(key: "⎋ Esc", label: "Закрыть", palette: palette)
                    
                    KeycapView(key: "↩ Enter", label: "Найти", palette: palette)
                    
                    KeycapView(key: "⌘S", label: "Источник", palette: palette)
                    
                    Spacer()
                    
                    // Display target status in footer if present
                    if let target = viewModel.searchTargetPlaylist {
                        HStack(spacing: 4) {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 8))
                            Text("В «\(target.name)»")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(palette.textTertiary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(palette.inset.opacity(0.2))
            }
            .frame(width: 620, height: 500)
            .background(
                VisualEffectView(material: .popover, blendingMode: .withinWindow, cornerRadius: 18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(palette.cardElevated.opacity(themeManager.theme == .dark ? 0.45 : 0.65))
                    )
            )
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(LinearGradient(
                        colors: [palette.strokeStrong, palette.stroke.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ), lineWidth: 1.5)
            )
            .shadow(color: searchBrandColor.opacity(themeManager.theme == .dark ? 0.22 : 0.15), radius: 35, x: 0, y: 15)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.94).combined(with: .opacity),
                removal: .scale(scale: 0.96).combined(with: .opacity)
            ))
            
            // 4. Hidden Keyboard Shortcuts Buttons
            Group {
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                        closeSearch()
                    }
                }) {
                    EmptyView()
                }
                .keyboardShortcut(.cancelAction)
                
                Button(action: {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                        viewModel.searchSource = (viewModel.searchSource == .soundCloud) ? .spotify : .soundCloud
                        viewModel.resetSearch(keepingQuery: true)
                        if !viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            viewModel.executeSearch()
                        }
                    }
                }) {
                    EmptyView()
                }
                .keyboardShortcut("s", modifiers: [.command])
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.showSearchBar)
        }
    }

    private func spotlightSourceButton(source: SearchSource, title: String, logo: AnyView, brandColor: Color) -> some View {
        let isActive = viewModel.searchSource == source
        let isHovered = hoveredSearchTab == title
        
        return Button(action: {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                viewModel.searchSource = source
                viewModel.resetSearch(keepingQuery: true)
                if !viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    viewModel.executeSearch()
                }
            }
        }) {
            HStack(spacing: 8) {
                logo
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 14)
            .foregroundColor(isActive ? palette.textPrimary : (isHovered ? palette.textSecondary : palette.textTertiary))
            .background(
                ZStack {
                    if isActive {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(brandColor.opacity(0.15))
                    } else if isHovered {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(palette.inset.opacity(0.5))
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isActive ? brandColor.opacity(0.4) : Color.clear, lineWidth: 1)
            )
            .scaleEffect(isHovered ? 1.03 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { h in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.65)) {
                hoveredSearchTab = h ? title : nil
            }
        }
    }

    private var spotlightTargetPicker: some View {
        HStack(spacing: 6) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(palette.textSecondary)

            Text("В:")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(palette.textSecondary)

            Picker("", selection: Binding(
                get: { viewModel.searchTargetPlaylistId ?? viewModel.localPlaylists.first?.id ?? "" },
                set: { viewModel.searchTargetPlaylistId = $0 }
            )) {
                ForEach(viewModel.localPlaylists) { playlist in
                    Text(playlist.name).tag(playlist.id)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .scaleEffect(0.95)
            .frame(maxWidth: 160)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(palette.inset.opacity(0.4)))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(palette.stroke, lineWidth: 1))
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
            topUtilityBar

            ForEach(playerLayoutOrder, id: \.self) { block in
                switch block {
                case .meta:
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
                case .visualizer:
                    VisualizerView(hfState: viewModel.hfState, isPlaying: viewModel.isPlaying)
                        .environmentObject(themeManager)
                case .controls:
                    PlayerControls(viewModel: viewModel)
                        .environmentObject(themeManager)
                        .padding(.horizontal, 18)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var topUtilityBar: some View {
        ZStack {
            WindowDragArea().frame(height: 44)

            HStack(spacing: 8) {
                compactPill(icon: "music.quarternote.3", text: "\(viewModel.albums.count) / \(totalTrackCount)", tint: palette.textSecondary)

                if viewModel.visualEffectsEnabled {
                    compactPill(icon: "sparkles", text: "FX", tint: palette.accent)
                }

                Spacer()

                if let statusText = liveStatusText {
                    compactPill(icon: viewModel.isConnecting || viewModel.isSearching ? "waveform" : "checkmark.circle", text: statusText, tint: palette.accent)
                        .frame(maxWidth: 260)
                } else {
                    Capsule().fill(palette.textTertiary.opacity(0.45))
                        .frame(width: 44, height: 4)
                }
            }
            .padding(.horizontal, 18)
            .frame(height: 44)
        }
    }

    private var liveStatusText: String? {
        if viewModel.isConnecting { return "Подключение" }
        if viewModel.isSearching { return "Поиск" }
        if !viewModel.searchStatus.isEmpty { return viewModel.searchStatus }
        if !viewModel.connectionStatus.isEmpty { return viewModel.connectionStatus }
        return nil
    }

    private func compactPill(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .lineLimit(1)
        }
        .foregroundColor(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(palette.inset.opacity(0.80)))
        .overlay(Capsule().stroke(palette.stroke, lineWidth: 1))
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
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(palette.accent)
                        Text("НАСТРОЙКИ ПЛЕЕРА")
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

                HStack(spacing: 0) {
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            settingsTab = 0
                        }
                    }) {
                        Text("СЕРВИСЫ")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                            .foregroundColor(settingsTab == 0 ? palette.textPrimary : palette.textSecondary)
                            .background(settingsTab == 0 ? palette.inset : Color.clear)
                            .contentShape(Rectangle())
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            settingsTab = 1
                        }
                    }) {
                        Text("КОНСТРУКТОР")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                            .foregroundColor(settingsTab == 1 ? palette.textPrimary : palette.textSecondary)
                            .background(settingsTab == 1 ? palette.inset : Color.clear)
                            .contentShape(Rectangle())
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(4)
                .background(RoundedRectangle(cornerRadius: 10).fill(palette.card))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(palette.stroke, lineWidth: 0.8))

                if settingsTab == 0 {
                    servicesTabContent
                } else {
                    constructorTabContent
                }

                Rectangle().fill(palette.divider).frame(height: 1)

                // UI refinement controls
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

                    Toggle(isOn: $viewModel.visualEffectsEnabled) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(palette.accent)
                            Text("АМБИЕНТ И ЧАСТИЦЫ")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(palette.textSecondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .padding(.top, 4)
                }

                if !viewModel.connectionStatus.isEmpty {
                    Text(viewModel.connectionStatus)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(palette.accent)
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)
                }
            }
            .padding(24)
            .frame(width: 560)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        themeManager.theme == .light ? Color.white :
                        (themeManager.theme == .custom ? Color(hex: customSidebar) : Color(hex: "#121214"))
                    )
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

    @ViewBuilder
    private var servicesTabContent: some View {
        VStack(spacing: 16) {
            // Spotify Card
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    SpotifyLogo(size: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Spotify")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(palette.textPrimary)
                        
                        if viewModel.spotifyToken.isEmpty {
                            Text("Не подключен")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundColor(palette.textTertiary)
                        } else {
                            Text("Подключен (Превью-треки)")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundColor(.spotifyGreen)
                        }
                    }
                    Spacer()
                }
                
                if viewModel.spotifyToken.isEmpty {
                    Button(action: { viewModel.startSpotifyWebLogin() }) {
                        HStack {
                            Spacer()
                            Image(systemName: "safari")
                            Text("Привязать Spotify")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.spotifyGreen))
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: { viewModel.disconnectSpotify() }) {
                        HStack {
                            Spacer()
                            Text("Отвязать Spotify")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                            Spacer()
                        }
                        .foregroundColor(palette.textSecondary)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(palette.inset))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(palette.stroke, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14).fill(palette.card))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.stroke, lineWidth: 0.8))
            
            // SoundCloud Card
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    SoundCloudLogo(size: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SoundCloud")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(palette.textPrimary)
                        
                        if viewModel.soundCloudOAuth.isEmpty {
                            Text("Не подключен")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundColor(palette.textTertiary)
                        } else {
                            Text("Подключен (Likes & Tracks)")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundColor(.soundcloudOrange)
                        }
                    }
                    Spacer()
                }
                
                if viewModel.soundCloudOAuth.isEmpty {
                    Button(action: { viewModel.startSoundCloudWebLogin() }) {
                        HStack {
                            Spacer()
                            Image(systemName: "safari")
                            Text("Привязать SoundCloud")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.soundcloudOrange))
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: { viewModel.disconnectSoundCloud() }) {
                        HStack {
                            Spacer()
                            Text("Отвязать SoundCloud")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                            Spacer()
                        }
                        .foregroundColor(palette.textSecondary)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(palette.inset))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(palette.stroke, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14).fill(palette.card))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.stroke, lineWidth: 0.8))
            
            // Local Import & Reset Actions
            HStack(spacing: 10) {
                Button(action: { viewModel.importLocalAudioFiles() }) {
                    HStack {
                        Image(systemName: "folder.badge.plus")
                        Text("Импорт")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(palette.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(palette.inset))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(palette.stroke, lineWidth: 0.8))
                }
                .buttonStyle(.plain)
                .help("Импортировать локальные файлы (.mp3, .m4a, .wav, etc.)")
                
                Button(action: { showResetConfirmation = true }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Сброс")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(palette.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(palette.inset))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(palette.stroke, lineWidth: 0.8))
                }
                .buttonStyle(.plain)
                .help("Очистить кэш и библиотеку")
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private var constructorTabContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                // Theme select
                VStack(alignment: .leading, spacing: 6) {
                    Text("РЕЖИМ ОФОРМЛЕНИЯ")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundColor(palette.textTertiary)
                    
                    Picker("", selection: $themeManager.theme) {
                        Text("Темная").tag(AppTheme.dark)
                        Text("Светлая").tag(AppTheme.light)
                        Text("Кастомная").tag(AppTheme.custom)
                    }
                    .pickerStyle(.segmented)
                }

                // Layout Ordering Card
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("РАСПОЛОЖЕНИЕ БЛОКОВ (ИНТЕРФЕЙС)")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .tracking(1.2)
                            .foregroundColor(palette.textTertiary)
                        Spacer()
                        Button(action: {
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                                layoutOrderString = "albums|tracks|player"
                            }
                        }) {
                            Text("Сбросить порядок")
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .foregroundColor(palette.accent)
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 8) {
                        ForEach(layoutOrder, id: \.self) { block in
                            let idx = layoutOrder.firstIndex(of: block) ?? 0

                            VStack(spacing: 5) {
                                HStack(spacing: 5) {
                                    Image(systemName: block.icon)
                                        .font(.system(size: 11))
                                        .foregroundColor(palette.accent)
                                    Text(block.displayName.uppercased())
                                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                                        .foregroundColor(palette.textPrimary)
                                        .lineLimit(1)
                                }
                                .frame(height: 18)

                                HStack(spacing: 8) {
                                    Button(action: { moveBlockLeft(block) }) {
                                        Image(systemName: "arrow.left")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(idx > 0 ? palette.textPrimary : palette.textTertiary)
                                            .frame(width: 18, height: 18)
                                            .background(Circle().fill(idx > 0 ? palette.card : Color.clear))
                                            .overlay(Circle().stroke(idx > 0 ? palette.stroke : Color.clear, lineWidth: 0.8))
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(idx == 0)

                                    Button(action: { moveBlockRight(block) }) {
                                        Image(systemName: "arrow.right")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(idx < layoutOrder.count - 1 ? palette.textPrimary : palette.textTertiary)
                                            .frame(width: 18, height: 18)
                                            .background(Circle().fill(idx < layoutOrder.count - 1 ? palette.card : Color.clear))
                                            .overlay(Circle().stroke(idx < layoutOrder.count - 1 ? palette.stroke : Color.clear, lineWidth: 0.8))
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(idx == layoutOrder.count - 1)
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 8)
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(palette.inset))
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(palette.stroke, lineWidth: 0.8))
                        }
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(palette.card.opacity(0.15)))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(palette.stroke, lineWidth: 0.8))

                // Player Column Vertical Ordering Card
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("ПОРЯДОК ЭЛЕМЕНТОВ ПЛЕЕРА (ВЕРТИКАЛЬНЫЙ)")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .tracking(1.2)
                            .foregroundColor(palette.textTertiary)
                        Spacer()
                        Button(action: {
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                                playerLayoutOrderString = "meta|visualizer|controls"
                            }
                        }) {
                            Text("Сбросить порядок")
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .foregroundColor(palette.accent)
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 8) {
                        ForEach(playerLayoutOrder, id: \.self) { block in
                            let idx = playerLayoutOrder.firstIndex(of: block) ?? 0

                            VStack(spacing: 5) {
                                HStack(spacing: 5) {
                                    Image(systemName: block.icon)
                                        .font(.system(size: 11))
                                        .foregroundColor(palette.accent)
                                    Text(block.displayName.uppercased())
                                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                                        .foregroundColor(palette.textPrimary)
                                        .lineLimit(1)
                                }
                                .frame(height: 18)

                                HStack(spacing: 8) {
                                    Button(action: { movePlayerBlockUp(block) }) {
                                        Image(systemName: "arrow.up")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(idx > 0 ? palette.textPrimary : palette.textTertiary)
                                            .frame(width: 18, height: 18)
                                            .background(Circle().fill(idx > 0 ? palette.card : Color.clear))
                                            .overlay(Circle().stroke(idx > 0 ? palette.stroke : Color.clear, lineWidth: 0.8))
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(idx == 0)

                                    Button(action: { movePlayerBlockDown(block) }) {
                                        Image(systemName: "arrow.down")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(idx < playerLayoutOrder.count - 1 ? palette.textPrimary : palette.textTertiary)
                                            .frame(width: 18, height: 18)
                                            .background(Circle().fill(idx < playerLayoutOrder.count - 1 ? palette.card : Color.clear))
                                            .overlay(Circle().stroke(idx < playerLayoutOrder.count - 1 ? palette.stroke : Color.clear, lineWidth: 0.8))
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(idx == playerLayoutOrder.count - 1)
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 8)
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(palette.inset))
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(palette.stroke, lineWidth: 0.8))
                        }
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(palette.card.opacity(0.15)))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(palette.stroke, lineWidth: 0.8))
                
                if themeManager.theme == .custom {
                    grandInteractivePreview
                        .padding(.bottom, 4)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("ЦВЕТА КАСТОМНОЙ ТЕМЫ")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .foregroundColor(palette.textTertiary)
                        
                        VStack(spacing: 10) {
                            HStack(spacing: 10) {
                                ColorPicker("Акцент", selection: colorBinding(for: $customAccent, key: "customAccent"))
                                    .onHover { h in hoveredColorKey = h ? "accent" : nil }
                                Spacer()
                                ColorPicker("Цвет фона", selection: colorBinding(for: $customAppTint, key: "customAppTint"))
                                    .onHover { h in hoveredColorKey = h ? "appTint" : nil }
                            }
                            HStack(spacing: 10) {
                                ColorPicker("Сайдбар", selection: colorBinding(for: $customSidebar, key: "customSidebar"))
                                    .onHover { h in hoveredColorKey = h ? "sidebar" : nil }
                                Spacer()
                                ColorPicker("Карты", selection: colorBinding(for: $customCard, key: "customCard"))
                                    .onHover { h in hoveredColorKey = h ? "card" : nil }
                            }
                            HStack(spacing: 10) {
                                ColorPicker("Текст", selection: colorBinding(for: $customTextPrimary, key: "customTextPrimary"))
                                    .onHover { h in hoveredColorKey = h ? "text" : nil }
                                Spacer()
                                ColorPicker("Прогресс", selection: colorBinding(for: $customProgress, key: "customProgress"))
                                    .onHover { h in hoveredColorKey = h ? "progress" : nil }
                            }
                            HStack(spacing: 10) {
                                ColorPicker("Свечение", selection: colorBinding(for: $customGlow, key: "customGlow"))
                                    .onHover { h in hoveredColorKey = h ? "glow" : nil }
                                Spacer()
                            }
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(palette.textSecondary)
                        
                        HStack(spacing: 10) {
                            Button(action: {
                                UserDefaults.standard.set(customAccent, forKey: "customAccent")
                                UserDefaults.standard.set(customSidebar, forKey: "customSidebar")
                                UserDefaults.standard.set(customAppTint, forKey: "customAppTint")
                                UserDefaults.standard.set(customCard, forKey: "customCard")
                                UserDefaults.standard.set(customTextPrimary, forKey: "customTextPrimary")
                                UserDefaults.standard.set(customProgress, forKey: "customProgress")
                                UserDefaults.standard.set(customGlow, forKey: "customGlow")
                                
                                UserDefaults.standard.set(notchBackgroundStyle, forKey: "notchBackgroundStyle")
                                UserDefaults.standard.set(notchCustomColor, forKey: "notchCustomColor")
                                UserDefaults.standard.set(notchParticlesEnabled, forKey: "notchParticlesEnabled")
                                UserDefaults.standard.set(notchVisualizerEnabled, forKey: "notchVisualizerEnabled")
                                UserDefaults.standard.set(notchVisualizerColor, forKey: "notchVisualizerColor")
                                
                                UserDefaults.standard.synchronize()
                                themeManager.forceRefresh()
                                NotificationCenter.default.post(name: .themeDidChange, object: themeManager.theme)
                                
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    showApplySuccess = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                    withAnimation {
                                        showApplySuccess = false
                                    }
                                }
                            }) {
                                HStack {
                                    Spacer()
                                    Image(systemName: showApplySuccess ? "checkmark.circle.fill" : "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                    Text(showApplySuccess ? "Применено! ✨" : "Применить изменения")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                    Spacer()
                                }
                                .foregroundColor(.white)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(showApplySuccess ? Color.green : palette.accent)
                                )
                                .shadow(color: (showApplySuccess ? Color.green : palette.accent).opacity(0.35), radius: 6, x: 0, y: 3)
                            }
                            .buttonStyle(.plain)

                            Button(action: { resetCustomColors() }) {
                                HStack {
                                    Spacer()
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 11, weight: .bold))
                                    Text("Сбросить")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                    Spacer()
                                }
                                .foregroundColor(palette.textPrimary)
                                .padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 8).fill(palette.card))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.stroke, lineWidth: 0.8))
                            }
                            .buttonStyle(.plain)
                            .frame(width: 100)
                        }
                        .padding(.top, 4)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(palette.inset))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(palette.stroke, lineWidth: 1))
                    
                    // Notch custom adjustments
                    VStack(alignment: .leading, spacing: 10) {
                        Text("КАСТОМИЗАЦИЯ NOTCH-ПЛЕЕРА")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .foregroundColor(palette.textTertiary)
                        
                        Toggle("Свечение и частицы в Notch", isOn: $notchParticlesEnabled)
                            .font(.system(size: 11, weight: .medium))
                            .toggleStyle(.checkbox)
                            .onHover { h in hoveredNotchKey = h ? "particles" : nil }
                        
                        Toggle("Включить Notch визуализатор", isOn: $notchVisualizerEnabled)
                            .font(.system(size: 11, weight: .medium))
                            .toggleStyle(.checkbox)
                            .onHover { h in hoveredNotchKey = h ? "visualizer" : nil }
                        
                        if notchVisualizerEnabled {
                            ColorPicker("Цвет визуализатора в Notch", selection: colorBinding(for: $notchVisualizerColor, key: "notchVisualizerColor"))
                                .font(.system(size: 11, weight: .medium))
                                .onHover { h in hoveredNotchKey = h ? "visualizer" : nil }
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Стиль заднего фона Notch")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(palette.textSecondary)
                            
                            Picker("", selection: $notchBackgroundStyle) {
                                Text("Матовый").tag(0)
                                Text("Однотонный").tag(1)
                                Text("Градиент").tag(2)
                            }
                            .pickerStyle(.segmented)
                        }
                        .onHover { h in hoveredNotchKey = h ? "background" : nil }
                        
                        if notchBackgroundStyle > 0 {
                            ColorPicker("Цвет заливки Notch", selection: colorBinding(for: $notchCustomColor, key: "notchCustomColor"))
                                .font(.system(size: 11, weight: .medium))
                                .onHover { h in hoveredNotchKey = h ? "fillColor" : nil }
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(palette.inset))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(palette.stroke, lineWidth: 1))
                }
            }
        }
        .frame(maxHeight: 520)
        .clipped()
    }

    @ViewBuilder
    private var grandPlayerPreview: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(alignment: .leading, spacing: 5) {
                // macOS traffic lights
                HStack(spacing: 4) {
                    Circle().fill(Color.red.opacity(0.85)).frame(width: 5, height: 5)
                    Circle().fill(Color.yellow.opacity(0.85)).frame(width: 5, height: 5)
                    Circle().fill(Color.green.opacity(0.85)).frame(width: 5, height: 5)
                }
                .padding(.bottom, 6)
                
                Text("БИБЛИОТЕКА")
                    .font(.system(size: 5, weight: .bold))
                    .foregroundColor(Color(hex: customTextPrimary).opacity(0.35))
                    .padding(.bottom, 2)
                
                ForEach(0..<4, id: \.self) { i in
                    HStack(spacing: 4) {
                        Image(systemName: i == 0 ? "heart.fill" : (i == 1 ? "music.note.list" : (i == 2 ? "waveform" : "folder")))
                            .font(.system(size: 6))
                            .foregroundColor(i == 0 ? Color(hex: customAccent) : Color(hex: customTextPrimary).opacity(0.4))
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color(hex: customTextPrimary).opacity(i == 0 ? 0.9 : 0.5))
                            .frame(width: i == 0 ? 30 : (i == 1 ? 24 : (i == 2 ? 34 : 20)), height: 3)
                    }
                    .padding(.vertical, 1)
                }
                
                Spacer()
                
                // SoundCloud / Spotify connected logos mockup
                HStack(spacing: 4) {
                    Circle().fill(Color.spotifyGreen).frame(width: 8, height: 8)
                    Circle().fill(Color.soundcloudOrange).frame(width: 8, height: 8)
                }
                .opacity(0.85)
            }
            .padding(6)
            .frame(width: 62)
            .frame(maxHeight: .infinity)
            .background(Color(hex: customSidebar))
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(palette.accent, lineWidth: hoveredColorKey == "sidebar" ? 1.2 : 0)
            )
            
            // Main Content Area
            VStack(spacing: 4) {
                // Top header / Drag Area
                HStack {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color(hex: customTextPrimary).opacity(0.2))
                        .frame(width: 40, height: 3)
                    Spacer()
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 8))
                        .foregroundColor(Color(hex: customTextPrimary).opacity(0.5))
                }
                .padding(.bottom, 2)
                
                // Centered large Album cover with Neon Glow
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(hex: customCard))
                        .frame(width: 38, height: 38)
                        .shadow(color: Color(hex: customGlow).opacity(0.7), radius: hoveredColorKey == "glow" ? 8 : 4)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: customAccent))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(palette.accent, lineWidth: hoveredColorKey == "glow" ? 1.5 : 0)
                        )
                }
                
                // Track details (centered text)
                VStack(spacing: 1) {
                    Text(viewModel.currentTrack?.title ?? "Aesthetic Song")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(Color(hex: customTextPrimary))
                        .lineLimit(1)
                    Text(viewModel.currentTrack?.artist ?? "Artist Name")
                        .font(.system(size: 5, weight: .semibold))
                        .foregroundColor(Color(hex: customTextPrimary).opacity(0.6))
                        .lineLimit(1)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(palette.accent, lineWidth: hoveredColorKey == "text" ? 1.2 : 0)
                        .padding(-2)
                )
                
                Spacer(minLength: 0)
                
                // Bottom Player Controls Section (Timeline + Buttons + Vol)
                VStack(spacing: 3) {
                    // Micro visualizer or volume row
                    HStack {
                        // Visualizer
                        HStack(alignment: .bottom, spacing: 1) {
                            ForEach(0..<6, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 0.5)
                                    .fill(Color(hex: customAccent).opacity(0.8))
                                    .frame(width: 1.5, height: CGFloat([6, 12, 8, 10, 5, 9][i % 6]) * 0.5)
                            }
                        }
                        
                        Spacer()
                        
                        // Volume slider mockup
                        HStack(spacing: 2) {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 5))
                                .foregroundColor(Color(hex: customTextPrimary).opacity(0.5))
                            RoundedRectangle(cornerRadius: 0.5)
                                .fill(Color(hex: customTextPrimary).opacity(0.8))
                                .frame(width: 25, height: 2)
                        }
                    }
                    
                    // Timeline
                    HStack(spacing: 3) {
                        Text("1:24")
                            .font(.system(size: 5, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(hex: customTextPrimary).opacity(0.4))
                        
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(hex: customTextPrimary).opacity(0.15))
                                .frame(height: 2)
                            Capsule()
                                .fill(Color(hex: customProgress))
                                .frame(width: 48, height: 2)
                            Circle()
                                .fill(Color(hex: customTextPrimary))
                                .frame(width: 4, height: 4)
                                .offset(x: 46)
                        }
                        
                        Text("3:45")
                            .font(.system(size: 5, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(hex: customTextPrimary).opacity(0.4))
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(palette.accent, lineWidth: hoveredColorKey == "progress" ? 1.2 : 0)
                            .padding(-2)
                    )
                    
                    // Primary controls row
                    HStack(spacing: 6) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 5))
                            .foregroundColor(viewModel.isShuffle ? Color(hex: customAccent) : Color(hex: customTextPrimary).opacity(0.4))
                        
                        Button(action: { viewModel.prevTrack() }) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 6))
                                .foregroundColor(Color(hex: customTextPrimary).opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { viewModel.togglePlayPause() }) {
                            Circle()
                                .fill(Color(hex: customAccent))
                                .frame(width: 14, height: 14)
                                .overlay(
                                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 6))
                                        .foregroundColor(palette.playIconColor)
                                        .offset(x: viewModel.isPlaying ? 0 : 0.5)
                                )
                        }
                        .buttonStyle(.plain)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: hoveredColorKey == "accent" ? 1.0 : 0)
                        )
                        
                        Button(action: { viewModel.nextTrack() }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 6))
                                .foregroundColor(Color(hex: customTextPrimary).opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        
                        Image(systemName: "repeat")
                            .font(.system(size: 5))
                            .foregroundColor(viewModel.isRepeat ? Color(hex: customAccent) : Color(hex: customTextPrimary).opacity(0.4))
                    }
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: customAppTint).opacity(0.85))
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(palette.accent, lineWidth: hoveredColorKey == "appTint" ? 1.2 : 0)
            )
        }
        .frame(height: 110)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.stroke, lineWidth: 1))
        .shadow(color: Color(hex: customAppTint).opacity(0.3), radius: 6)
    }

    @ViewBuilder
    private var grandNotchPreview: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                // Top screen menu bar simulation
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "applelogo")
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.9))
                        Text("Файл")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                        Text("Правка")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                        Image(systemName: "wifi")
                            .font(.system(size: 7))
                            .foregroundColor(.white.opacity(0.8))
                        Text("100%")
                            .font(.system(size: 6, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                        Text("15:46")
                            .font(.system(size: 6, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.4))
                    
                    Spacer()
                }
                .frame(height: 110)
                .background(Color(hex: customAppTint).opacity(0.95))
                
                // Visualizer hanging under the Notch
                if notchVisualizerEnabled {
                    HStack(alignment: .top, spacing: 2) {
                        ForEach(0..<25, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 0.5)
                                .fill(Color(hex: notchVisualizerColor))
                                .frame(width: 1.5, height: CGFloat([6, 12, 8, 14, 18, 10, 16, 7, 13, 9, 15, 11, 8, 5, 10, 14, 8, 12, 17, 9, 6, 11, 15, 7, 4][i % 25]) * 0.9)
                        }
                    }
                    .offset(y: 14)
                    .opacity(0.9)
                    .overlay(
                        Rectangle()
                            .stroke(palette.accent, lineWidth: hoveredNotchKey == "visualizer" ? 1.2 : 0)
                            .padding(-4)
                    )
                }
                
                // Floating cosmic particles
                if notchParticlesEnabled {
                    ZStack {
                        Circle().fill(Color(hex: customAccent).opacity(hoveredNotchKey == "particles" ? 0.95 : 0.6))
                            .frame(width: 3, height: 3)
                            .offset(x: -85, y: 22)
                        Circle().fill(Color(hex: customAccent).opacity(hoveredNotchKey == "particles" ? 0.95 : 0.4))
                            .frame(width: 4, height: 4)
                            .offset(x: -55, y: 34)
                        Circle().fill(Color(hex: customAccent).opacity(hoveredNotchKey == "particles" ? 0.95 : 0.7))
                            .frame(width: 2.5, height: 2.5)
                            .offset(x: 50, y: 28)
                        Circle().fill(Color(hex: customAccent).opacity(hoveredNotchKey == "particles" ? 0.95 : 0.5))
                            .frame(width: 3.5, height: 3.5)
                            .offset(x: 80, y: 32)
                        Circle().fill(Color(hex: customAccent).opacity(hoveredNotchKey == "particles" ? 0.95 : 0.8))
                            .frame(width: 2, height: 2)
                            .offset(x: -20, y: 40)
                    }
                    .shadow(color: Color(hex: customAccent).opacity(0.3), radius: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(palette.accent, lineWidth: hoveredNotchKey == "particles" ? 1.2 : 0)
                            .frame(width: 220, height: 50)
                            .offset(y: 15)
                    )
                }
                
                // Physical screen notch bezel representation
                NotchSimulatedShape()
                    .fill(notchFillStyle)
                    .frame(width: 140, height: 16)
                    .shadow(color: Color(hex: customGlow).opacity(notchParticlesEnabled ? 0.4 : 0), radius: 4, x: 0, y: 2)
                    .overlay(
                        NotchSimulatedShape()
                            .stroke(palette.accent, lineWidth: (hoveredNotchKey == "background" || hoveredNotchKey == "fillColor") ? 1.5 : 0)
                    )
                
                // Expanded Notch Mini Player Window hanging down
                VStack(spacing: 0) {
                    Spacer().frame(height: 16)
                    
                    VStack(spacing: 6) {
                        // Brand Header Row (Logo + Aferapokitaysky + Shuffle/Repeat icons)
                        HStack(spacing: 4) {
                            Circle().fill(Color(hex: customAccent)).frame(width: 6, height: 6)
                            Text("Aferapokitaysky")
                                .font(.system(size: 8, weight: .heavy, design: .rounded))
                                .foregroundColor(Color(hex: customTextPrimary))
                            Spacer()
                            if viewModel.isShuffle {
                                Image(systemName: "shuffle")
                                    .font(.system(size: 6, weight: .bold))
                                    .foregroundColor(Color(hex: customAccent))
                            }
                            if viewModel.isRepeat {
                                Image(systemName: "repeat")
                                    .font(.system(size: 6, weight: .bold))
                                    .foregroundColor(Color(hex: customAccent))
                            }
                        }
                        .opacity(0.85)
                        
                        // Middle Row: Cover, Info, Controls, Volume
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(hex: customCard))
                                .frame(width: 26, height: 26)
                                .shadow(color: Color(hex: customGlow).opacity(0.5), radius: 3)
                                .overlay(
                                    Image(systemName: "music.note")
                                        .font(.system(size: 10))
                                        .foregroundColor(Color(hex: customAccent))
                                )
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text(viewModel.currentTrack?.title ?? "Aesthetic Song")
                                    .font(.system(size: 7, weight: .heavy, design: .rounded))
                                    .foregroundColor(Color(hex: customTextPrimary))
                                    .lineLimit(1)
                                Text(viewModel.currentTrack?.artist ?? "SoundCloud Artist")
                                    .font(.system(size: 5, weight: .semibold, design: .rounded))
                                    .foregroundColor(Color(hex: customTextPrimary).opacity(0.6))
                                    .lineLimit(1)
                            }
                            .frame(width: 60, alignment: .leading)
                            
                            Spacer(minLength: 0)
                            
                            HStack(spacing: 4) {
                                Button(action: { viewModel.prevTrack() }) {
                                    Image(systemName: "backward.fill")
                                        .font(.system(size: 6))
                                        .foregroundColor(Color(hex: customTextPrimary).opacity(0.6))
                                        .frame(width: 12, height: 12)
                                        .background(Circle().fill(Color(hex: customCard)))
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: { viewModel.togglePlayPause() }) {
                                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 7, weight: .black))
                                        .foregroundColor(palette.pauseIconColor)
                                        .frame(width: 14, height: 14)
                                        .background(Circle().fill(Color(hex: customTextPrimary)))
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: { viewModel.nextTrack() }) {
                                    Image(systemName: "forward.fill")
                                        .font(.system(size: 6))
                                        .foregroundColor(Color(hex: customTextPrimary).opacity(0.6))
                                        .frame(width: 12, height: 12)
                                        .background(Circle().fill(Color(hex: customCard)))
                                }
                                .buttonStyle(.plain)
                            }
                            
                            HStack(spacing: 2) {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 5))
                                    .foregroundColor(Color(hex: customTextPrimary).opacity(0.5))
                                RoundedRectangle(cornerRadius: 0.5)
                                    .fill(Color(hex: customAccent))
                                    .frame(width: 20, height: 2)
                            }
                        }
                        
                        // Bottom row: timeline progress bar
                        HStack(spacing: 3) {
                            Text("1:24")
                                .font(.system(size: 5, weight: .medium, design: .monospaced))
                                .foregroundColor(Color(hex: customTextPrimary).opacity(0.4))
                            
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color(hex: customTextPrimary).opacity(0.15))
                                    .frame(height: 2)
                                Capsule()
                                    .fill(Color(hex: customProgress))
                                    .frame(width: 110, height: 2)
                            }
                            
                            Text("-2:21")
                                .font(.system(size: 5, weight: .medium, design: .monospaced))
                                .foregroundColor(Color(hex: customTextPrimary).opacity(0.4))
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .frame(width: 290, height: 62)
                    .background(
                        CustomRoundedCorner(
                            topLeft: 0, topRight: 0,
                            bottomLeft: 12, bottomRight: 12
                        )
                        .fill(notchFillStyle)
                    )
                    .overlay(
                        CustomRoundedCorner(
                            topLeft: 0, topRight: 0,
                            bottomLeft: 12, bottomRight: 12
                        )
                        .stroke(palette.stroke, lineWidth: 0.8)
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 6, y: 3)
                }
            }
            .frame(height: 110)
            .cornerRadius(8)
            .clipped()
        }
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.stroke, lineWidth: 1))
    }

    @ViewBuilder
    private var grandInteractivePreview: some View {
        VStack(spacing: 8) {
            HStack {
                Text("ИНТЕРАКТИВНЫЙ СИМУЛЯТОР")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundColor(palette.textTertiary)
                
                Spacer()
                
                HStack(spacing: 0) {
                    Button(action: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                            previewMode = 0
                        }
                    }) {
                        Text("ПЛЕЕР")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(previewMode == 0 ? palette.accent : Color.clear)
                            .foregroundColor(previewMode == 0 ? .white : palette.textSecondary)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                            previewMode = 1
                        }
                    }) {
                        Text("NOTCH")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(previewMode == 1 ? palette.accent : Color.clear)
                            .foregroundColor(previewMode == 1 ? .white : palette.textSecondary)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(2)
                .background(RoundedRectangle(cornerRadius: 6).fill(palette.inset))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(palette.stroke, lineWidth: 0.8))
            }
            
            if previewMode == 0 {
                grandPlayerPreview
            } else {
                grandNotchPreview
            }
            
            Text(previewMode == 0 ? descriptionForHoveredKey() : descriptionForHoveredNotchKey())
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor((previewMode == 0 ? hoveredColorKey != nil : hoveredNotchKey != nil) ? palette.accent : palette.textTertiary)
                .multilineTextAlignment(.center)
                .frame(height: 22)
                .frame(maxWidth: .infinity)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10).fill(palette.inset))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(palette.stroke, lineWidth: 0.8))
    }

    private func descriptionForHoveredKey() -> String {
        guard let key = hoveredColorKey else {
            return "(Наведите курсор на цвет для подсказки)"
        }
        switch key {
        case "accent":
            return "[АКЦЕНТ] — Кнопки управления и индикаторы"
        case "appTint":
            return "[ФОН] — Цвет заднего амбиентного свечения"
        case "sidebar":
            return "[САЙДБАР] — Левые списки альбомов и треков"
        case "card":
            return "[КАРТЫ] — Подложка кнопок и элементов списка"
        case "text":
            return "[ТЕКСТ] — Подписи, названия и меню"
        case "progress":
            return "[ПРОГРЕСС] — Бегущая полоса воспроизведения"
        case "glow":
            return "[СВЕЧЕНИЕ] — Неоновый нимб обложки"
        default:
            return ""
        }
    }

    private func resetCustomColors() {
        customAccent = "#FF5500"
        customSidebar = "#111111"
        customAppTint = "#000000"
        customCard = "#222222"
        customTextPrimary = "#FFFFFF"
        customProgress = "#FF5500"
        customGlow = "#FF5500"
        
        UserDefaults.standard.set("#FF5500", forKey: "customAccent")
        UserDefaults.standard.set("#111111", forKey: "customSidebar")
        UserDefaults.standard.set("#000000", forKey: "customAppTint")
        UserDefaults.standard.set("#222222", forKey: "customCard")
        UserDefaults.standard.set("#FFFFFF", forKey: "customTextPrimary")
        UserDefaults.standard.set("#FF5500", forKey: "customProgress")
        UserDefaults.standard.set("#FF5500", forKey: "customGlow")
        
        notchBackgroundStyle = 0
        notchCustomColor = "#000000"
        notchParticlesEnabled = true
        notchVisualizerEnabled = true
        notchVisualizerColor = "#FFFFFF"
        
        UserDefaults.standard.set(0, forKey: "notchBackgroundStyle")
        UserDefaults.standard.set("#000000", forKey: "notchCustomColor")
        UserDefaults.standard.set(true, forKey: "notchParticlesEnabled")
        UserDefaults.standard.set(true, forKey: "notchVisualizerEnabled")
        UserDefaults.standard.set("#FFFFFF", forKey: "notchVisualizerColor")
        
        UserDefaults.standard.synchronize()
        
        themeManager.forceRefresh()
        NotificationCenter.default.post(name: .themeDidChange, object: themeManager.theme)
    }

    private var notchFillStyle: AnyShapeStyle {
        if notchBackgroundStyle == 0 {
            return AnyShapeStyle(Color.black.opacity(0.8))
        } else if notchBackgroundStyle == 1 {
            return AnyShapeStyle(Color(hex: notchCustomColor))
        } else {
            return AnyShapeStyle(LinearGradient(
                colors: [Color(hex: notchCustomColor), Color(hex: notchCustomColor).opacity(0.6)],
                startPoint: .top, endPoint: .bottom
            ))
        }
    }

    private func descriptionForHoveredNotchKey() -> String {
        guard let key = hoveredNotchKey else {
            return "(Наведите на параметры для подсказки по Notch)"
        }
        switch key {
        case "particles":
            return "[ЧАСТИЦЫ] — Легкая космическая пыль вокруг Notch-плеера"
        case "visualizer":
            return "[ВИЗУАЛИЗАТОР] — Спектрограмма, огибающая нижнюю грань Notch"
        case "background":
            return "[СТИЛЬ ФОНА] — Внешний вид плашки (матовый, сплошной или градиент)"
        case "fillColor":
            return "[ЦВЕТ ЗАЛИВКИ] — Собственный оттенок корпуса Notch-плеера"
        default:
            return ""
        }
    }

    private var sidebarEmptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note.list")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(palette.textTertiary)
                .frame(width: 38, height: 38)
                .background(Circle().fill(palette.inset))
                .overlay(Circle().stroke(palette.stroke, lineWidth: 1))

            Text("Библиотека пуста")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var emptyTracksState: some View {
        VStack(spacing: 10) {
            Image(systemName: "waveform")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(palette.textTertiary)
                .frame(width: 52, height: 52)
                .background(Circle().fill(palette.inset))
                .overlay(Circle().stroke(palette.stroke, lineWidth: 1))

            Text("Треков пока нет")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
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
        let artSize: CGFloat = 220

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

// MARK: - Mechanical Keycap Badge View
struct KeycapView: View {
    let key: String
    let label: String
    let palette: Palette
    
    var body: some View {
        HStack(spacing: 5) {
            Text(key)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .padding(.horizontal, 5)
                .padding(.vertical, 2.5)
                .foregroundColor(palette.textPrimary)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(palette.inset)
                        .shadow(color: Color.black.opacity(0.25), radius: 1, x: 0, y: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(palette.stroke, lineWidth: 1)
                )
            
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(palette.textSecondary)
        }
    }
}

// MARK: - Premium Spotlight Track Row
struct SpotlightTrackRow: View {
    let track: Track
    let album: Album
    @ObservedObject var viewModel: PlayerViewModel
    let brandColor: Color
    @EnvironmentObject var themeManager: ThemeManager

    @State private var isHovered = false
    @State private var isPlayHovered = false
    @State private var isAddHovered = false
    @State private var isMenuHovered = false

    private var palette: Palette { themeManager.theme.palette }

    var body: some View {
        let isActive = viewModel.currentTrack == track
        let isPlayingThis = isActive && viewModel.isPlaying
        let isAdded = viewModel.searchTargetPlaylist?.tracks.contains(where: { $0.id == track.id }) == true

        return HStack(spacing: 12) {
            // 1. Explicit Play/Pause Button
            Button(action: {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.70)) {
                    if isPlayingThis {
                        viewModel.pause()
                    } else {
                        viewModel.addTrackToSearchHistory(track)
                        viewModel.playTrack(track, in: album)
                    }
                }
            }) {
                ZStack {
                    Circle()
                        .fill(isPlayingThis ? brandColor.opacity(0.15) : palette.inset.opacity(0.8))
                        .frame(width: 26, height: 26)
                    
                    Image(systemName: isPlayingThis ? "pause.fill" : "play.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(isPlayingThis ? brandColor : (isPlayHovered ? brandColor : palette.textSecondary))
                }
                .overlay(
                    Circle()
                        .stroke(isPlayingThis ? brandColor : (isPlayHovered ? brandColor.opacity(0.5) : palette.stroke), lineWidth: 1)
                )
                .scaleEffect(isPlayHovered ? 1.12 : 1.0)
                .shadow(color: isPlayHovered ? brandColor.opacity(0.2) : .clear, radius: 4)
            }
            .buttonStyle(.plain)
            .onHover { isPlayHovered = $0 }
            .help(isPlayingThis ? "Пауза" : "Играть трек")

            // 2. Album Artwork
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(palette.inset)
                    .frame(width: 34, height: 34)

                if let url = track.albumArtUrl, url.hasPrefix("http"), let u = URL(string: url) {
                    AsyncImage(url: u) { phase in
                        switch phase {
                        case .success(let image): image.resizable().aspectRatio(contentMode: .fill)
                        default: Image(systemName: "music.note").foregroundColor(palette.textTertiary)
                        }
                    }
                    .frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                } else {
                    Image(systemName: track.albumArtUrl ?? "music.note")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(palette.textTertiary)
                }

                if isActive && isPlayingThis {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.black.opacity(0.4))
                        .frame(width: 34, height: 34)
                    activeBars
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(palette.stroke, lineWidth: 1))
            .scaleEffect(isHovered ? 1.04 : 1.0)

            // 3. Track Info (Title, Artist)
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(isActive ? brandColor : palette.textPrimary)
                    .lineLimit(1)
                
                Text(track.artist)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(palette.textTertiary)
                    .lineLimit(1)
            }
            .offset(x: isHovered ? 4 : 0)

            Spacer()

            // 4. Explicit Add/Checked Button + Playlist Menu
            HStack(spacing: 8) {
                if isAdded {
                    // Glowing Confirmation Checkmark
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(Color.green)
                        .shadow(color: Color.green.opacity(0.4), radius: 6, x: 0, y: 0)
                        .scaleEffect(1.08)
                        .transition(.scale.combined(with: .opacity))
                        .help("Уже добавлено")
                } else {
                    // Pulsing Plus Button
                    Button(action: {
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.72)) {
                            viewModel.addTrackToSearchTargetPlaylist(track)
                        }
                    }) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 15))
                            .foregroundColor(isAddHovered ? brandColor : palette.textSecondary)
                            .scaleEffect(isAddHovered ? 1.15 : 1.0)
                            .shadow(color: isAddHovered ? brandColor.opacity(0.25) : .clear, radius: 4)
                    }
                    .buttonStyle(.plain)
                    .onHover { isAddHovered = $0 }
                    .transition(.scale.combined(with: .opacity))
                    .help("Добавить в выбранный плейлист")
                }

                // Ellipsis context menu button for custom playlists
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
                                Label("Добавить в «\(pl.name)»", systemImage: "music.note.list")
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
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(isMenuHovered ? palette.textPrimary : palette.textTertiary)
                        .rotationEffect(.degrees(90))
                        .frame(width: 22, height: 22)
                        .background(isMenuHovered ? palette.inset.opacity(0.5) : Color.clear)
                        .clipShape(Circle())
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .onHover { isMenuHovered = $0 }
                .help("Добавить в другой плейлист...")
            }

            // 5. Duration
            Text(formatDuration(track.duration))
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(isActive ? brandColor.opacity(0.85) : palette.textTertiary)
                .frame(width: 32, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isActive ? brandColor.opacity(0.10) : (isHovered ? palette.inset.opacity(0.4) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isActive ? brandColor.opacity(0.5) : (isHovered ? brandColor.opacity(0.20) : Color.clear), lineWidth: 1.2)
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .onHover { hovering in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.72)) {
                isHovered = hovering
            }
        }
    }

    private var activeBars: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2) {
                ForEach(0..<3) { i in
                    let phase = sin(t * 6.0 + Double(i) * 1.3)
                    let h = CGFloat(5.0 + (phase + 1.0) * 3.5)
                    RoundedRectangle(cornerRadius: 1).fill(brandColor)
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

// MARK: - Customizable Layout Blocks Enum
enum LayoutBlock: String, CaseIterable {
    case albums = "albums"
    case tracks = "tracks"
    case player = "player"
    
    var displayName: String {
        switch self {
        case .albums: return "Альбомы"
        case .tracks: return "Треки"
        case .player: return "Плеер"
        }
    }
    
    var icon: String {
        switch self {
        case .albums: return "music.note.list"
        case .tracks: return "waveform"
        case .player: return "play.circle.fill"
        }
    }
}

// MARK: - Customizable Player Blocks Enum
enum PlayerBlock: String, CaseIterable {
    case meta = "meta"
    case visualizer = "visualizer"
    case controls = "controls"
    
    var displayName: String {
        switch self {
        case .meta: return "Инфо"
        case .visualizer: return "Спектр"
        case .controls: return "Пульт"
        }
    }
    
    var icon: String {
        switch self {
        case .meta: return "music.note"
        case .visualizer: return "waveform.and.waveform"
        case .controls: return "play.circle.fill"
        }
    }
}

