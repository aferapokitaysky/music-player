import SwiftUI

struct MainView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showSettings = false
    @State private var isHoveringControls = false
    @State private var isWindowKey = true

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
                    .frame(width: 280)
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
                AestheticLogoView(size: 28, color: palette.textPrimary)
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
                }
                .padding(.horizontal, 14)
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
                            TrackRowView(track: track, album: album, viewModel: viewModel)
                                .environmentObject(themeManager)
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




