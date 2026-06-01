import Foundation
import AVFoundation
import Combine
import SwiftUI
import MediaPlayer
import AppKit
import UniformTypeIdentifiers

struct Track: Identifiable, Equatable, Hashable, Codable {
    let id: String
    let title: String
    let artist: String
    let albumArtUrl: String?
    let audioUrl: String
    let duration: Double // in seconds

    static func == (lhs: Track, rhs: Track) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // Apple Music style ambient colors generated dynamically or by brand
    var ambientColors: [Color] {
        if id.hasPrefix("spotify") {
            return [
                Color(red: 0.117, green: 0.843, blue: 0.376), // Spotify Green
                Color(red: 0.05, green: 0.15, blue: 0.05)
            ]
        } else if id.hasPrefix("sc_") {
            return [
                Color(red: 1.000, green: 0.333, blue: 0.000), // SoundCloud Orange
                Color(red: 0.20, green: 0.08, blue: 0.0)
            ]
        }
        let hashVal = abs(title.hashValue ^ artist.hashValue)
        let hue1 = Double(hashVal % 360) / 360.0
        let hue2 = Double((hashVal + 140) % 360) / 360.0
        return [
            Color(hue: hue1, saturation: 0.68, brightness: 0.85),
            Color(hue: hue2, saturation: 0.60, brightness: 0.70)
        ]
    }
}

enum AlbumKind: String, Codable {
    case demo, uploads, likes, playlist, custom, spotify
}

enum SearchSource: String, Codable {
    case soundCloud
    case spotify
}

struct Album: Identifiable, Equatable, Codable {
    let id: String
    var name: String
    var kind: AlbumKind
    var artworkUrl: String?
    var tracks: [Track]
}

// MARK: - High-Frequency Audio & Visual State (Isolates 60 FPS redraws)
@MainActor
final class HighFrequencyState: ObservableObject {
    @Published var visualizerBars: [Double] = Array(repeating: 0.0, count: 28)
    @Published var currentTime: Double = 0.0
}

@MainActor
class PlayerViewModel: ObservableObject {
    // High frequency state instance
    let hfState = HighFrequencyState()

    // Playback State
    @Published var isPlaying = false
    var currentTime: Double = 0.0 {
        didSet {
            hfState.currentTime = currentTime
        }
    }
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
    @Published var uiOpacity: Double = UserDefaults.standard.double(forKey: "uiOpacity") == 0 ? 0.60 : UserDefaults.standard.double(forKey: "uiOpacity") {
        didSet {
            UserDefaults.standard.set(uiOpacity, forKey: "uiOpacity")
        }
    }
    @Published var visualEffectsEnabled: Bool = (UserDefaults.standard.object(forKey: "visualEffectsEnabled") as? Bool) ?? true {
        didSet {
            UserDefaults.standard.set(visualEffectsEnabled, forKey: "visualEffectsEnabled")
        }
    }
    @Published var currentAmbientColors: [Color] = []

    // Services / Inputs
    @Published var spotifyToken = ""
    @Published var soundCloudUrl = ""
    @Published var soundCloudOAuth = ""   // optional user-supplied OAuth token (for private content)
    @Published var connectionStatus = ""
    @Published var isConnecting = false

    // SoundCloud & Spotify Search
    @Published var showSearchBar = false
    @Published var searchQuery = ""
    @Published var searchSource: SearchSource = .soundCloud
    @Published var searchResults: [Track] = []
    @Published var isSearching = false
    @Published var searchStatus = ""
    @Published var searchTargetPlaylistId: String? = nil
    private var searchTask: Task<Void, Never>?

    var searchAlbum: Album {
        Album(id: "search", name: "Результаты поиска", kind: .custom, artworkUrl: nil, tracks: searchResults)
    }
    var localPlaylists: [Album] {
        albums.filter { $0.kind == .custom && $0.id.hasPrefix("local_") }
    }
    var searchTargetPlaylist: Album? {
        if let id = searchTargetPlaylistId,
           let album = albums.first(where: { $0.id == id }) {
            return album
        }
        return localPlaylists.first
    }

    // Computed: the queue used by next/prev
    var playlist: [Track] {
        if playingAlbumId == "search" { return searchResults }
        if let id = playingAlbumId, let a = albums.first(where: { $0.id == id }) { return a.tracks }
        if let id = selectedAlbumId, let a = albums.first(where: { $0.id == id }) { return a.tracks }
        return albums.first?.tracks ?? []
    }
    var selectedAlbum: Album? {
        albums.first(where: { $0.id == selectedAlbumId }) ?? albums.first
    }
    
    // Visualizer State
    var visualizerBars: [Double] = Array(repeating: 0.0, count: 28) {
        didSet {
            hfState.visualizerBars = visualizerBars
        }
    }
    private var targetBars: [Double] = Array(repeating: 0.0, count: 28)
    private var velocities: [Double] = Array(repeating: 0.0, count: 28)
    
    // Internal Player
    private var player = AVPlayer()
    private var timeObserver: Any?
    private var playerFinishedObserver: Any?
    private var visualizerTimer: Timer?
    private var beatCounter = 0.0
    private var hasPrintedTerminalVisualizer = false
    private var terminalTickCounter = 0
    private static var scClientId: String? = nil
    var isTuiActive = false
    static var isStaticTuiActive = false
    private var loginWindowController: LoginWebWindowController?
    private var normalizedSpotifyToken: String {
        spotifyToken
            .replacingOccurrences(of: "Bearer ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    init() {
        // Restore OAuth from Keychain if present
        if let saved = Keychain.load(account: "soundcloud_oauth") {
            self.soundCloudOAuth = saved
        }
        // Restore Spotify Token if present
        if let savedSpotify = Keychain.load(account: "spotify_token") {
            self.spotifyToken = savedSpotify
        }

        let loadedAlbums = LibraryStore.load()
        let cached = loadedAlbums.filter { $0.kind != .demo }
        self.albums = cached
        if cached.count != loadedAlbums.count {
            LibraryStore.save(cached)
        }
        if let lastTrackId = UserDefaults.standard.string(forKey: "lastPlayingTrackId") {
            var foundTrack: Track? = nil
            var foundAlbum: Album? = nil
            
            for album in self.albums {
                if let track = album.tracks.first(where: { $0.id == lastTrackId }) {
                    foundTrack = track
                    foundAlbum = album
                    break
                }
            }
            
            if let track = foundTrack, let album = foundAlbum {
                self.selectedAlbumId = album.id
                self.playingAlbumId = album.id
                self.currentTrack = track
                
                let lastTime = UserDefaults.standard.double(forKey: "lastPlayingTime")
                DispatchQueue.main.async { [weak self] in
                    self?.loadTrack(track, in: album, seekTo: lastTime)
                }
            } else {
                self.selectedAlbumId = self.albums.first?.id
                self.playingAlbumId = self.selectedAlbumId
                self.currentTrack = self.albums.first?.tracks.first
                if let firstAlbum = self.albums.first, let firstTrack = firstAlbum.tracks.first {
                    DispatchQueue.main.async { [weak self] in
                        self?.loadTrack(firstTrack, in: firstAlbum, seekTo: 0.0)
                    }
                }
            }
        } else {
            self.selectedAlbumId = self.albums.first?.id
            self.playingAlbumId = self.selectedAlbumId
            self.currentTrack = self.albums.first?.tracks.first
            if let firstAlbum = self.albums.first, let firstTrack = firstAlbum.tracks.first {
                DispatchQueue.main.async { [weak self] in
                    self?.loadTrack(firstTrack, in: firstAlbum, seekTo: 0.0)
                }
            }
        }
        self.searchTargetPlaylistId = self.localPlaylists.first?.id

        setupAudioSession()
        setupVisualizerTimer()
        setupTimeObserver()
        
        // Auto-connect cloud services on startup if tokens exist
        Task { [weak self] in
            guard let self = self else { return }
            if !self.soundCloudOAuth.isEmpty {
                Self.log("Startup: Auto-connecting SoundCloud...")
                await self.connectSoundCloud()
            }
            if !self.spotifyToken.isEmpty {
                Self.log("Startup: Auto-connecting Spotify...")
                await self.connectSpotify()
            }
        }

        // Notify player of initial volume
        player.volume = Float(volume)
        
        setupRemoteCommandCenter()

        // Setup Keyboard Event Observers from KeyableWindow
        NotificationCenter.default.addObserver(forName: NSNotification.Name("appVolumeUp"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.volume = min(1.0, self.volume + 0.05)
            }
        }
        NotificationCenter.default.addObserver(forName: NSNotification.Name("appVolumeDown"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.volume = max(0.0, self.volume - 0.05)
            }
        }
        NotificationCenter.default.addObserver(forName: NSNotification.Name("appSeekBackward"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.seek(to: max(0.0, self.currentTime - 5.0))
            }
        }
        NotificationCenter.default.addObserver(forName: NSNotification.Name("appSeekForward"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let track = self.currentTrack else { return }
                self.seek(to: min(track.duration, self.currentTime + 5.0))
            }
        }
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
        player.pause()
        albums = []
        selectedAlbumId = nil
        playingAlbumId = nil
        currentTrack = nil
        currentTime = 0.0
        isPlaying = false
        searchTargetPlaylistId = nil
        spotifyToken = ""
        soundCloudUrl = ""
        soundCloudOAuth = ""
        Keychain.remove(account: "soundcloud_oauth")
        Keychain.remove(account: "spotify_token")
        persistLibrary()
    }

    func deleteAlbumLocally(_ albumId: String) {
        let wasPlayingDeletedAlbum = playingAlbumId == albumId
        albums.removeAll(where: { $0.id == albumId })
        if selectedAlbumId == albumId {
            selectedAlbumId = albums.first?.id
        }
        if searchTargetPlaylistId == albumId {
            searchTargetPlaylistId = localPlaylists.first?.id
        }
        if wasPlayingDeletedAlbum {
            playingAlbumId = selectedAlbumId
            if let nextAlbum = selectedAlbum, let nextTrack = nextAlbum.tracks.first {
                loadTrack(nextTrack, in: nextAlbum, seekTo: 0.0)
            } else {
                player.pause()
                currentTrack = nil
                currentTime = 0.0
                isPlaying = false
            }
        }
        persistLibrary()
    }

    @discardableResult
    func createLocalPlaylist(named rawName: String) -> Album {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = trimmed.isEmpty ? "Новый плейлист" : trimmed
        let existingNames = Set(albums.map { $0.name })
        var finalName = baseName
        var suffix = 2
        while existingNames.contains(finalName) {
            finalName = "\(baseName) \(suffix)"
            suffix += 1
        }

        let album = Album(
            id: "local_\(UUID().uuidString)",
            name: finalName,
            kind: .custom,
            artworkUrl: nil,
            tracks: []
        )
        albums.append(album)
        selectedAlbumId = album.id
        if playingAlbumId == nil {
            playingAlbumId = album.id
        }
        searchTargetPlaylistId = album.id
        persistLibrary()
        return album
    }

    func importLocalAudioFiles() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Импорт локальных аудиофайлов"
        openPanel.allowedContentTypes = [
            UTType.mp3,
            UTType.mpeg4Audio, // for m4a
            UTType.wav, // for wav
            UTType(tag: "aac", tagClass: .filenameExtension, conformingTo: nil),
            UTType(tag: "flac", tagClass: .filenameExtension, conformingTo: nil)
        ].compactMap { $0 }
        openPanel.allowsMultipleSelection = true
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        
        if openPanel.runModal() == .OK {
            let selectedURLs = openPanel.urls
            guard !selectedURLs.isEmpty else { return }
            
            self.searchStatus = "Импорт \(selectedURLs.count) файлов..."
            
            Task {
                var newTracks: [Track] = []
                for url in selectedURLs {
                    let asset = AVURLAsset(url: url)
                    
                    let (title, artist, duration) = await self.loadMetadata(for: asset, defaultTitle: url.deletingPathExtension().lastPathComponent)
                    
                    let trackId = "local_\(abs(url.path.hashValue))"
                    
                    let track = Track(
                        id: trackId,
                        title: title,
                        artist: artist,
                        albumArtUrl: "music.note",
                        audioUrl: url.absoluteString,
                        duration: duration
                    )
                    newTracks.append(track)
                }
                
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    
                    var playlistIndex = self.albums.firstIndex(where: { $0.id == "local_files" })
                    if playlistIndex == nil {
                        let newAlbum = Album(
                            id: "local_files",
                            name: "Локальные файлы",
                            kind: .custom,
                            artworkUrl: "music.note",
                            tracks: []
                        )
                        self.albums.append(newAlbum)
                        playlistIndex = self.albums.count - 1
                    }
                    
                    if let idx = playlistIndex {
                        var addedCount = 0
                        for track in newTracks {
                            if !self.albums[idx].tracks.contains(where: { $0.id == track.id }) {
                                self.albums[idx].tracks.append(track)
                                addedCount += 1
                            }
                        }
                        
                        self.selectedAlbumId = "local_files"
                        self.searchStatus = "Импортировано треков: \(addedCount)"
                        
                        if self.searchTargetPlaylistId == nil {
                            self.searchTargetPlaylistId = "local_files"
                        }
                    }
                    
                    self.persistLibrary()
                }
            }
        }
    }

    private func loadMetadata(for asset: AVAsset, defaultTitle: String) async -> (title: String, artist: String, duration: Double) {
        if #available(macOS 13.0, *) {
            do {
                let commonMetadata = try await asset.load(.commonMetadata)
                var title = defaultTitle
                var artist = "Неизвестный исполнитель"
                
                if let titleItem = AVMetadataItem.metadataItems(from: commonMetadata, withKey: AVMetadataKey.commonKeyTitle, keySpace: AVMetadataKeySpace.common).first {
                    if let titleVal = try? await titleItem.load(.stringValue), !titleVal.trimmingCharacters(in: .whitespaces).isEmpty {
                        title = titleVal
                    }
                }
                
                if let artistItem = AVMetadataItem.metadataItems(from: commonMetadata, withKey: AVMetadataKey.commonKeyArtist, keySpace: AVMetadataKeySpace.common).first {
                    if let artistVal = try? await artistItem.load(.stringValue), !artistVal.trimmingCharacters(in: .whitespaces).isEmpty {
                        artist = artistVal
                    }
                }
                
                let duration = try await asset.load(.duration).seconds
                return (title, artist, duration.isNaN || duration <= 0 ? 180.0 : duration)
            } catch {
                // If async load fails, fall back to KVC below
            }
        }
        
        // Fallback for macOS 12 using KVC to avoid compiler deprecation warnings
        var title = defaultTitle
        var artist = "Неизвестный исполнитель"
        
        let commonMetadata = asset.value(forKey: "commonMetadata") as? [AVMetadataItem] ?? []
        if let titleItem = AVMetadataItem.metadataItems(from: commonMetadata, withKey: AVMetadataKey.commonKeyTitle, keySpace: AVMetadataKeySpace.common).first,
           let titleVal = titleItem.value(forKey: "stringValue") as? String, !titleVal.trimmingCharacters(in: .whitespaces).isEmpty {
            title = titleVal
        }
        if let artistItem = AVMetadataItem.metadataItems(from: commonMetadata, withKey: AVMetadataKey.commonKeyArtist, keySpace: AVMetadataKeySpace.common).first,
           let artistVal = artistItem.value(forKey: "stringValue") as? String, !artistVal.trimmingCharacters(in: .whitespaces).isEmpty {
            artist = artistVal
        }
        
        let durationCMTime = asset.value(forKey: "duration") as? CMTime ?? .zero
        let duration = durationCMTime.seconds
        return (title, artist, duration.isNaN || duration <= 0 ? 180.0 : duration)
    }


    func addTrackToSearchTargetPlaylist(_ track: Track) {
        let targetId: String
        if let id = searchTargetPlaylist?.id {
            targetId = id
        } else {
            targetId = createLocalPlaylist(named: "Мой плейлист").id
        }
        addTrack(track, toLocalPlaylist: targetId)
    }

    func addTrack(_ track: Track, toLocalPlaylist playlistId: String) {
        guard let index = albums.firstIndex(where: { $0.id == playlistId }) else { return }
        if albums[index].tracks.contains(where: { $0.id == track.id }) {
            searchStatus = "Уже есть в \(albums[index].name)"
            return
        }
        albums[index].tracks.append(track)
        if albums[index].artworkUrl == nil {
            albums[index].artworkUrl = track.albumArtUrl
        }
        selectedAlbumId = albums[index].id
        searchTargetPlaylistId = albums[index].id
        searchStatus = "Добавлено в \(albums[index].name)"
        persistLibrary()
    }

    func deleteTrackLocally(_ trackId: String, from albumId: String) {
        guard let index = albums.firstIndex(where: { $0.id == albumId }) else { return }
        albums[index].tracks.removeAll(where: { $0.id == trackId })
        
        if currentTrack?.id == trackId && playingAlbumId == albumId {
            if albums[index].tracks.isEmpty {
                player.pause()
                currentTrack = nil
                currentTime = 0.0
                isPlaying = false
            } else {
                nextTrack()
            }
        }
        persistLibrary()
    }

    private func refreshSoundCloudTrackUrl(_ track: Track) async -> Track {
        guard track.id.hasPrefix("sc_") else { return track }
        let numericId = track.id.replacingOccurrences(of: "sc_", with: "")
        
        Self.log("Refreshing expired CDN URL for SoundCloud track: \(track.title) (\(numericId))")
        
        do {
            let clientId: String
            if let cached = Self.scClientId {
                clientId = cached
            } else {
                let html = try await Self.fetchString(url: URL(string: "https://soundcloud.com")!)
                clientId = try await Self.extractClientId(fromHTML: html)
                Self.scClientId = clientId
            }
            
            var tc = URLComponents(string: "https://api-v2.soundcloud.com/tracks/\(numericId)")!
            tc.queryItems = [URLQueryItem(name: "client_id", value: clientId)]
            
            let oauth = soundCloudOAuth.trimmingCharacters(in: .whitespacesAndNewlines)
            let oauthOpt = oauth.isEmpty ? nil : oauth
            
            let data = try await Self.fetchData(url: tc.url!, oauth: oauthOpt)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return track }
            
            let refreshedTrack = try await Self.makeTrack(from: json, clientId: clientId, oauth: oauthOpt)
            
            for (aIdx, album) in albums.enumerated() {
                if let tIdx = album.tracks.firstIndex(where: { $0.id == track.id }) {
                    albums[aIdx].tracks[tIdx] = refreshedTrack
                }
            }
            persistLibrary()
            
            return refreshedTrack
        } catch {
            Self.log("Error refreshing SoundCloud track: \(error.localizedDescription)")
            return track
        }
    }
    
    deinit {
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
        }
        NotificationCenter.default.removeObserver(self)
        visualizerTimer?.invalidate()
    }
    
    private func setupAudioSession() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidPlayToEndTime(_:)),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
    }

    @objc private func playerItemDidPlayToEndTime(_ notification: Notification) {
        Self.log("AVPlayerItemDidPlayToEndTime notification received. Hopping to main queue to advance.")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.nextTrack()
        }
    }
    
    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.25, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            Task { @MainActor in
                guard self.isPlaying else { return }
                self.currentTime = time.seconds
                UserDefaults.standard.set(time.seconds, forKey: "lastPlayingTime")
            }
        }
    }
    
    // MARK: - Playback Controls
    
    func playTrack(_ track: Track, in album: Album? = nil) {
        // Anchor the playback queue to whatever album the user clicked from
        if let album = album {
            playingAlbumId = album.id
        } else if playingAlbumId != nil && playlist.contains(where: { $0.id == track.id }) {
            // Already playing an album/playlist that contains this track, keep playing it!
        } else if let containing = albums.first(where: { $0.tracks.contains(where: { $0.id == track.id }) }) {
            playingAlbumId = containing.id
        }

        currentTrack = track
        currentAmbientColors = track.ambientColors
        currentTime = 0.0
        isPlaying = true // immediately indicate playing state to update visualizers/UI

        UserDefaults.standard.set(track.id, forKey: "lastPlayingTrackId")
        if let albumId = playingAlbumId {
            UserDefaults.standard.set(albumId, forKey: "lastPlayingAlbumId")
        }
        UserDefaults.standard.set(0.0, forKey: "lastPlayingTime")

        Task {
            let activeTrack: Track
            if track.id.hasPrefix("sc_") {
                activeTrack = await refreshSoundCloudTrackUrl(track)
            } else {
                activeTrack = track
            }
            
            // Check that the user hasn't skipped to another track while we were resolving
            guard self.currentTrack?.id == track.id else { return }
            
            guard let url = URL(string: activeTrack.audioUrl) else {
                self.isPlaying = false
                return
            }
            
            let currentVol = self.player.volume
            let playerItem = AVPlayerItem(url: url)
            self.player.replaceCurrentItem(with: playerItem)
            self.player.volume = currentVol
            
            self.player.play()
            self.updateNowPlayingInfo()
        }
    }

    func loadTrack(_ track: Track, in album: Album? = nil, seekTo time: Double = 0.0) {
        if let album = album {
            playingAlbumId = album.id
        } else if playingAlbumId != nil && playlist.contains(where: { $0.id == track.id }) {
            // Already playing
        } else if let containing = albums.first(where: { $0.tracks.contains(where: { $0.id == track.id }) }) {
            playingAlbumId = containing.id
        }

        currentTrack = track
        currentAmbientColors = track.ambientColors
        currentTime = time
        isPlaying = false // pre-loaded, but paused

        UserDefaults.standard.set(track.id, forKey: "lastPlayingTrackId")
        if let albumId = playingAlbumId {
            UserDefaults.standard.set(albumId, forKey: "lastPlayingAlbumId")
        }

        Task {
            let activeTrack: Track
            if track.id.hasPrefix("sc_") {
                activeTrack = await refreshSoundCloudTrackUrl(track)
            } else {
                activeTrack = track
            }
            
            guard self.currentTrack?.id == track.id else { return }
            
            guard let url = URL(string: activeTrack.audioUrl) else { return }
            
            let currentVol = self.player.volume
            let playerItem = AVPlayerItem(url: url)
            self.player.replaceCurrentItem(with: playerItem)
            self.player.volume = currentVol
            
            if time > 0 {
                let targetTime = CMTime(seconds: time, preferredTimescale: 1000)
                self.player.seek(to: targetTime) { _ in }
            }
            self.updateNowPlayingInfo()
        }
    }
    
    func play() {
        if player.currentItem == nil, let track = currentTrack {
            playTrack(track, in: selectedAlbum)
            return
        }

        guard currentTrack != nil else {
            if let album = selectedAlbum, let track = album.tracks.first {
                playTrack(track, in: album)
            }
            return
        }

        player.play()
        isPlaying = true
        updateNowPlayingInfo()
    }
    
    func pause() {
        player.pause()
        isPlaying = false
        updateNowPlayingInfo()
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
                    self.updateNowPlayingInfo()
                }
            }
        }
    }
    
    func nextTrack() {
        let queue = playlist
        guard !queue.isEmpty else { return }
        guard let current = currentTrack, let index = queue.firstIndex(of: current) else {
            playTrack(queue[0])
            return
        }
        
        if isRepeat {
            seek(to: 0)
            play()
            return
        }
        
        let nextIndex: Int
        if isShuffle {
            if queue.count == 1 {
                nextIndex = 0
            } else {
                var candidate = index
                while candidate == index {
                    candidate = Int.random(in: 0..<queue.count)
                }
                nextIndex = candidate
            }
        } else {
            nextIndex = (index + 1) % queue.count
        }
        
        playTrack(queue[nextIndex])
    }
    
    func prevTrack() {
        let queue = playlist
        guard !queue.isEmpty else { return }
        guard let current = currentTrack, let index = queue.firstIndex(of: current) else {
            playTrack(queue[0])
            return
        }
        
        let prevIndex = (index - 1 + queue.count) % queue.count
        playTrack(queue[prevIndex])
    }
    
    func toggleShuffle() {
        isShuffle.toggle()
    }
    
    func toggleRepeat() {
        isRepeat.toggle()
    }
    
    // MARK: - Spotify & SoundCloud Connections
    
    func startSpotifyWebLogin() {
        let controller = LoginWebWindowController(isSpotify: true)
        controller.onSpotifyTokenObtained = { [weak self] token in
            Task { @MainActor in
                guard let self = self else { return }
                self.spotifyToken = token
                Keychain.save(token, account: "spotify_token")
                self.connectionStatus = "Токен Spotify получен! Подключение..."
                await self.connectSpotify()
            }
        }
        controller.showWindow(nil)
        self.loginWindowController = controller
    }

    func startSoundCloudWebLogin() {
        let controller = LoginWebWindowController(isSpotify: false)
        controller.onSoundCloudTokenObtained = { [weak self] token in
            Task { @MainActor in
                guard let self = self else { return }
                self.soundCloudOAuth = token
                self.persistOAuth()
                self.connectionStatus = "Токен SoundCloud получен! Автоматический вход..."
                await self.connectSoundCloud()
            }
        }
        controller.showWindow(nil)
        self.loginWindowController = controller
    }

    func disconnectSpotify() {
        spotifyToken = ""
        Keychain.remove(account: "spotify_token")
        self.albums.removeAll { $0.id.hasPrefix("spotify_") }
        if selectedAlbumId?.hasPrefix("spotify_") == true {
            selectedAlbumId = nil
        }
        if playingAlbumId?.hasPrefix("spotify_") == true {
            player.pause()
            isPlaying = false
            currentTrack = nil
        }
        persistLibrary()
        connectionStatus = "Spotify отключен"
    }

    func disconnectSoundCloud() {
        soundCloudOAuth = ""
        soundCloudUrl = ""
        Keychain.remove(account: "soundcloud_oauth")
        self.albums.removeAll { $0.id.hasPrefix("soundcloud_") }
        if selectedAlbumId?.hasPrefix("soundcloud_") == true {
            selectedAlbumId = nil
        }
        if playingAlbumId?.hasPrefix("soundcloud_") == true {
            player.pause()
            isPlaying = false
            currentTrack = nil
        }
        persistLibrary()
        connectionStatus = "SoundCloud отключен"
    }

    func connectSpotify() async {
        let token = normalizedSpotifyToken
        guard !token.isEmpty else {
            connectionStatus = "Введите токен!"
            return
        }
        
        isConnecting = true
        connectionStatus = "Подключение к Spotify..."
        
        var request = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/playlists?limit=10")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
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
                        tracksRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                        
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
                        self.albums.removeAll { $0.kind == .demo }
                        self.albums.append(album)
                        if self.selectedAlbumId == nil {
                            self.selectedAlbumId = album.id
                        }
                        if self.playingAlbumId == nil {
                            self.playingAlbumId = album.id
                        }
                        if self.currentTrack == nil {
                            self.currentTrack = fetchedTracks.first
                        }
                        self.persistLibrary()
                        self.spotifyToken = token
                        Keychain.save(token, account: "spotify_token")
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
        var raw = soundCloudUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let oauth = soundCloudOAuth.trimmingCharacters(in: .whitespacesAndNewlines)
        let oauthOpt: String? = oauth.isEmpty ? nil : oauth

        Self.log("=== connectSoundCloud start ===")
        
        isConnecting = true
        
        if raw.isEmpty {
            if let token = oauthOpt {
                connectionStatus = "Определение профиля SoundCloud..."
                do {
                    let homeHTML = try await Self.fetchString(url: URL(string: "https://soundcloud.com")!)
                    let clientId = try await Self.extractClientId(fromHTML: homeHTML)
                    
                    guard var meComps = URLComponents(string: "https://api-v2.soundcloud.com/me") else {
                        throw NSError(domain: "SC", code: -1)
                    }
                    meComps.queryItems = [URLQueryItem(name: "client_id", value: clientId)]
                    guard let meURL = meComps.url else { throw NSError(domain: "SC", code: -2) }
                    
                    let meData = try await Self.fetchData(url: meURL, oauth: token)
                    if let meJson = try? JSONSerialization.jsonObject(with: meData) as? [String: Any],
                       let permalinkUrl = meJson["permalink_url"] as? String {
                        let resolvedUrl = permalinkUrl
                        await MainActor.run {
                            self.soundCloudUrl = resolvedUrl
                            UserDefaults.standard.set(resolvedUrl, forKey: "soundCloudUrl")
                        }
                        raw = resolvedUrl
                        Self.log("Automatically resolved SoundCloud user URL: \(raw)")
                    } else {
                        throw NSError(domain: "SC", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to parse profile JSON"])
                    }
                } catch {
                    connectionStatus = "Не удалось определить профиль: \(error.localizedDescription)"
                    isConnecting = false
                    return
                }
            } else {
                connectionStatus = "Пожалуйста, привяжите SoundCloud через Web"
                isConnecting = false
                return
            }
        }

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

        Self.log("input URL: \(raw)")

        guard let pageURL = URL(string: raw),
              pageURL.host?.contains("soundcloud.com") == true else {
            connectionStatus = "Некорректная ссылка SoundCloud"
            Self.log("invalid URL after normalization: \(raw)")
            isConnecting = false
            return
        }

        connectionStatus = "Загрузка страницы SoundCloud..."
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

                    // --- RECOMMENDATIONS / CHARTS LOADER ---
                    var recommendationTracks: [Track] = []
                    if oauthOpt != nil {
                        do {
                            Self.log("Fetching personalized recommendations for user \(uid)...")
                            let recJsons = try await Self.fetchCollection(
                                urlString: "https://api-v2.soundcloud.com/users/\(uid)/track_recommendations",
                                clientId: clientId, oauth: oauthOpt
                            )
                            let recs = await Self.buildTracks(from: Self.flattenTracks(recJsons),
                                                               clientId: clientId, oauth: oauthOpt) { idx, total in
                                await MainActor.run { self.connectionStatus = "Рекомендации \(idx)/\(total)" }
                            }
                            recommendationTracks = recs
                        } catch {
                            Self.log("Failed to load personalized recommendations: \(error)")
                        }
                    }

                    if recommendationTracks.isEmpty {
                        do {
                            Self.log("Personalized recommendations unavailable or empty. Fetching global charts...")
                            let chartsJsons = try await Self.fetchCollection(
                                urlString: "https://api-v2.soundcloud.com/charts?kind=top&genre=soundcloud%3Agenres%3Aall-music",
                                clientId: clientId, oauth: oauthOpt
                            )
                            let charts = await Self.buildTracks(from: Self.flattenTracks(chartsJsons),
                                                                 clientId: clientId, oauth: oauthOpt) { idx, total in
                                await MainActor.run { self.connectionStatus = "Топ-Чарты \(idx)/\(total)" }
                            }
                            recommendationTracks = charts
                        } catch {
                            Self.log("Failed to load trending charts: \(error)")
                        }
                    }

                    if !recommendationTracks.isEmpty {
                        newAlbums.append(Album(
                            id: "sc_recommendations_\(uid)",
                            name: oauthOpt != nil ? "⚡ Рекомендации · \(userName)" : "🔥 Топ-Чарт SoundCloud",
                            kind: .custom,
                            artworkUrl: recommendationTracks.first?.albumArtUrl,
                            tracks: recommendationTracks
                        ))
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

            // Replace SoundCloud-related albums (likes/uploads/playlist), keep spotify
            self.albums.removeAll { [.likes, .uploads, .playlist].contains($0.kind) }
            self.albums.removeAll { $0.kind == .demo }
            self.albums.append(contentsOf: newAlbums)
            if self.selectedAlbumId == nil {
                self.selectedAlbumId = newAlbums.first?.id
            }
            if self.playingAlbumId == nil {
                self.playingAlbumId = newAlbums.first?.id
            }
            if self.currentTrack == nil {
                self.currentTrack = newAlbums.first?.tracks.first
            }

            self.persistLibrary()
            self.persistOAuth()

            let total = newAlbums.reduce(0) { $0 + $1.tracks.count }
            self.connectionStatus = "Импортировано \(newAlbums.count) альбомов · \(total) треков"
        } catch {
            self.connectionStatus = "Ошибка SoundCloud: \(error.localizedDescription)"
        }

        isConnecting = false
    }

    // MARK: - Search Functionality

    func clearSearch() {
        resetSearch(keepingQuery: false)
    }

    func resetSearch(keepingQuery: Bool = true) {
        searchTask?.cancel()
        searchTask = nil
        if !keepingQuery {
            searchQuery = ""
        }
        searchResults = []
        isSearching = false
        searchStatus = ""
    }

    func executeSearch() {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        searchTask?.cancel()
        searchTask = nil

        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            searchStatus = ""
            return
        }

        isSearching = true
        searchResults = []

        switch searchSource {
        case .soundCloud:
            searchStatus = "Поиск в SoundCloud..."
            searchTask = Task {
                do {
                    // 1. Get client ID
                    let clientId: String
                    if let cached = Self.scClientId {
                        clientId = cached
                    } else {
                        let homepageURL = URL(string: "https://soundcloud.com")!
                        let html = try await Self.fetchString(url: homepageURL)
                        clientId = try await Self.extractClientId(fromHTML: html)
                        Self.scClientId = clientId
                    }

                    // 2. Query the search endpoint
                    guard var comps = URLComponents(string: "https://api-v2.soundcloud.com/search/tracks") else {
                        throw NSError(domain: "SC", code: 0)
                    }
                    let oauthOpt: String? = soundCloudOAuth.isEmpty ? nil : soundCloudOAuth
                    comps.queryItems = [
                        URLQueryItem(name: "q", value: query),
                        URLQueryItem(name: "client_id", value: clientId),
                        URLQueryItem(name: "limit", value: "25")
                    ]

                    guard let searchURL = comps.url else { throw NSError(domain: "SC", code: 1) }
                    let searchData = try await Self.fetchData(url: searchURL, oauth: oauthOpt)
                    if Task.isCancelled { return }

                    guard let json = try JSONSerialization.jsonObject(with: searchData) as? [String: Any],
                          let collection = json["collection"] as? [[String: Any]] else {
                        throw NSError(domain: "SC", code: 2, userInfo: [NSLocalizedDescriptionKey: "Невозможно разобрать результаты"])
                    }

                    await MainActor.run {
                        if Task.isCancelled { return }
                        self.searchStatus = "Обработка треков..."
                    }

                    // 3. Convert collection to Tracks in parallel
                    let tracks = await Self.buildTracks(from: collection, clientId: clientId, oauth: oauthOpt) { idx, total in
                        await MainActor.run {
                            if Task.isCancelled { return }
                            self.searchStatus = "Декодирование \(idx)/\(total)..."
                        }
                    }
                    if Task.isCancelled { return }

                    await MainActor.run {
                        if Task.isCancelled { return }
                        self.searchResults = tracks
                        self.isSearching = false
                        self.searchTask = nil
                        if tracks.isEmpty {
                            self.searchStatus = "Ничего не найдено"
                        } else {
                            self.searchStatus = ""
                        }
                    }
                } catch {
                    if Task.isCancelled { return }
                    Self.log("Search error: \(error)")
                    await MainActor.run {
                        if Task.isCancelled { return }
                        self.searchResults = []
                        self.isSearching = false
                        self.searchTask = nil
                        self.searchStatus = "Ошибка: \(error.localizedDescription)"
                    }
                }
            }

        case .spotify:
            searchStatus = "Поиск в Spotify..."
            searchTask = Task {
                do {
                    let tracks = try await searchSpotify()
                    if Task.isCancelled { return }
                    await MainActor.run {
                        if Task.isCancelled { return }
                        self.searchResults = tracks
                        self.isSearching = false
                        self.searchTask = nil
                        if tracks.isEmpty {
                            self.searchStatus = "Ничего не найдено (или нет 30с превью)"
                        } else {
                            self.searchStatus = ""
                        }
                    }
                } catch {
                    if Task.isCancelled { return }
                    Self.log("Spotify search error: \(error)")
                    await MainActor.run {
                        if Task.isCancelled { return }
                        self.searchResults = []
                        self.isSearching = false
                        self.searchTask = nil
                        self.searchStatus = "Ошибка: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    private func searchSpotify() async throws -> [Track] {
        let token = normalizedSpotifyToken
        guard !token.isEmpty else {
            throw NSError(domain: "Spotify", code: 401, userInfo: [NSLocalizedDescriptionKey: "Введите токен Spotify во вкладке 'Подключения'!"])
        }

        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var comps = URLComponents(string: "https://api.spotify.com/v1/search") else {
            throw NSError(domain: "Spotify", code: 0)
        }
        comps.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "type", value: "track"),
            URLQueryItem(name: "limit", value: "25")
        ]

        guard let url = comps.url else { throw NSError(domain: "Spotify", code: 1) }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if httpResponse.statusCode == 401 {
            throw NSError(domain: "Spotify", code: 401, userInfo: [NSLocalizedDescriptionKey: "Токен Spotify истек или недействителен"])
        }

        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "Spotify", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Ошибка API Spotify (\(httpResponse.statusCode))"])
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tracksObj = json["tracks"] as? [String: Any],
              let items = tracksObj["items"] as? [[String: Any]] else {
            return []
        }

        var results: [Track] = []
        for item in items {
            guard let name = item["name"] as? String,
                  let artists = item["artists"] as? [[String: Any]],
                  let artistName = artists.first?["name"] as? String,
                  let previewUrl = item["preview_url"] as? String,
                  !previewUrl.isEmpty else {
                continue
            }

            let trackId = item["id"] as? String ?? UUID().uuidString
            let durationMs = item["duration_ms"] as? Double ?? 30000.0

            var artUrl: String?
            if let album = item["album"] as? [String: Any],
               let images = album["images"] as? [[String: Any]],
               let firstImage = images.first,
               let urlStr = firstImage["url"] as? String {
                artUrl = urlStr
            }

            results.append(Track(
                id: "spotify_search_\(trackId)",
                title: name,
                artist: artistName,
                albumArtUrl: artUrl,
                audioUrl: previewUrl,
                duration: durationMs / 1000.0
            ))
        }
        return results
    }

    // MARK: - SoundCloud higher-level helpers

    private static func fetchCollection(urlString: String, clientId: String, oauth: String?) async throws -> [[String: Any]] {
        guard var c = URLComponents(string: urlString) else { return [] }
        var queryItems = c.queryItems ?? []
        
        if !queryItems.contains(where: { $0.name == "client_id" }) {
            queryItems.append(URLQueryItem(name: "client_id", value: clientId))
        }
        if !queryItems.contains(where: { $0.name == "limit" }) {
            queryItems.append(URLQueryItem(name: "limit", value: "200"))
        }
        if !queryItems.contains(where: { $0.name == "linked_partitioning" }) {
            queryItems.append(URLQueryItem(name: "linked_partitioning", value: "1"))
        }
        
        c.queryItems = queryItems
        var nextURL = c.url
        var allItems: [[String: Any]] = []
        var pageCount = 0

        while let url = nextURL {
            if Task.isCancelled { return allItems }

            let data = try await fetchData(url: url, oauth: oauth)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let collection = json["collection"] as? [[String: Any]] else { break }

            allItems.append(contentsOf: collection)
            pageCount += 1

            guard pageCount < 25,
                  let nextHref = json["next_href"] as? String,
                  !nextHref.isEmpty,
                  var nextComponents = URLComponents(string: nextHref) else {
                nextURL = nil
                continue
            }

            var queryItems = nextComponents.queryItems ?? []
            if !queryItems.contains(where: { $0.name == "client_id" }) {
                queryItems.append(URLQueryItem(name: "client_id", value: clientId))
            }
            nextComponents.queryItems = queryItems
            nextURL = nextComponents.url
        }

        log("collection from \(urlString) size: \(allItems.count), pages: \(pageCount)")
        return allItems
    }

    /// Likes endpoint wraps the actual track in entry["track"]; flatten that out.
    private static func flattenLikes(_ entries: [[String: Any]]) -> [[String: Any]] {
        entries.compactMap { $0["track"] as? [String: Any] }
    }

    /// Flatten recommendations or charts which can have nested tracks or be clean tracks
    private static func flattenTracks(_ entries: [[String: Any]]) -> [[String: Any]] {
        entries.compactMap {
            if let track = $0["track"] as? [String: Any] {
                return track
            }
            return $0
        }
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
            if Task.isCancelled { return built }
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
        guard !isStaticTuiActive else { return }
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

        // Bulletproof fallbacks of well-known public client IDs in case scraping fails
        let fallbacks = [
            "iZsnndsk4IpT7w1k1R4t9JqU26gWcoGL",
            "2t99a7Ywng0uqZJHzerVwui7Vwt8eSpJ",
            "YUKiah45Qso1j3x49cgN8sUjL8H1zQxP"
        ]
        
        for fallbackId in fallbacks {
            log("Trying fallback SoundCloud client_id: \(fallbackId.prefix(6))…")
            var comps = URLComponents(string: "https://api-v2.soundcloud.com/resolve")!
            comps.queryItems = [
                URLQueryItem(name: "url", value: "https://soundcloud.com/pages/contact"),
                URLQueryItem(name: "client_id", value: fallbackId)
            ]
            if let testURL = comps.url, (try? await fetchData(url: testURL)) != nil {
                log("Fallback client_id is working: \(fallbackId)")
                return fallbackId
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
    
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in
                self.play()
            }
            return .success
        }
        
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in
                self.pause()
            }
            return .success
        }
        
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in
                self.togglePlayPause()
            }
            return .success
        }
        
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in
                self.nextTrack()
            }
            return .success
        }
        
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in
                self.prevTrack()
            }
            return .success
        }

        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self, let posEvent = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in
                self.seek(to: posEvent.positionTime)
            }
            return .success
        }
    }
    
    func updateNowPlayingInfo() {
        guard let track = currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyPlaybackDuration: track.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        
        if let artUrl = track.albumArtUrl, artUrl.hasPrefix("http"), let url = URL(string: artUrl) {
            Task {
                if let (data, _) = try? await URLSession.shared.data(from: url),
                   let nsImage = NSImage(data: data) {
                    let extractedColors = nsImage.dominantColors()
                    let artwork = MPMediaItemArtwork(boundsSize: nsImage.size) { _ in nsImage }
                    await MainActor.run { [weak self] in
                        guard let self = self else { return }
                        if let colors = extractedColors, self.currentTrack?.id == track.id {
                            self.currentAmbientColors = colors
                        }
                        var currentInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? info
                        currentInfo[MPMediaItemPropertyArtwork] = artwork
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = currentInfo
                    }
                }
            }
        } else {
            if let symbolImage = NSImage(systemSymbolName: track.albumArtUrl ?? "music.note", accessibilityDescription: nil) {
                let artwork = MPMediaItemArtwork(boundsSize: symbolImage.size) { _ in symbolImage }
                info[MPMediaItemPropertyArtwork] = artwork
            }
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func setupVisualizerTimer() {
        // 60 FPS for buttery-smooth spring-driven spectrum
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if Thread.isMainThread {
                MainActor.assumeIsolated {
                    self.updateVisualizerPhysics()
                }
            } else {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    MainActor.assumeIsolated {
                        self.updateVisualizerPhysics()
                    }
                }
            }
        }
        // Use common modes so it keeps ticking during scrolls / drags
        RunLoop.main.add(timer, forMode: .common)
        visualizerTimer = timer
    }
    
    private func updateVisualizerPhysics() {
        let count = visualizerBars.count
        var tempBars = visualizerBars
        
        if !isPlaying {
            var allNearZero = true
            for i in 0..<count {
                tempBars[i] = tempBars[i] * 0.80 // Smooth exponential decay
                velocities[i] = 0.0
                targetBars[i] = 0.0
                if tempBars[i] > 0.001 {
                    allNearZero = false
                } else {
                    tempBars[i] = 0.0
                }
            }
            visualizerBars = tempBars
            if allNearZero {
                printTerminalVisualizer(force: true)
                return // Avoid redundant calculations when fully decayed
            }
        } else {
            // Seed a deterministic song fingerprint based on track ID or title
            let trackSeed = Double(abs((currentTrack?.id ?? "default").hashValue % 1000)) / 1000.0
            
            // Derive a unique tempo (BPM) and rhythm offset for this specific song
            let bpm = 110.0 + trackSeed * 50.0 // Unique BPM between 110 and 160
            let secondsPerBeat = 60.0 / bpm
            let currentBeat = currentTime / secondsPerBeat
            let beatFraction = currentBeat.truncatingRemainder(dividingBy: 1.0)
            
            // Rhythmic envelopes that mimic highly accurate audio frequency bands
            // 1. Bass / Kick Drum Envelope: hits heavy on the integer beats (fraction 0) and decays rapidly
            let kickEnvelope = exp(-7.5 * beatFraction)
            let subBassEnvelope = exp(-3.5 * beatFraction) * 0.45
            let bassPulse = kickEnvelope + subBassEnvelope
            
            // 2. Mid / Snare Envelope: hits sharp on beats 2 and 4 (odd beat index) + off-beat syncopation on eighth notes
            let isSnareBeat = Int(currentBeat) % 2 == 1
            let snareEnvelope = isSnareBeat ? exp(-9.0 * beatFraction) : 0.0
            let offbeatMid = exp(-11.0 * abs(beatFraction - 0.5)) * 0.35
            let midPulse = snareEnvelope + offbeatMid
            
            // 3. Treble / Hi-Hats: fast sixteenth-note transients and eighth-note off-beats
            let offbeatHat = exp(-14.0 * abs(beatFraction - 0.5))
            let sixteenthHat1 = exp(-18.0 * abs(beatFraction - 0.25))
            let sixteenthHat2 = exp(-18.0 * abs(beatFraction - 0.75))
            let treblePulse = max(offbeatHat * 0.65, max(sixteenthHat1 * 0.45, sixteenthHat2 * 0.45))
            
            // Dynamic phase based on currentTime for organic background movement
            let timeFactor = currentTime
            
            for i in 0..<count {
                let indexFactor = Double(i) / Double(count)
                var amplitude = 0.0
                
                if i < count / 4 {
                    // Bass section (kick drum + deep organic wobble)
                    let bassOscillation = sin(timeFactor * 3.5 + trackSeed * 10.0) * 0.12
                    amplitude = (bassPulse * 0.75 + 0.15 + bassOscillation) * (1.0 - indexFactor) * 1.25
                } else if i < count * 3 / 4 {
                    // Mid frequencies (snare + active harmony wave)
                    let midOscillation = cos(timeFactor * 2.2 + Double(i) * 0.25 + trackSeed * 5.0) * 0.15
                    amplitude = (midPulse * 0.68 + 0.20 + midOscillation) * 0.95
                } else {
                    // Treble frequencies (crisp hi-hat ticks + ambient air)
                    let trebleOscillation = sin(timeFactor * 4.5 - Double(i) * 0.5 + trackSeed * 8.0) * 0.10
                    amplitude = (treblePulse * 0.72 + 0.12 + trebleOscillation) * indexFactor * 1.35
                }
                
                // Add micro-noise transients that trigger deterministically in the song timeline for hi-hat/snare sizzle
                let transientTrigger = sin(timeFactor * 14.0 + trackSeed * 3.0)
                if transientTrigger > 0.85 && i > count * 2 / 3 {
                    amplitude += 0.22 * (transientTrigger - 0.85)
                }
                
                // Add tiny organic dynamic noise to keep it lively
                let noise = Double.random(in: -0.04...0.04)
                amplitude = max(0.0, min(1.0, amplitude + noise))
                
                // Scale target amplitude by a full constant factor instead of the volume level,
                // so that the visualizer reacts perfectly to the beat and rhythm regardless of volume/mute.
                targetBars[i] = min(1.0, amplitude * 1.45)
            }
            
            // Smooth but snappy physics-based spring interpolation
            let stiffness = 0.28 // Snappier response (was 0.22)
            let damping = 0.70   // Allows small realistic micro-bounces (was 0.76)
            
            for i in 0..<count {
                let displacement = targetBars[i] - tempBars[i]
                let force = displacement * stiffness
                
                velocities[i] = velocities[i] * damping + force
                tempBars[i] = max(0.0, tempBars[i] + velocities[i])
            }
            visualizerBars = tempBars
        }
        printTerminalVisualizer()
    }

    private func printTerminalVisualizer(force: Bool = false) {
        guard !isTuiActive else { return }
        terminalTickCounter += 1
        guard force || (terminalTickCounter % 3 == 0) else { return }
        
        let height = 8
        let barsCount = visualizerBars.count
        
        var lines: [String] = []
        
        lines.append("") // top padding
        
        for r in (0..<height).reversed() {
            var rowStr = "  "
            let threshold = Double(r) / Double(height)
            
            for col in 0..<barsCount {
                let val = visualizerBars[col]
                let char: String
                if val >= threshold + 0.05 {
                    char = "█"
                } else if val >= threshold {
                    char = "▄"
                } else {
                    char = " "
                }
                
                let colorCode: String
                if col < 9 {
                    colorCode = "\u{001B}[38;5;45m" // cyan
                } else if col < 18 {
                    colorCode = "\u{001B}[38;5;99m" // indigo/purple
                } else {
                    colorCode = "\u{001B}[38;5;200m" // magenta/pink
                }
                rowStr += colorCode + char
            }
            rowStr += "\u{001B}[0m"
            lines.append(rowStr)
        }
        lines.append("") // bottom padding
        
        var output = ""
        let totalLines = lines.count
        
        if hasPrintedTerminalVisualizer {
            output += "\u{001B}[\(totalLines)A"
        } else {
            hasPrintedTerminalVisualizer = true
        }
        
        for line in lines {
            output += line + "\u{001B}[K\n"
        }
        
        print(output, terminator: "")
        fflush(stdout)
    }
}

// MARK: - Premium Color Extraction from Album Art
extension NSImage {
    func dominantColors() -> [Color]? {
        let targetSize = NSSize(width: 8, height: 8)
        guard let tiff = self.tiffRepresentation,
              let _ = NSBitmapImageRep(data: tiff) else { return nil }
              
        guard let smallRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 8,
            pixelsHigh: 8,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }
        
        NSGraphicsContext.saveGraphicsState()
        let context = NSGraphicsContext(bitmapImageRep: smallRep)
        NSGraphicsContext.current = context
        
        self.draw(in: NSRect(origin: .zero, size: targetSize),
                  from: NSRect(origin: .zero, size: self.size),
                  operation: .copy,
                  fraction: 1.0)
                  
        NSGraphicsContext.restoreGraphicsState()
        
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, count1 = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, count2 = 0
        
        for y in 0..<8 {
            for x in 0..<8 {
                guard let color = smallRep.colorAt(x: x, y: y) else { continue }
                let r = color.redComponent
                let g = color.greenComponent
                let b = color.blueComponent
                
                // Sample different spatial regions (top-left vs bottom-right)
                if x + y < 7 {
                    r1 += r
                    g1 += g
                    b1 += b
                    count1 += 1
                } else {
                    r2 += r
                    g2 += g
                    b2 += b
                    count2 += 1
                }
            }
        }
        
        if count1 > 0 && count2 > 0 {
            let finalColor1 = Color(red: r1 / CGFloat(count1), green: g1 / CGFloat(count1), blue: b1 / CGFloat(count1))
            let finalColor2 = Color(red: r2 / CGFloat(count2), green: g2 / CGFloat(count2), blue: b2 / CGFloat(count2))
            return [finalColor1, finalColor2]
        }
        
        return nil
    }
}
