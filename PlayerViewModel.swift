import Foundation
import AVFoundation
import Combine

struct Track: Identifiable, Equatable, Hashable, Codable {
    let id: String
    let title: String
    let artist: String
    let albumArtUrl: String?
    let audioUrl: String
    let duration: Double // in seconds
}

enum AlbumKind: String, Codable {
    case demo, uploads, likes, playlist, custom, spotify
}

struct Album: Identifiable, Equatable, Codable {
    let id: String
    var name: String
    var kind: AlbumKind
    var artworkUrl: String?
    var tracks: [Track]
}

@MainActor
class PlayerViewModel: ObservableObject {
    // Playback State
    @Published var isPlaying = false
    @Published var currentTime: Double = 0.0
    @Published var volume: Double = 0.8 {
        didSet {
            player.volume = Float(volume)
        }
    }
    @Published var currentTrack: Track?
    @Published var albums: [Album] = []
    @Published var selectedAlbumId: String? = nil   // currently shown in middle column
    @Published var playingAlbumId: String? = nil    // album the player is iterating
    @Published var isShuffle = false
    @Published var isRepeat = false

    // UI state
    @Published var sidebarCollapsed = false

    // Services / Inputs
    @Published var spotifyToken = ""
    @Published var soundCloudUrl = ""
    @Published var soundCloudOAuth = ""   // optional user-supplied OAuth token (for private content)
    @Published var connectionStatus = ""
    @Published var isConnecting = false

    // Computed: the queue used by next/prev
    var playlist: [Track] {
        if let id = playingAlbumId, let a = albums.first(where: { $0.id == id }) { return a.tracks }
        if let id = selectedAlbumId, let a = albums.first(where: { $0.id == id }) { return a.tracks }
        return albums.first?.tracks ?? []
    }
    var selectedAlbum: Album? {
        albums.first(where: { $0.id == selectedAlbumId }) ?? albums.first
    }
    
    // Visualizer State
    @Published var visualizerBars: [Double] = Array(repeating: 0.0, count: 28)
    private var targetBars: [Double] = Array(repeating: 0.0, count: 28)
    private var velocities: [Double] = Array(repeating: 0.0, count: 28)
    
    // Internal Player
    private var player = AVPlayer()
    private var timeObserver: Any?
    private var visualizerTimer: Timer?
    private var beatCounter = 0.0
    
    // Preloaded Demo Tracks
    private let demoTracks = [
        Track(
            id: "demo1",
            title: "Midnight Drive",
            artist: "Synthwave Horizon",
            albumArtUrl: "sparkles", // SF Symbol name
            audioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3",
            duration: 372.0
        ),
        Track(
            id: "demo2",
            title: "Chill Cafe Lo-Fi",
            artist: "Bedtime Beatmaker",
            albumArtUrl: "cup.and.saucer.fill",
            audioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3",
            duration: 344.0
        ),
        Track(
            id: "demo3",
            title: "Neon Reflections",
            artist: "Retro-Future",
            albumArtUrl: "play.house.fill",
            audioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3",
            duration: 302.0
        ),
        Track(
            id: "demo4",
            title: "Rainy Sunset",
            artist: "Lofi Library",
            albumArtUrl: "cloud.rain.fill",
            audioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3",
            duration: 318.0
        )
    ]
    
    init() {
        // Restore OAuth from Keychain if present
        if let saved = Keychain.load(account: "soundcloud_oauth") {
            self.soundCloudOAuth = saved
        }

        // Try to load cached library; fall back to demo album
        let cached = LibraryStore.load()
        if !cached.isEmpty {
            self.albums = cached
        } else {
            let demo = Album(id: "demo", name: "Demo", kind: .demo, artworkUrl: nil, tracks: demoTracks)
            self.albums = [demo]
        }
        self.selectedAlbumId = self.albums.first?.id
        self.playingAlbumId = self.selectedAlbumId
        self.currentTrack = self.albums.first?.tracks.first

        setupAudioSession()
        setupVisualizerTimer()
        setupTimeObserver()

        // Notify player of initial volume
        player.volume = Float(volume)
    }

    // Persist when needed
    func persistLibrary() { LibraryStore.save(albums) }
    func persistOAuth() {
        let trimmed = soundCloudOAuth.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            Keychain.remove(account: "soundcloud_oauth")
        } else {
            Keychain.save(trimmed, account: "soundcloud_oauth")
        }
    }
    func clearLibrary() {
        let demo = Album(id: "demo", name: "Demo", kind: .demo, artworkUrl: nil, tracks: demoTracks)
        albums = [demo]
        selectedAlbumId = demo.id
        playingAlbumId = demo.id
        currentTrack = demo.tracks.first
        persistLibrary()
    }
    
    deinit {
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
        }
        visualizerTimer?.invalidate()
    }
    
    private func setupAudioSession() {
        // Allow AVPlayer to play audio in the background on macOS
        // (Typically managed automatically, but good practice to initialize)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
    }
    
    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.25, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            Task { @MainActor in
                guard self.isPlaying else { return }
                self.currentTime = time.seconds
            }
        }
    }
    
    @objc private func playerDidFinishPlaying() {
        nextTrack()
    }
    
    // MARK: - Playback Controls
    
    func playTrack(_ track: Track, in album: Album? = nil) {
        guard let url = URL(string: track.audioUrl) else { return }

        // Anchor the playback queue to whatever album the user clicked from
        if let album = album {
            playingAlbumId = album.id
        } else if let containing = albums.first(where: { $0.tracks.contains(track) }) {
            playingAlbumId = containing.id
        }

        let currentVol = player.volume
        currentTrack = track
        currentTime = 0.0

        let playerItem = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: playerItem)
        player.volume = currentVol

        play()
    }
    
    func play() {
        player.play()
        isPlaying = true
    }
    
    func pause() {
        player.pause()
        isPlaying = false
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func seek(to seconds: Double) {
        let targetTime = CMTime(seconds: seconds, preferredTimescale: 1000)
        player.seek(to: targetTime) { [weak self] completed in
            guard let self = self else { return }
            if completed {
                Task { @MainActor in
                    self.currentTime = seconds
                }
            }
        }
    }
    
    func nextTrack() {
        guard let current = currentTrack, let index = playlist.firstIndex(of: current) else { return }
        
        if isRepeat {
            seek(to: 0)
            play()
            return
        }
        
        let nextIndex: Int
        if isShuffle {
            nextIndex = Int.random(in: 0..<playlist.count)
        } else {
            nextIndex = (index + 1) % playlist.count
        }
        
        playTrack(playlist[nextIndex])
    }
    
    func prevTrack() {
        guard let current = currentTrack, let index = playlist.firstIndex(of: current) else { return }
        
        let prevIndex = (index - 1 + playlist.count) % playlist.count
        playTrack(playlist[prevIndex])
    }
    
    func toggleShuffle() {
        isShuffle.toggle()
    }
    
    func toggleRepeat() {
        isRepeat.toggle()
    }
    
    // MARK: - Spotify & SoundCloud Connections
    
    func connectSpotify() async {
        guard !spotifyToken.isEmpty else {
            connectionStatus = "Введите токен!"
            return
        }
        
        isConnecting = true
        connectionStatus = "Подключение к Spotify..."
        
        var request = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/playlists?limit=10")!)
        request.setValue("Bearer \(spotifyToken)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            
            if httpResponse.statusCode == 200 {
                // Parse Spotify Playlists
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let items = json["items"] as? [[String: Any]] {
                    
                    var fetchedTracks: [Track] = []
                    
                    // Fetch tracks for the first playlist
                    if let firstPlaylist = items.first,
                       let tracksObj = firstPlaylist["tracks"] as? [String: Any],
                       let tracksUrlStr = tracksObj["href"] as? String,
                       let tracksUrl = URL(string: tracksUrlStr) {
                        
                        var tracksRequest = URLRequest(url: tracksUrl)
                        tracksRequest.setValue("Bearer \(spotifyToken)", forHTTPHeaderField: "Authorization")
                        
                        let (tracksData, _) = try await URLSession.shared.data(for: tracksRequest)
                        if let tracksJson = try? JSONSerialization.jsonObject(with: tracksData) as? [String: Any],
                           let trackItems = tracksJson["items"] as? [[String: Any]] {
                            
                            for (index, item) in trackItems.enumerated() {
                                if let t = item["track"] as? [String: Any],
                                   let name = t["name"] as? String,
                                   let artists = t["artists"] as? [[String: Any]],
                                   let artistName = artists.first?["name"] as? String {
                                    
                                    // Spotify uses preview_url for playable 30-sec samples
                                    let previewUrl = t["preview_url"] as? String ?? ""
                                    let durationMs = t["duration_ms"] as? Double ?? 30000.0
                                    
                                    // Album art
                                    var artUrl: String?
                                    if let album = t["album"] as? [String: Any],
                                       let images = album["images"] as? [[String: Any]],
                                       let firstImage = images.first,
                                       let urlStr = firstImage["url"] as? String {
                                        artUrl = urlStr
                                    }
                                    
                                    // Only add playable preview tracks
                                    if !previewUrl.isEmpty {
                                        fetchedTracks.append(Track(
                                            id: "spotify_\(index)",
                                            title: name,
                                            artist: artistName,
                                            albumArtUrl: artUrl,
                                            audioUrl: previewUrl,
                                            duration: durationMs / 1000.0
                                        ))
                                    }
                                }
                            }
                        }
                    }
                    
                    if !fetchedTracks.isEmpty {
                        let album = Album(id: "spotify_main",
                                          name: "Spotify · Превью",
                                          kind: .spotify,
                                          artworkUrl: fetchedTracks.first?.albumArtUrl,
                                          tracks: fetchedTracks)
                        self.albums.removeAll { $0.kind == .spotify }
                        self.albums.append(album)
                        self.selectedAlbumId = album.id
                        self.playingAlbumId = album.id
                        self.currentTrack = fetchedTracks.first
                        self.persistLibrary()
                        self.connectionStatus = "Успешно подключен Spotify! \(fetchedTracks.count) превью-треков."
                    } else {
                        self.connectionStatus = "Плейлисты пустые или нет превью-треков."
                    }
                }
            } else {
                self.connectionStatus = "Ошибка API Spotify (Код: \(httpResponse.statusCode))"
            }
        } catch {
            self.connectionStatus = "Ошибка подключения: \(error.localizedDescription)"
        }
        
        isConnecting = false
    }
    
    func connectSoundCloud() async {
        // Tolerant URL normalization
        var raw = soundCloudUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        // Strip wrapping quotes
        raw = raw.trimmingCharacters(in: CharacterSet(charactersIn: "\"'`"))
        // Add scheme if missing
        if !raw.lowercased().hasPrefix("http://") && !raw.lowercased().hasPrefix("https://") {
            if raw.hasPrefix("soundcloud.com") || raw.hasPrefix("www.soundcloud.com") {
                raw = "https://" + raw
            } else if raw.hasPrefix("/") {
                raw = "https://soundcloud.com" + raw
            }
        }

        Self.log("=== connectSoundCloud start ===")
        Self.log("input URL: \(raw)")

        guard !raw.isEmpty, let pageURL = URL(string: raw),
              pageURL.host?.contains("soundcloud.com") == true else {
            connectionStatus = "Некорректная ссылка SoundCloud"
            Self.log("invalid URL after normalization: \(raw)")
            return
        }

        isConnecting = true
        connectionStatus = "Загрузка страницы SoundCloud..."

        let oauth = soundCloudOAuth.trimmingCharacters(in: .whitespacesAndNewlines)
        let oauthOpt: String? = oauth.isEmpty ? nil : oauth
        Self.log("oauth provided: \(oauthOpt != nil)  path: \(pageURL.path)")

        do {
            // 1. Download the public HTML page
            let html = try await Self.fetchString(url: pageURL)
            Self.log("fetched HTML \(html.count) chars")

            // 2. Extract a working client_id from one of the JS bundles
            connectionStatus = "Получение API ключа..."
            let clientId = try await Self.extractClientId(fromHTML: html)
            Self.log("client_id ok: \(clientId.prefix(6))…")

            // 3. Resolve the URL through SoundCloud API v2
            connectionStatus = oauthOpt == nil ? "Анализ ссылки..." : "Анализ ссылки (OAuth)..."
            guard var comps = URLComponents(string: "https://api-v2.soundcloud.com/resolve") else {
                throw NSError(domain: "SC", code: 0)
            }
            comps.queryItems = [
                URLQueryItem(name: "url", value: raw),
                URLQueryItem(name: "client_id", value: clientId)
            ]
            guard let resolveURL = comps.url else { throw NSError(domain: "SC", code: 1) }
            let resolveData = try await Self.fetchData(url: resolveURL, oauth: oauthOpt)
            guard let resolved = try JSONSerialization.jsonObject(with: resolveData) as? [String: Any] else {
                throw NSError(domain: "SC", code: 2,
                              userInfo: [NSLocalizedDescriptionKey: "Невозможно разобрать ответ"])
            }
            let kind = resolved["kind"] as? String ?? ""
            Self.log("resolved kind=\(kind) id=\(resolved["id"] ?? "?")")

            // 4. Build albums depending on kind & path
            let path = pageURL.path.lowercased()
            var newAlbums: [Album] = []

            switch kind {
            case "user":
                guard let uid = resolved["id"] as? Int else { break }
                let userName = (resolved["username"] as? String) ?? "user"

                if path.hasSuffix("/likes") {
                    let entries = try await Self.fetchCollection(
                        urlString: "https://api-v2.soundcloud.com/users/\(uid)/track_likes",
                        clientId: clientId, oauth: oauthOpt
                    )
                    let tracks = await Self.buildTracks(from: Self.flattenLikes(entries),
                                                       clientId: clientId, oauth: oauthOpt) { idx, total in
                        await MainActor.run { self.connectionStatus = "Лайки \(idx)/\(total)" }
                    }
                    if !tracks.isEmpty {
                        newAlbums.append(Album(id: "sc_likes_\(uid)",
                                               name: "❤ Лайки · \(userName)",
                                               kind: .likes,
                                               artworkUrl: tracks.first?.albumArtUrl,
                                               tracks: tracks))
                    }

                } else if path.hasSuffix("/sets") || path.contains("/sets/") {
                    // /sets — list of playlists; /sets/<name> — single playlist (already in resolved)
                    var playlistJsons: [[String: Any]] = []
                    if path.contains("/sets/") {
                        playlistJsons = [resolved]
                    } else {
                        playlistJsons = try await Self.fetchCollection(
                            urlString: "https://api-v2.soundcloud.com/users/\(uid)/playlists",
                            clientId: clientId, oauth: oauthOpt
                        )
                    }
                    for (i, pl) in playlistJsons.enumerated() {
                        if let alb = await Self.makeAlbumFromPlaylist(
                            pl, ownerName: userName, clientId: clientId, oauth: oauthOpt,
                            progress: { idx, total, name in
                                await MainActor.run { self.connectionStatus = "\(name) \(idx)/\(total)" }
                            }), !alb.tracks.isEmpty {
                            newAlbums.append(alb)
                        }
                        await MainActor.run {
                            self.connectionStatus = "Плейлист \(i+1)/\(playlistJsons.count)"
                        }
                    }

                } else {
                    // Bare profile — uploads, likes, all playlists (each as its own album)
                    let uploadEntries = try await Self.fetchCollection(
                        urlString: "https://api-v2.soundcloud.com/users/\(uid)/tracks",
                        clientId: clientId, oauth: oauthOpt
                    )
                    let uploads = await Self.buildTracks(from: uploadEntries,
                                                         clientId: clientId, oauth: oauthOpt) { idx, total in
                        await MainActor.run { self.connectionStatus = "Uploads \(idx)/\(total)" }
                    }
                    if !uploads.isEmpty {
                        newAlbums.append(Album(id: "sc_uploads_\(uid)",
                                               name: "Загрузки · \(userName)",
                                               kind: .uploads,
                                               artworkUrl: uploads.first?.albumArtUrl,
                                               tracks: uploads))
                    }

                    let likeEntries = try await Self.fetchCollection(
                        urlString: "https://api-v2.soundcloud.com/users/\(uid)/track_likes",
                        clientId: clientId, oauth: oauthOpt
                    )
                    let likes = await Self.buildTracks(from: Self.flattenLikes(likeEntries),
                                                       clientId: clientId, oauth: oauthOpt) { idx, total in
                        await MainActor.run { self.connectionStatus = "Лайки \(idx)/\(total)" }
                    }
                    if !likes.isEmpty {
                        newAlbums.append(Album(id: "sc_likes_\(uid)",
                                               name: "❤ Лайки · \(userName)",
                                               kind: .likes,
                                               artworkUrl: likes.first?.albumArtUrl,
                                               tracks: likes))
                    }

                    let playlistJsons = try await Self.fetchCollection(
                        urlString: "https://api-v2.soundcloud.com/users/\(uid)/playlists",
                        clientId: clientId, oauth: oauthOpt
                    )
                    for (i, pl) in playlistJsons.enumerated() {
                        if let alb = await Self.makeAlbumFromPlaylist(
                            pl, ownerName: userName, clientId: clientId, oauth: oauthOpt,
                            progress: { idx, total, name in
                                await MainActor.run { self.connectionStatus = "\(name) \(idx)/\(total)" }
                            }), !alb.tracks.isEmpty {
                            newAlbums.append(alb)
                        }
                        await MainActor.run {
                            self.connectionStatus = "Плейлист \(i+1)/\(playlistJsons.count)"
                        }
                    }
                }

            case "playlist", "system-playlist":
                if let alb = await Self.makeAlbumFromPlaylist(
                    resolved, ownerName: nil, clientId: clientId, oauth: oauthOpt,
                    progress: { idx, total, name in
                        await MainActor.run { self.connectionStatus = "\(name) \(idx)/\(total)" }
                    }), !alb.tracks.isEmpty {
                    newAlbums.append(alb)
                }

            case "track":
                let tracks = await Self.buildTracks(from: [resolved], clientId: clientId, oauth: oauthOpt) { _, _ in }
                if !tracks.isEmpty {
                    newAlbums.append(Album(
                        id: "sc_track_\(resolved["id"] ?? UUID().uuidString)",
                        name: tracks[0].title,
                        kind: .custom,
                        artworkUrl: tracks[0].albumArtUrl,
                        tracks: tracks
                    ))
                }

            default:
                throw NSError(domain: "SC", code: 3,
                              userInfo: [NSLocalizedDescriptionKey: "Неподдерживаемый тип: \(kind)"])
            }

            guard !newAlbums.isEmpty else {
                throw NSError(domain: "SC", code: 4,
                              userInfo: [NSLocalizedDescriptionKey:
                                "Треков не найдено (kind=\(kind), path=\(path))"])
            }

            // Replace SoundCloud-related albums (likes/uploads/playlist), keep demo & spotify
            self.albums.removeAll { [.likes, .uploads, .playlist].contains($0.kind) }
            self.albums.append(contentsOf: newAlbums)
            self.selectedAlbumId = newAlbums.first?.id
            self.playingAlbumId = newAlbums.first?.id
            self.currentTrack = newAlbums.first?.tracks.first

            self.persistLibrary()
            self.persistOAuth()

            let total = newAlbums.reduce(0) { $0 + $1.tracks.count }
            self.connectionStatus = "Импортировано \(newAlbums.count) альбомов · \(total) треков"
        } catch {
            self.connectionStatus = "Ошибка SoundCloud: \(error.localizedDescription)"
        }

        isConnecting = false
    }

    // MARK: - SoundCloud higher-level helpers

    private static func fetchCollection(urlString: String, clientId: String, oauth: String?) async throws -> [[String: Any]] {
        guard var c = URLComponents(string: urlString) else { return [] }
        c.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "limit", value: "200")
        ]
        guard let url = c.url else { return [] }
        let data = try await fetchData(url: url, oauth: oauth)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let collection = json["collection"] as? [[String: Any]] else { return [] }
        log("collection from \(urlString) size: \(collection.count)")
        return collection
    }

    /// Likes endpoint wraps the actual track in entry["track"]; flatten that out.
    private static func flattenLikes(_ entries: [[String: Any]]) -> [[String: Any]] {
        entries.compactMap { $0["track"] as? [String: Any] }
    }

    /// Build [Track] from a list of raw track JSONs, resolving missing `media` via /tracks/{id}.
    private static func buildTracks(
        from rawList: [[String: Any]],
        clientId: String,
        oauth: String?,
        progress: (Int, Int) async -> Void
    ) async -> [Track] {
        var built: [Track] = []
        for (idx, raw) in rawList.enumerated() {
            await progress(idx + 1, rawList.count)
            var fullRaw = raw
            if (raw["media"] as? [String: Any]) == nil, let tid = raw["id"] as? Int {
                var tc = URLComponents(string: "https://api-v2.soundcloud.com/tracks/\(tid)")!
                tc.queryItems = [URLQueryItem(name: "client_id", value: clientId)]
                if let data = try? await fetchData(url: tc.url!, oauth: oauth),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    fullRaw = json
                }
            }
            if let track = try? await makeTrack(from: fullRaw, clientId: clientId, oauth: oauth) {
                built.append(track)
            }
        }
        return built
    }

    private static func makeAlbumFromPlaylist(
        _ pl: [String: Any],
        ownerName: String?,
        clientId: String,
        oauth: String?,
        progress: (Int, Int, String) async -> Void
    ) async -> Album? {
        guard let id = pl["id"] as? Int else { return nil }
        let title = (pl["title"] as? String) ?? "Без названия"
        let artwork = (pl["artwork_url"] as? String)?
            .replacingOccurrences(of: "-large.jpg", with: "-t500x500.jpg")
        let rawTracks = (pl["tracks"] as? [[String: Any]]) ?? []

        let tracks = await buildTracks(from: rawTracks, clientId: clientId, oauth: oauth) { idx, total in
            await progress(idx, total, title)
        }
        return Album(
            id: "sc_pl_\(id)",
            name: ownerName.map { "\(title) · \($0)" } ?? title,
            kind: .playlist,
            artworkUrl: artwork,
            tracks: tracks
        )
    }

    // MARK: - SoundCloud helpers

    private static func log(_ msg: String) {
        // Goes to stdout/stderr so the user can see it when running ./AestheticPlayer in a terminal
        FileHandle.standardError.write(Data("[SC] \(msg)\n".utf8))
    }

    private static func fetchData(url: URL, oauth: String? = nil) async throws -> Data {
        var req = URLRequest(url: url)
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
                     forHTTPHeaderField: "User-Agent")
        // Attach user OAuth token only on api-v2 requests (not on the public HTML/JS bundles)
        if let token = oauth, !token.isEmpty,
           let host = url.host, host.contains("soundcloud.com") || host.contains("sndcdn.com") {
            // SoundCloud accepts a few formats; "OAuth <token>" matches what the web app sends
            let cleaned = token
                .replacingOccurrences(of: "OAuth ", with: "")
                .replacingOccurrences(of: "Bearer ", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            req.setValue("OAuth \(cleaned)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse {
            log("HTTP \(http.statusCode) \(url.absoluteString) (\(data.count)B)")
            if http.statusCode >= 400 {
                let snippet = String(data: data.prefix(200), encoding: .utf8) ?? ""
                throw NSError(domain: "HTTP", code: http.statusCode,
                              userInfo: [NSLocalizedDescriptionKey:
                                "HTTP \(http.statusCode) \(url.host ?? ""): \(snippet)"])
            }
        }
        return data
    }

    private static func fetchString(url: URL, oauth: String? = nil) async throws -> String {
        let data = try await fetchData(url: url, oauth: oauth)
        guard let s = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "SC", code: 10,
                          userInfo: [NSLocalizedDescriptionKey: "Не удалось декодировать страницу"])
        }
        return s
    }

    /// Pulls SoundCloud's rotating public client_id by scanning one of the
    /// JS bundles referenced from the page (the last bundle reliably contains it).
    private static func extractClientId(fromHTML html: String) async throws -> String {
        let nsHtml = html as NSString
        let scriptRegex = try NSRegularExpression(
            pattern: #"https://a-v2\.sndcdn\.com/assets/[^"']+\.js"#
        )
        let matches = scriptRegex.matches(in: html, range: NSRange(location: 0, length: nsHtml.length))
        var urls: [String] = matches.map { nsHtml.substring(with: $0.range) }
        // Deduplicate, keep order, prefer the LAST (the one with client_id usually loads last)
        var seen = Set<String>()
        urls = urls.filter { seen.insert($0).inserted }

        let cidRegex = try NSRegularExpression(
            pattern: #"client_id\s*[:=]\s*"([A-Za-z0-9]{20,})""#
        )

        for jsURLStr in urls.reversed() {
            guard let jsURL = URL(string: jsURLStr) else { continue }
            guard let js = try? await fetchString(url: jsURL) else { continue }
            let nsJs = js as NSString
            if let m = cidRegex.firstMatch(in: js, range: NSRange(location: 0, length: nsJs.length)),
               m.numberOfRanges > 1 {
                return nsJs.substring(with: m.range(at: 1))
            }
        }

        throw NSError(domain: "SC", code: 20,
                      userInfo: [NSLocalizedDescriptionKey: "client_id не найден на странице"])
    }

    /// Build a `Track` from SoundCloud's track JSON. Resolves the progressive stream URL.
    private static func makeTrack(from raw: [String: Any], clientId: String, oauth: String? = nil) async throws -> Track {
        guard let id = raw["id"] as? Int,
              let title = raw["title"] as? String else {
            throw NSError(domain: "SC", code: 30)
        }
        let user = raw["user"] as? [String: Any]
        let artist = (user?["username"] as? String) ?? "SoundCloud"
        // Get larger artwork
        var artworkURL = raw["artwork_url"] as? String
        if artworkURL == nil, let avatar = user?["avatar_url"] as? String {
            artworkURL = avatar
        }
        artworkURL = artworkURL?
            .replacingOccurrences(of: "-large.jpg", with: "-t500x500.jpg")
            .replacingOccurrences(of: "-large.png", with: "-t500x500.png")

        let durationMs = (raw["full_duration"] as? Double) ?? (raw["duration"] as? Double) ?? 0

        // Resolve a progressive transcoding (mp3) URL
        guard let media = raw["media"] as? [String: Any],
              let transcodings = media["transcodings"] as? [[String: Any]] else {
            throw NSError(domain: "SC", code: 31,
                          userInfo: [NSLocalizedDescriptionKey: "Нет transcodings"])
        }

        // Prefer progressive (mp3); fall back to the first available (HLS — AVPlayer also handles)
        let chosen = transcodings.first(where: {
            let format = $0["format"] as? [String: Any]
            return (format?["protocol"] as? String) == "progressive"
        }) ?? transcodings.first

        guard let trURLStr = chosen?["url"] as? String,
              var trComps = URLComponents(string: trURLStr) else {
            throw NSError(domain: "SC", code: 32)
        }
        var qi = trComps.queryItems ?? []
        qi.append(URLQueryItem(name: "client_id", value: clientId))
        trComps.queryItems = qi

        guard let trURL = trComps.url else { throw NSError(domain: "SC", code: 33) }
        let data = try await fetchData(url: trURL, oauth: oauth)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let stream = json["url"] as? String else {
            throw NSError(domain: "SC", code: 34,
                          userInfo: [NSLocalizedDescriptionKey: "Не удалось получить stream URL"])
        }

        return Track(
            id: "sc_\(id)",
            title: title,
            artist: artist,
            albumArtUrl: artworkURL,
            audioUrl: stream,
            duration: durationMs / 1000.0
        )
    }
    
    // MARK: - High-Performance Wave Visualizer Simulation
    
    private func setupVisualizerTimer() {
        // 60 FPS for buttery-smooth spring-driven spectrum
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateVisualizerPhysics()
            }
        }
        // Use common modes so it keeps ticking during scrolls / drags
        RunLoop.main.add(timer, forMode: .common)
        visualizerTimer = timer
    }
    
    private func updateVisualizerPhysics() {
        let count = visualizerBars.count
        
        if isPlaying {
            // Halved because we now tick at 60 Hz instead of 30 Hz
            beatCounter += 0.075
            
            // Generate a natural-looking frequency spectrum using mathematical harmonics
            for i in 0..<count {
                let indexFactor = Double(i) / Double(count)
                
                // Base rhythm/beat wave (bass on the left, treble on the right)
                let bassFrequency = sin(beatCounter * 1.5) * 0.35 + 0.45
                let midFrequency = cos(beatCounter * 0.8 + Double(i) * 0.2) * 0.25 + 0.3
                let highFrequency = sin(beatCounter * 2.2 - Double(i) * 0.4) * 0.15 + 0.15
                
                var amplitude = 0.0
                
                if i < count / 4 {
                    // Bass section (low index)
                    amplitude = bassFrequency * (1.0 - indexFactor) * 0.95
                } else if i < count * 3 / 4 {
                    // Mid section
                    amplitude = midFrequency * 0.8
                } else {
                    // Treble section (high index)
                    amplitude = highFrequency * indexFactor * 1.2
                }
                
                // Add some natural-looking micro-noise jitter
                let noise = Double.random(in: -0.05...0.05)
                amplitude = max(0.02, min(1.0, amplitude + noise))
                
                // Apply volume factor
                targetBars[i] = amplitude * volume
            }
        } else {
            // Decay to zero when paused
            for i in 0..<count {
                targetBars[i] = 0.01
            }
        }
        
        // Smooth physics-based spring interpolation
        // bars = bars + velocity * dt
        // velocity = velocity + (target - bars) * springStiffness - velocity * damping
        // Tuned for 60 Hz (smaller step → smoother spring)
        let stiffness = 0.20
        let damping = 0.78
        
        for i in 0..<count {
            let displacement = targetBars[i] - visualizerBars[i]
            let force = displacement * stiffness
            
            velocities[i] = velocities[i] * damping + force
            visualizerBars[i] = max(0.01, visualizerBars[i] + velocities[i])
        }
    }
}
