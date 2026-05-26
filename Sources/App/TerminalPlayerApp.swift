import Foundation
import Darwin
import AVFoundation
import SwiftUI

@MainActor
final class TerminalPlayerApp {
    private let viewModel: PlayerViewModel
    private var termiosOriginal: termios
    private var isRawModeActive = false
    
    // TUI Navigation / Layout State
    private enum ActivePane {
        case albums
        case tracks
        case player
    }
    
    private enum PopupState {
        case none
        case addToPlaylist(track: Track)
    }
    
    private enum InputMode {
        case normal
        case searchInput(query: String)
        case playlistCreateInput(name: String)
    }
    
    private var focusedPane: ActivePane = .albums
    private var selectedAlbumIndex = 0
    private var selectedTrackIndex = 0
    
    private var popupState: PopupState = .none
    private var selectedPopupIndex = 0
    
    private var inputMode: InputMode = .normal
    private var searchSource: SearchSource = .soundCloud
    private var showOptions = false
    
    private var lastWidth = 0
    private var lastHeight = 0
    
    // Helper: unified list of all albums and playlists, plus search results if present
    private var allAlbums: [Album] {
        var list = viewModel.albums
        if !viewModel.searchResults.isEmpty {
            list.append(viewModel.searchAlbum)
        }
        return list
    }
    
    private var selectedAlbum: Album? {
        let albums = allAlbums
        guard selectedAlbumIndex >= 0 && selectedAlbumIndex < albums.count else {
            return albums.first
        }
        return albums[selectedAlbumIndex]
    }
    
    init(viewModel: PlayerViewModel) {
        self.viewModel = viewModel
        self.termiosOriginal = termios()
        tcgetattr(STDIN_FILENO, &self.termiosOriginal)
    }
    
    func run() {
        print("\u{001B}[?25l", terminator: "") // Hide cursor
        print("\u{001B}[2J\u{001B}[H", terminator: "") // Clear screen, cursor to home
        fflush(stdout)
        
        // Show splash screen
        showSplashScreen()
        
        enableRawMode()
        viewModel.isTuiActive = true
        PlayerViewModel.isStaticTuiActive = true
        
        // Start background input capturer thread
        startInputThread()
        
        // Main TUI render loop at ~25 FPS
        let renderTimer = Timer(timeInterval: 1.0 / 25.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.drawDashboard()
            }
        }
        RunLoop.main.add(renderTimer, forMode: .common)
        
        // Preload first track if needed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                if self.viewModel.currentTrack == nil {
                    if let firstAlbum = self.viewModel.albums.first,
                       let firstTrack = firstAlbum.tracks.first {
                        self.viewModel.loadTrack(firstTrack, in: firstAlbum, seekTo: 0.0)
                    }
                }
            }
        }
    }
    
    private func shutdown() {
        disableRawMode()
        print("\u{001B}[?25h", terminator: "") // Show cursor
        print("\u{001B}[2J\u{001B}[H", terminator: "") // Clear screen on exit
        print("Aferapokitaysky Media Player stopped. До свидания!\n")
        fflush(stdout)
        exit(0)
    }
    
    // MARK: - Splash Screen with new Block Art
    private func showSplashScreen() {
        let size = getTerminalSize()
        let width = size.width
        let height = size.height
        
        if height < 44 {
            let compactArt = [
                "        _                       ",
                "   __ _| |_ ___ _ _ __ _   _ __ ",
                "  / _` |  _/ -_) '_/ _` | | '_ \\",
                "  \\__,_|\\__\\___|_| \\__,_| | .__/",
                "                          |_|   "
            ]
            let padX = max(0, (width - 32) / 2)
            let padStr = String(repeating: " ", count: padX)
            var out = "\n\n"
            for (idx, line) in compactArt.enumerated() {
                let colorCode = idx < 2 ? "\u{001B}[38;5;208m" : "\u{001B}[38;5;201m"
                out += padStr + colorCode + line + "\u{001B}[0m\n"
            }
            out += "\n"
            let text = "⚡ A F E R A   P L A Y E R   L O A D I N G . . ."
            let padText = max(0, (width - text.count) / 2)
            out += String(repeating: " ", count: padText) + "\u{001B}[38;5;45m" + text + "\u{001B}[0m\n"
            print(out)
            fflush(stdout)
            Thread.sleep(forTimeInterval: 1.0)
            print("\u{001B}[2J\u{001B}[H", terminator: "")
            fflush(stdout)
            return
        }
        
        let art = [
            "                             ▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇                            ",
            "                       ▇▇▇▇▇▇▇▇▇         ▇▇▇▇▇▇▇▇▇                      ",
            "                   ▇▇▇▇▇▇                       ▇▇▇▇▇                   ",
            "                ▇▇▇▇▇                               ▇▇▇▇                ",
            "              ▇▇▇▇                                     ▇▇▇▇             ",
            "            ▇▇▇                                          ▇▇▇▇           ",
            "          ▇▇▇                                              ▇▇▇▇         ",
            "        ▇▇▇                     ▇▇▇▇▇                        ▇▇▇        ",
            "       ▇▇▇                      ▇▇ ▇▇                          ▇▇       ",
            "      ▇▇                        ▇▇  ▇▇                          ▇▇▇     ",
            "     ▇▇                         ▇▇   ▇▇▇                         ▇▇▇    ",
            "    ▇▇                          ▇▇ ▇▇▇▇▇▇▇▇▇▇                     ▇▇    ",
            "   ▇▇                           ▇▇ ▇▇                              ▇▇   ",
            "  ▇▇▇                           ▇▇ ▇▇▇▇                             ▇▇  ",
            "  ▇▇                            ▇▇   ▇▇▇▇▇                          ▇▇▇ ",
            " ▇▇                ▇▇▇▇▇▇▇▇▇    ▇▇      ▇▇▇▇▇                        ▇▇ ",
            " ▇▇              ▇▇▇      ▇▇▇   ▇▇         ▇▇▇▇▇                     ▇▇ ",
            " ▇▇                        ▇▇▇  ▇▇            ▇▇▇▇▇                  ▇▇▇",
            "▇▇                  ▇▇▇▇▇▇ ▇▇▇  ▇▇               ▇▇▇▇                 ▇▇",
            "▇▇               ▇▇▇▇      ▇▇▇  ▇▇       ▇▇▇        ▇▇▇▇              ▇▇",
            "▇▇              ▇▇▇        ▇▇▇  ▇▇     ▇▇▇ ▇▇▇        ▇▇              ▇▇",
            "▇▇              ▇▇        ▇▇▇▇  ▇▇    ▇▇           ▇▇▇▇               ▇▇",
            "▇▇▇              ▇▇     ▇▇▇▇▇▇  ▇▇    ▇▇        ▇▇▇▇▇                ▇▇▇",
            " ▇▇               ▇▇▇▇▇▇▇  ▇▇▇  ▇▇    ▇▇      ▇▇▇▇                   ▇▇ ",
            " ▇▇                        ▇▇▇  ▇▇    ▇▇   ▇▇▇▇                      ▇▇ ",
            " ▇▇▇                 ▇▇▇▇▇▇▇▇▇  ▇▇    ▇▇ ▇▇▇                        ▇▇▇ ",
            "  ▇▇               ▇▇▇          ▇▇    ▇▇                            ▇▇  ",
            "   ▇▇              ▇▇           ▇▇    ▇▇                           ▇▇▇  ",
            "   ▇▇▇            ▇▇▇          ▇▇▇    ▇▇                          ▇▇▇   ",
            "    ▇▇▇            ▇▇▇        ▇▇▇     ▇▇                         ▇▇▇    ",
            "     ▇▇▇            ▇▇▇▇▇▇▇▇▇▇▇       ▇▇                        ▇▇▇     ",
            "      ▇▇▇               ▇▇▇           ▇▇                       ▇▇▇      ",
            "        ▇▇                            ▇▇                      ▇▇        ",
            "         ▇▇▇                          ▇▇                    ▇▇▇         ",
            "           ▇▇▇                                            ▇▇▇           ",
            "             ▇▇▇                                        ▇▇▇             ",
            "                ▇▇▇                                  ▇▇▇▇               ",
            "                  ▇▇▇▇                            ▇▇▇▇                  ",
            "                      ▇▇▇▇▇                   ▇▇▇▇                      ",
            "                           ▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇                           "
        ]
        
        var output = "\n"
        let padX = max(0, (width - 80) / 2)
        let padStr = String(repeating: " ", count: padX)
        
        for (idx, line) in art.enumerated() {
            let ratio = Double(idx) / Double(art.count)
            let colorIndex: Int
            if ratio < 0.25 {
                colorIndex = 208
            } else if ratio < 0.50 {
                colorIndex = 202
            } else if ratio < 0.75 {
                colorIndex = 201
            } else {
                colorIndex = 198
            }
            output += padStr + "\u{001B}[38;5;\(colorIndex)m" + line + "\u{001B}[0m\n"
        }
        
        output += "\n"
        let statusText = "⚡  A F E R A P O K I T A Y S K Y   M E D I A   S Y S T E M   L O A D I N G . . ."
        let padText = max(0, (width - statusText.count) / 2)
        output += String(repeating: " ", count: padText) + "\u{001B}[1;38;5;208m" + statusText + "\u{001B}[0m\n"
        
        print(output)
        fflush(stdout)
        
        Thread.sleep(forTimeInterval: 1.5)
        print("\u{001B}[2J\u{001B}[H", terminator: "")
        fflush(stdout)
    }
    
    // MARK: - Termios Raw Mode Input
    private func enableRawMode() {
        var raw = termiosOriginal
        raw.c_lflag &= ~tcflag_t(ECHO | ICANON | ISIG)
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw)
        isRawModeActive = true
    }
    
    private func disableRawMode() {
        guard isRawModeActive else { return }
        var original = termiosOriginal
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &original)
        isRawModeActive = false
    }
    
    private func startInputThread() {
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            while true {
                guard let self = self else { break }
                let bytes = self.readRawInput()
                if !bytes.isEmpty {
                    Task { @MainActor in
                        self.handleRawInput(bytes)
                    }
                }
            }
        }
    }
    
    nonisolated private func readRawInput() -> [UInt8] {
        var char: UInt8 = 0
        var bytes = [UInt8]()
        let bytesRead = read(STDIN_FILENO, &char, 1)
        
        if bytesRead > 0 {
            bytes.append(char)
            if char == 27 { // Escape indicator
                let flags = fcntl(STDIN_FILENO, F_GETFL)
                _ = fcntl(STDIN_FILENO, F_SETFL, flags | O_NONBLOCK)
                
                var nextByte: UInt8 = 0
                while read(STDIN_FILENO, &nextByte, 1) > 0 {
                    bytes.append(nextByte)
                }
                
                _ = fcntl(STDIN_FILENO, F_SETFL, flags)
            }
        }
        return bytes
    }
    
    // MARK: - Input State Machine
    private func handleRawInput(_ bytes: [UInt8]) {
        guard !bytes.isEmpty else { return }
        
        // 1. Text Entry Mode handling
        switch inputMode {
        case .searchInput(let query):
            handleSearchInput(bytes, query: query)
            return
        case .playlistCreateInput(let name):
            handlePlaylistCreateInput(bytes, name: name)
            return
        case .normal:
            break
        }
        
        // 2. Add to Playlist Popup handling
        if case .addToPlaylist(let track) = popupState {
            handlePopupInput(bytes, track: track)
            return
        }
        
        // 3. Normal TUI Controls
        if bytes.count == 1 {
            let key = bytes[0]
            switch key {
            case 9: // Tab key
                cycleFocus()
            case 32: // Space
                viewModel.togglePlayPause()
            case 112, 80: // 'p' or 'P'
                viewModel.togglePlayPause()
            case 110, 78: // 'n' or 'N'
                viewModel.nextTrack()
            case 98, 66: // 'b' or 'B'
                viewModel.prevTrack()
            case 115, 83: // 's' or 'S'
                viewModel.isShuffle.toggle()
            case 114, 82: // 'r' or 'R'
                viewModel.isRepeat.toggle()
            case 116, 84: // 't' or 'T' - Theme toggle
                ThemeManager.shared.toggle()
            case 111, 79: // 'o' or 'O' - Settings/Options view toggle
                showOptions.toggle()
            case 47: // '/' key - trigger Search
                inputMode = .searchInput(query: "")
            case 99, 67: // 'c' or 'C' - Create playlist (only when albums focused)
                if focusedPane == .albums {
                    inputMode = .playlistCreateInput(name: "")
                }
            case 97, 65: // 'a' or 'A' - Add active track to playlist (only tracks focused)
                if focusedPane == .tracks, let selAlbum = selectedAlbum, !selAlbum.tracks.isEmpty {
                    let track = selAlbum.tracks[selectedTrackIndex]
                    popupState = .addToPlaylist(track: track)
                    selectedPopupIndex = 0
                }
            case 127: // Backspace
                handleDeletion()
            case 13: // Enter
                handleEnterKey()
            case 113, 81: // 'q' or 'Q'
                shutdown()
            default:
                break
            }
        } else if bytes.count >= 3 && bytes[0] == 27 && bytes[1] == 91 {
            let code = bytes[2]
            switch code {
            case 65: // Up Arrow
                navigateUp()
            case 66: // Down Arrow
                navigateDown()
            case 67: // Right Arrow
                navigateRight()
            case 68: // Left Arrow
                navigateLeft()
            default:
                break
            }
        } else if bytes.count == 1 && bytes[0] == 27 {
            shutdown()
        }
    }
    
    // MARK: - Input State Handlers
    private func handleSearchInput(_ bytes: [UInt8], query: String) {
        if bytes.count == 1 {
            let key = bytes[0]
            if key == 13 { // Enter
                viewModel.searchQuery = query
                viewModel.searchSource = searchSource
                viewModel.executeSearch()
                inputMode = .normal
                // Focus on search results
                if let searchAlbumIdx = allAlbums.firstIndex(where: { $0.id == "search" }) {
                    selectedAlbumIndex = searchAlbumIdx
                    focusedPane = .tracks
                    selectedTrackIndex = 0
                }
            } else if key == 27 { // Escape
                inputMode = .normal
            } else if key == 127 { // Backspace
                if !query.isEmpty {
                    inputMode = .searchInput(query: String(query.dropLast()))
                }
            } else if key == 9 { // Tab toggles SoundCloud/Spotify source
                searchSource = (searchSource == .soundCloud) ? .spotify : .soundCloud
            } else if key >= 32 && key <= 126 { // Printable character
                let scalar = UnicodeScalar(key)
                inputMode = .searchInput(query: query + String(scalar))
            }
        }
    }
    
    private func handlePlaylistCreateInput(_ bytes: [UInt8], name: String) {
        if bytes.count == 1 {
            let key = bytes[0]
            if key == 13 { // Enter
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    _ = viewModel.createLocalPlaylist(named: trimmed)
                    // Reset to newly created playlist
                    if let newIdx = allAlbums.firstIndex(where: { $0.name == trimmed }) {
                        selectedAlbumIndex = newIdx
                    }
                }
                inputMode = .normal
            } else if key == 27 { // Escape
                inputMode = .normal
            } else if key == 127 { // Backspace
                if !name.isEmpty {
                    inputMode = .playlistCreateInput(name: String(name.dropLast()))
                }
            } else if key >= 32 && key <= 126 { // Printable character
                let scalar = UnicodeScalar(key)
                inputMode = .playlistCreateInput(name: name + String(scalar))
            }
        }
    }
    
    private func handlePopupInput(_ bytes: [UInt8], track: Track) {
        let playlists = viewModel.localPlaylists
        guard !playlists.isEmpty else {
            popupState = .none
            return
        }
        
        if bytes.count == 1 {
            let key = bytes[0]
            if key == 13 { // Enter
                let playlist = playlists[selectedPopupIndex]
                viewModel.addTrack(track, toLocalPlaylist: playlist.id)
                popupState = .none
            } else if key == 27 { // Escape
                popupState = .none
            }
        } else if bytes.count >= 3 && bytes[0] == 27 && bytes[1] == 91 {
            let code = bytes[2]
            if code == 65 { // Up
                if selectedPopupIndex > 0 { selectedPopupIndex -= 1 }
            } else if code == 66 { // Down
                if selectedPopupIndex < playlists.count - 1 { selectedPopupIndex += 1 }
            }
        }
    }
    
    private func handleDeletion() {
        if focusedPane == .albums {
            let albums = allAlbums
            guard selectedAlbumIndex >= 0 && selectedAlbumIndex < albums.count else { return }
            let album = albums[selectedAlbumIndex]
            if album.kind == .custom && album.id.hasPrefix("local_") {
                viewModel.deleteAlbumLocally(album.id)
                selectedAlbumIndex = max(0, selectedAlbumIndex - 1)
            }
        } else if focusedPane == .tracks {
            guard let album = selectedAlbum, album.kind == .custom && album.id.hasPrefix("local_") else { return }
            guard selectedTrackIndex >= 0 && selectedTrackIndex < album.tracks.count else { return }
            let track = album.tracks[selectedTrackIndex]
            viewModel.deleteTrackLocally(track.id, from: album.id)
            selectedTrackIndex = max(0, selectedTrackIndex - 1)
        }
    }
    
    private func handleEnterKey() {
        if focusedPane == .albums {
            // Select and load album
            if let album = selectedAlbum {
                viewModel.selectedAlbumId = album.id
                focusedPane = .tracks
                selectedTrackIndex = 0
            }
        } else if focusedPane == .tracks {
            // Play highlighted track
            if let album = selectedAlbum, !album.tracks.isEmpty {
                let track = album.tracks[selectedTrackIndex]
                viewModel.playTrack(track, in: album)
            }
        }
    }
    
    // MARK: - Navigation Control
    private func cycleFocus() {
        switch focusedPane {
        case .albums: focusedPane = .tracks
        case .tracks: focusedPane = .player
        case .player: focusedPane = .albums
        }
    }
    
    private func navigateUp() {
        if focusedPane == .albums {
            if selectedAlbumIndex > 0 { selectedAlbumIndex -= 1 }
        } else if focusedPane == .tracks {
            if selectedTrackIndex > 0 { selectedTrackIndex -= 1 }
        } else if focusedPane == .player {
            viewModel.volume = min(1.0, viewModel.volume + 0.05)
        }
    }
    
    private func navigateDown() {
        if focusedPane == .albums {
            if selectedAlbumIndex < allAlbums.count - 1 { selectedAlbumIndex += 1 }
        } else if focusedPane == .tracks {
            if let tracks = selectedAlbum?.tracks, selectedTrackIndex < tracks.count - 1 {
                selectedTrackIndex += 1
            }
        } else if focusedPane == .player {
            viewModel.volume = max(0.0, viewModel.volume - 0.05)
        }
    }
    
    private func navigateLeft() {
        switch focusedPane {
        case .albums:
            break
        case .tracks:
            focusedPane = .albums
        case .player:
            focusedPane = .tracks
        }
    }
    
    private func navigateRight() {
        switch focusedPane {
        case .albums:
            focusedPane = .tracks
        case .tracks:
            focusedPane = .player
        case .player:
            break
        }
    }
    
    // MARK: - Terminal Rendering Dashboard
    private func getTerminalSize() -> (width: Int, height: Int) {
        var w = winsize()
        if ioctl(STDOUT_FILENO, TIOCGWINSZ, &w) == 0 {
            return (Int(w.ws_col), Int(w.ws_row))
        }
        return (80, 24)
    }
    
    private func drawDashboard() {
        let size = getTerminalSize()
        let width = size.width
        let height = size.height
        
        if width != lastWidth || height != lastHeight {
            print("\u{001B}[2J", terminator: "")
            lastWidth = width
            lastHeight = height
        }
        
        var output = "\u{001B}[H" // Jump home
        
        // Unify theme configuration
        let isLight = ThemeManager.shared.theme == .light
        let appTitle = isLight ? "⚡ A F E R A P O K I T A Y S K Y" : "⚡ A F E R A   S Y N T H   S Y S T E M"
        let borderGlow = isLight ? "\u{001B}[38;5;25m" : "\u{001B}[38;5;82m" // blue or neon green
        let defaultBorder = isLight ? "\u{001B}[38;5;248m" : "\u{001B}[38;5;240m"
        
        // 1. Draw App Title Header (exactly 2 lines total)
        let pad = max(0, (width - appTitle.count) / 2)
        let themeIndicator = isLight ? "[LIGHT]" : "[SYNTH]"
        output += String(repeating: " ", count: pad) + "\u{001B}[1;38;5;201m" + appTitle + "\u{001B}[0m  \(themeIndicator)\u{001B}[K\n"
        output += "\u{001B}[K\n"
        
        // 2. Render content based on terminal width (takes exactly height - 8 lines)
        if width >= 100 && height >= 24 {
            output += drawSplitDashboard(width: width, height: height, isLight: isLight, glowColor: borderGlow, normalColor: defaultBorder)
        } else {
            output += drawCompactDashboard(width: width, height: height, isLight: isLight)
        }
        
        // 3. Draw Stdin queries / popups / options if active (takes exactly 3 lines)
        output += drawInputAndOverlays(width: width)
        
        // 4. Draw Command Footer (takes exactly 3 lines)
        output += drawFooter(width: width)
        
        print(output, terminator: "")
        fflush(stdout)
    }
    
    // MARK: - Responsive Split View Panel
    private func drawSplitDashboard(width: Int, height: Int, isLight: Bool, glowColor: String, normalColor: String) -> String {
        let contentHeight = height - 13 // pane content rows
        
        let col1W = 24
        let col2W = 30
        let col3W = max(36, width - col1W - col2W - 10)
        
        let col1Lines = getAlbumsPane(width: col1W, height: contentHeight, glow: glowColor, normal: normalColor)
        let col2Lines = getTracksPane(width: col2W, height: contentHeight, glow: glowColor, normal: normalColor)
        let col3Lines = getPlayerPane(width: col3W, height: contentHeight, glow: glowColor, normal: normalColor, isLight: isLight)
        
        var res = ""
        let maxLines = contentHeight + 2 // exactly height - 11 lines!
        
        for i in 0..<maxLines {
            let c1 = i < col1Lines.count ? col1Lines[i] : String(repeating: " ", count: col1W + 2)
            let c2 = i < col2Lines.count ? col2Lines[i] : String(repeating: " ", count: col2W + 2)
            let c3 = i < col3Lines.count ? col3Lines[i] : String(repeating: " ", count: col3W + 2)
            res += c1 + " " + c2 + " " + c3 + "\u{001B}[K\n"
        }
        
        return res
    }
    
    // MARK: - Compact Screen Layout
    private func drawCompactDashboard(width: Int, height: Int, isLight: Bool) -> String {
        var res = ""
        let hudHeight = height < 20 ? 4 : 5
        res += drawHUD(width: width, isCompact: height < 20)
        
        let listHeight = height - hudHeight - 11
        if focusedPane == .tracks || focusedPane == .albums {
            res += drawPlaylistBrowser(width: width, height: listHeight)
        } else {
            res += drawVisualizer(width: width, height: listHeight)
        }
        return res
    }
    
    // MARK: - Album Pane (Col 1)
    private func getAlbumsPane(width: Int, height: Int, glow: String, normal: String) -> [String] {
        var lines: [String] = []
        let active = focusedPane == .albums
        let border = active ? glow : normal
        
        lines.append(getHeader(title: "БИБЛИОТЕКА", width: width, border: border))
        
        let albums = allAlbums
        let maxDisplay = height
        
        for i in 0..<maxDisplay {
            if i < albums.count {
                let album = albums[i]
                let isSelected = i == selectedAlbumIndex
                
                // Formulate icon prefix based on kind
                let icon: String
                switch album.kind {
                case .demo: icon = "💿"
                case .custom: icon = "📁"
                case .spotify: icon = "🟢"
                case .likes: icon = "❤️"
                case .uploads: icon = "📤"
                case .playlist: icon = "♫"
                }
                
                let text = " \(icon) \(album.name)"
                let formatted = text.count > width ? String(text.prefix(width - 3)) + ".." : text
                
                if isSelected {
                    let cleanText = "\u{001B}[7;38;5;208m" + formatted + "\u{001B}[0m"
                    lines.append(getLine(content: cleanText, width: width, border: border))
                } else {
                    lines.append(getLine(content: formatted, width: width, border: border))
                }
            } else {
                lines.append(getLine(content: "", width: width, border: border))
            }
        }
        
        lines.append(getFooter(width: width, border: border))
        return lines
    }
    
    // MARK: - Tracks Pane (Col 2)
    private func getTracksPane(width: Int, height: Int, glow: String, normal: String) -> [String] {
        var lines: [String] = []
        let active = focusedPane == .tracks
        let border = active ? glow : normal
        
        let albumName = selectedAlbum?.name ?? "ТРЕКИ"
        lines.append(getHeader(title: String(albumName.prefix(width - 4)), width: width, border: border))
        
        let maxDisplay = height
        let tracks = selectedAlbum?.tracks ?? []
        
        for i in 0..<maxDisplay {
            if i < tracks.count {
                let track = tracks[i]
                let isSelected = i == selectedTrackIndex
                let isPlaying = track.id == viewModel.currentTrack?.id
                
                let symbol = isPlaying ? "▶" : " "
                let trackStr = " \(symbol) [\(i+1)] \(track.title) - \(track.artist)"
                let formatted = trackStr.count > width ? String(trackStr.prefix(width - 2)) + ".." : trackStr
                
                if isSelected {
                    let focusText = "\u{001B}[7;38;5;45m" + formatted + "\u{001B}[0m"
                    lines.append(getLine(content: focusText, width: width, border: border))
                } else {
                    let itemColor = isPlaying ? "\u{001B}[38;5;82m" : ""
                    let cleanText = itemColor + formatted + (isPlaying ? "\u{001B}[0m" : "")
                    lines.append(getLine(content: cleanText, width: width, border: border))
                }
            } else {
                lines.append(getLine(content: "", width: width, border: border))
            }
        }
        
        lines.append(getFooter(width: width, border: border))
        return lines
    }
    
    // MARK: - Player & Visualizer Pane (Col 3)
    private func getPlayerPane(width: Int, height: Int, glow: String, normal: String, isLight: Bool) -> [String] {
        var lines: [String] = []
        let active = focusedPane == .player
        let border = active ? glow : normal
        
        lines.append(getHeader(title: "СИСТЕМА", width: width, border: border))
        
        // Dynamic block logo based on available height (height is contentHeight)
        let logo: [String]
        let baseLogoWidth: Int
        if height >= 21 {
            baseLogoWidth = 38
            logo = [
                "            ▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇           ",
                "       ▇▇▇▇▇▇▇           ▇▇▇▇▇▇▇      ",
                "     ▇▇▇                      ▇▇▇▇    ",
                "   ▇▇▇           ▇▇▇▇           ▇▇▇▇  ",
                "  ▇▇             ▇▇▇▇▇▇▇          ▇▇  ",
                " ▇▇              ▇▇▇▇▇▇            ▇▇▇",
                " ▇       ▇▇▇▇▇▇▇ ▇   ▇▇▇▇▇          ▇▇",
                "▇▇       ▇▇▇▇▇▇▇ ▇    ▇▇▇▇▇▇▇▇      ▇▇",
                "▇▇      ▇▇▇   ▇▇ ▇  ▇▇▇▇▇  ▇▇▇       ▇",
                "▇▇       ▇▇▇▇▇▇▇ ▇  ▇▇ ▇▇▇▇▇        ▇▇",
                " ▇▇       ▇▇▇▇▇▇ ▇  ▇▇▇▇            ▇▇",
                "  ▇▇      ▇▇    ▇▇  ▇▇            ▇▇▇ ",
                "   ▇▇      ▇▇▇▇▇▇   ▇▇           ▇▇▇  ",
                "    ▇▇▇▇            ▇▇         ▇▇▇    ",
                "       ▇▇▇▇                 ▇▇▇▇      ",
                "          ▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇         "
            ]
        } else if height >= 12 {
            baseLogoWidth = 32
            logo = [
                "        _                       ",
                "   __ _| |_ ___ _ _ __ _   _ __ ",
                "  / _` |  _/ -_) '_/ _` | | '_ \\",
                "  \\__,_|\\__\\___|_| \\__,_| | .__/",
                "                          |_|   "
            ]
        } else {
            baseLogoWidth = 32
            logo = [
                "       ⚡ A F E R A   S Y N T H  "
            ]
        }
        
        // Pad the logo lines dynamically to exactly match column content width
        let logoPad = max(0, (width - baseLogoWidth) / 2)
        let logoPadStr = String(repeating: " ", count: logoPad)
        let rightLogoPad = max(0, width - logoPad - baseLogoWidth)
        let rightLogoPadStr = String(repeating: " ", count: rightLogoPad)
        
        // Since players have a fixed set of logo + data, fill the rest with empty space to match height!
        let logoCount = logo.count
        let remainingRows = height - logoCount - 5 // exact budget
        
        for idx in 0..<logoCount {
            let colorIndex: Int
            let ratio = Double(idx) / Double(logo.count)
            if ratio < 0.25 { colorIndex = 208 }
            else if ratio < 0.5 { colorIndex = 202 }
            else if ratio < 0.75 { colorIndex = 201 }
            else { colorIndex = 198 }
            
            let logoLine = logoPadStr + "\u{001B}[38;5;\(colorIndex)m" + logo[idx] + "\u{001B}[0m" + rightLogoPadStr
            lines.append(getLine(content: logoLine, width: width, border: border))
        }
        
        let titleText: String
        let artistText: String
        if let track = viewModel.currentTrack {
            titleText = track.title
            artistText = track.artist
        } else {
            titleText = "Нет трека"
            artistText = "Aferapokitaysky"
        }
        
        let volPercent = Int(viewModel.volume * 100)
        let shuff = viewModel.isShuffle ? "ON" : "OFF"
        let rep = viewModel.isRepeat ? "ON" : "OFF"
        let playState = viewModel.isPlaying ? "▶ PLAYING" : "Ⅱ PAUSED"
        
        lines.append(getLine(content: String(repeating: "─", count: width), width: width, border: border))
        
        let lineMeta1 = "  \(playState) | \(titleText) - \(artistText)"
        let formattedMeta1 = "\u{001B}[1;38;5;45m" + (lineMeta1.count > width ? String(lineMeta1.prefix(width - 2)) + ".." : lineMeta1) + "\u{001B}[0m"
        lines.append(getLine(content: formattedMeta1, width: width, border: border))
        
        let lineMeta2 = "  Vol: \(volPercent)% | Shuffle: \(shuff) | Repeat: \(rep)"
        let formattedMeta2 = "\u{001B}[38;5;246m" + (lineMeta2.count > width ? String(lineMeta2.prefix(width - 2)) + ".." : lineMeta2) + "\u{001B}[0m"
        lines.append(getLine(content: formattedMeta2, width: width, border: border))
        
        // Render timeline progress bar
        let duration = viewModel.currentTrack?.duration ?? 0.0
        let current = viewModel.currentTime
        let progress = duration > 0 ? current / duration : 0.0
        
        let barW = max(6, width - 20)
        let filled = Int(progress * Double(barW))
        let empty = max(0, barW - filled)
        let barStr = String(repeating: "█", count: filled) + String(repeating: "░", count: empty)
        
        let timeStr = "  \(formatTime(current)) [\u{001B}[38;5;45m\(barStr)\u{001B}[0m] \(formatTime(duration))"
        lines.append(getLine(content: timeStr, width: width, border: border))
        
        // Render spectrogram (takes remaining dynamic rows!)
        let bars = viewModel.visualizerBars
        let barCount = min(bars.count, max(6, width / 3))
        let spacePad = max(0, (width - (barCount * 3)) / 2)
        let padStr = String(repeating: " ", count: spacePad)
        
        let visRows = max(1, remainingRows)
        for r in (0..<visRows).reversed() {
            var rowStr = padStr
            let threshold = Double(r) / Double(visRows)
            
            for c in 0..<barCount {
                let val = bars[c]
                let char = val >= threshold + 0.1 ? "██" : (val >= threshold ? "▄▄" : "  ")
                let colorCode: String
                let progressVal = Double(c) / Double(barCount)
                if progressVal < 0.35 { colorCode = "\u{001B}[38;5;45m" }
                else if progressVal < 0.70 { colorCode = "\u{001B}[38;5;99m" }
                else { colorCode = "\u{001B}[38;5;201m" }
                rowStr += colorCode + char + "\u{001B}[0m "
            }
            lines.append(getLine(content: rowStr, width: width, border: border))
        }
        
        lines.append(getFooter(width: width, border: border))
        return lines
    }
    
    // MARK: - Popups / Overlays Drawing
    private func drawInputAndOverlays(width: Int) -> String {
        var lines: [String] = []
        
        // Check active popup or search mode
        switch inputMode {
        case .searchInput(let query):
            let text = " 🔎 ПОИСК SoundCloud (Tab: Spotify, Enter: искать, Esc: отмена): [ \(query)█ ]"
            let pad = max(0, width - text.count)
            lines.append("\u{001B}[48;5;236;38;5;82m\(text)\(String(repeating: " ", count: pad))\u{001B}[0m")
        case .playlistCreateInput(let name):
            let text = " 📁 НОВЫЙ ПЛЕЙЛИСТ (Enter: создать, Esc: отмена): [ \(name)█ ]"
            let pad = max(0, width - text.count)
            lines.append("\u{001B}[48;5;236;38;5;208m\(text)\(String(repeating: " ", count: pad))\u{001B}[0m")
        case .normal:
            if case .addToPlaylist = popupState {
                let playlists = viewModel.localPlaylists
                if playlists.isEmpty {
                    let text = " ⚠️ Создайте плейлист сначала с помощью [C] в панели Библиотеки!"
                    let pad = max(0, width - text.count)
                    lines.append("\u{001B}[48;5;88;38;5;255m\(text)\(String(repeating: " ", count: pad))\u{001B}[0m")
                } else {
                    let popupTitle = "ВЫБЕРИТЕ ПЛЕЙЛИСТ"
                    let dashes = max(0, width - 2 - popupTitle.count - 5)
                    let headerStr = "╔══ \(popupTitle) " + String(repeating: "═", count: dashes) + "╗"
                    lines.append("\u{001B}[38;5;45m\(headerStr)\u{001B}[0m")
                    
                    if selectedPopupIndex < playlists.count {
                        let line = "   ▶ 📁 \(playlists[selectedPopupIndex].name)"
                        let pad = max(0, width - line.count - 4)
                        lines.append("\u{001B}[38;5;45m║\u{001B}[0m\u{001B}[7;38;5;82m\(line)\(String(repeating: " ", count: pad))\u{001B}[0m\u{001B}[38;5;45m║\u{001B}[0m")
                    } else {
                        lines.append("\u{001B}[38;5;45m║\u{001B}[0m\(String(repeating: " ", count: width - 2))\u{001B}[38;5;45m║\u{001B}[0m")
                    }
                    
                    let footerStr = "╚" + String(repeating: "═", count: width - 2) + "╝"
                    lines.append("\u{001B}[38;5;45m\(footerStr)\u{001B}[0m")
                }
            } else if showOptions {
                let optionsTitle = "НАСТРОЙКИ СВЯЗИ / СИСТЕМЫ"
                let dashes = max(0, width - 2 - optionsTitle.count - 5)
                let headerStr = "╔══ \(optionsTitle) " + String(repeating: "═", count: dashes) + "╗"
                lines.append("\u{001B}[38;5;201m\(headerStr)\u{001B}[0m")
                
                let soundcloudOAuth = viewModel.soundCloudOAuth.isEmpty ? "НЕ АКТИВЕН" : "ПОДКЛЮЧЕН"
                let line = "  SoundCloud: \(soundcloudOAuth)  |  Spotify: \(viewModel.spotifyToken.isEmpty ? "НЕ АКТИВЕН" : "ПОДКЛЮЧЕН")"
                let pad = max(0, width - line.count - 4)
                lines.append("\u{001B}[38;5;201m║\u{001B}[0m\(line)\(String(repeating: " ", count: pad))\u{001B}[38;5;201m║\u{001B}[0m")
                
                let footerStr = "╚" + String(repeating: "═", count: width - 2) + "╝"
                lines.append("\u{001B}[38;5;201m\(footerStr)\u{001B}[0m")
            }
        }
        
        // Fill remaining rows to always return exactly 3 lines
        while lines.count < 3 {
            lines.append("")
        }
        
        var res = ""
        for line in lines.prefix(3) {
            res += line + "\u{001B}[K\n"
        }
        return res
    }
    
    // MARK: - Simple HUD / Fallbacks
    private func drawHUD(width: Int, isCompact: Bool) -> String {
        var res = ""
        let border = String(repeating: "═", count: max(10, width - 4))
        
        res += "\u{001B}[38;5;99m╔\(border)╗\u{001B}[0m\u{001B}[K\n"
        
        let playState = viewModel.isPlaying ? "▶ PLAYING" : "Ⅱ PAUSED"
        let titleText = viewModel.currentTrack?.title ?? "Нет трека"
        let artistText = viewModel.currentTrack?.artist ?? "Aferapokitaysky"
        
        let line1 = "  \(playState)  |  Track: \(titleText) - \(artistText)"
        let padCount1 = max(0, width - line1.count - 4)
        res += "\u{001B}[38;5;99m║\u{001B}[0m\(line1)\(String(repeating: " ", count: padCount1))\u{001B}[38;5;99m║\u{001B}[0m\u{001B}[K\n"
        
        let duration = viewModel.currentTrack?.duration ?? 0.0
        let current = viewModel.currentTime
        let progress = duration > 0 ? current / duration : 0.0
        
        let barWidth = max(20, width - 26)
        let filledCount = Int(progress * Double(barWidth))
        let emptyCount = max(0, barWidth - filledCount)
        let barStr = String(repeating: "█", count: filledCount) + String(repeating: "░", count: emptyCount)
        
        let progressBarLine = "  \(formatTime(current)) [\(barStr)] \(formatTime(duration))"
        let padCount2 = max(0, width - progressBarLine.count - 4)
        res += "\u{001B}[38;5;99m║\u{001B}[0m\(progressBarLine)\(String(repeating: " ", count: padCount2))\u{001B}[38;5;99m║\u{001B}[0m\u{001B}[K\n"
        
        if !isCompact {
            let shuff = viewModel.isShuffle ? "ON" : "OFF"
            let rep = viewModel.isRepeat ? "ON" : "OFF"
            let volPercent = Int(viewModel.volume * 100)
            
            let line3 = "  Volume: \(volPercent)%  |  Shuffle: \(shuff)  |  Repeat: \(rep)"
            let padCount3 = max(0, width - line3.count - 4)
            res += "\u{001B}[38;5;99m║\u{001B}[0m\(line3)\(String(repeating: " ", count: padCount3))\u{001B}[38;5;99m║\u{001B}[0m\u{001B}[K\n"
        }
        
        res += "\u{001B}[38;5;99m╚\(border)╝\u{001B}[0m\u{001B}[K\n"
        return res
    }
    
    private func drawVisualizer(width: Int, height: Int) -> String {
        var res = ""
        res += "\u{001B}[K\n"
        
        let bars = viewModel.visualizerBars
        let barCount = min(bars.count, max(10, (width - 10) / 3))
        guard barCount > 0 else { return "\u{001B}[K\n" }
        
        let spacePad = max(0, (width - (barCount * 3)) / 2)
        let padStr = String(repeating: " ", count: spacePad)
        
        let targetRows = max(1, height - 2)
        for r in (0..<targetRows).reversed() {
            var rowStr = padStr
            let threshold = Double(r) / Double(targetRows)
            
            for c in 0..<barCount {
                let val = bars[c]
                let char = val >= threshold + 0.04 ? "██" : (val >= threshold ? "▄▄" : "  ")
                let colorCode: String
                let progress = Double(c) / Double(barCount)
                if progress < 0.35 { colorCode = "\u{001B}[38;5;45m" }
                else if progress < 0.70 { colorCode = "\u{001B}[38;5;99m" }
                else { colorCode = "\u{001B}[38;5;201m" }
                rowStr += colorCode + char + "\u{001B}[0m "
            }
            res += rowStr + "\u{001B}[K\n"
        }
        res += "\u{001B}[K\n"
        return res
    }
    
    private func drawPlaylistBrowser(width: Int, height: Int) -> String {
        var res = ""
        let border = String(repeating: "═", count: max(10, width - 4))
        
        let headerTitle = "ВЫБЕРИТЕ ТРЕК"
        let dashes = max(0, width - 2 - headerTitle.count - 5)
        let headerStr = "╔══ \(headerTitle) " + String(repeating: "═", count: dashes) + "╗"
        res += "\u{001B}[38;5;45m\(headerStr)\u{001B}[0m\u{001B}[K\n"
        
        let tracks = selectedAlbum?.tracks ?? []
        guard !tracks.isEmpty else {
            res += "  В библиотеке пусто!\n"
            return res
        }
        
        let maxDisplay = max(3, height - 2)
        var startIdx = 0
        var endIdx = tracks.count
        
        if tracks.count > maxDisplay {
            startIdx = max(0, selectedTrackIndex - maxDisplay / 2)
            endIdx = min(tracks.count, startIdx + maxDisplay)
            if endIdx - startIdx < maxDisplay {
                startIdx = max(0, endIdx - maxDisplay)
            }
        }
        
        for idx in startIdx..<endIdx {
            let track = tracks[idx]
            let isSelected = idx == selectedTrackIndex
            let isCurrentlyPlaying = track.id == viewModel.currentTrack?.id
            
            let pointer = isSelected ? "\u{001B}[38;5;82m▶\u{001B}[0m" : " "
            let indicator = isCurrentlyPlaying ? "\u{001B}[38;5;45m♫\u{001B}[0m" : " "
            
            let line = "  \(pointer) \(indicator) [\(idx + 1)] \(track.title) - \(track.artist)"
            let cleanLine = "   [\(idx + 1)] \(track.title) - \(track.artist)"
            
            let pad = max(0, width - cleanLine.count - 6)
            let padStr = String(repeating: " ", count: pad)
            
            let lineFormatted = isSelected ? "\u{001B}[38;5;82m\(line)\(padStr)\u{001B}[0m" : line + padStr
            res += "\u{001B}[38;5;45m║\u{001B}[0m\(lineFormatted)\u{001B}[38;5;45m║\u{001B}[0m\u{001B}[K\n"
        }
        
        // Pad with empty rows to match exact height budget
        let renderedRows = endIdx - startIdx
        if renderedRows < maxDisplay {
            for _ in renderedRows..<maxDisplay {
                res += "\u{001B}[38;5;45m║\u{001B}[0m\(String(repeating: " ", count: width - 4))\u{001B}[38;5;45m║\u{001B}[0m\u{001B}[K\n"
            }
        }
        
        res += "\u{001B}[38;5;45m╚\(border)╝\u{001B}[0m\u{001B}[K\n"
        return res
    }
    
    // MARK: - Footer / Legend Drawer
    private func drawFooter(width: Int) -> String {
        var res = ""
        let border = String(repeating: "─", count: max(10, width - 4))
        
        res += "\u{001B}[38;5;244m┌\(border)┐\u{001B}[0m\u{001B}[K\n"
        
        let legend: String
        switch inputMode {
        case .searchInput:
            legend = "  [Enter] Начать поиск  |  [Tab] Сменить SoundCloud/Spotify  |  [Esc] Отмена"
        case .playlistCreateInput:
            legend = "  [Enter] Создать плейлист  |  [Esc] Отмена"
        case .normal:
            if case .addToPlaylist = popupState {
                legend = "  [▲/▼] Выбрать  |  [Enter] Подтвердить  |  [Esc] Назад"
            } else {
                legend = "  [Tab] Колонки | [▲/▼] Нав | [◀/▶] Seek/Фокус | [Space] Play | [/] Поиск | [C] Создать пл | [A] Добавить тк | [T] Тема | [O] Опции | [Q] Выход"
            }
        }
        
        let pad = max(0, width - legend.count - 4)
        let padStr = String(repeating: " ", count: pad)
        
        res += "\u{001B}[38;5;244m│\u{001B}[38;5;248m\(legend)\(padStr)\u{001B}[38;5;244m│\u{001B}[0m\u{001B}[K\n"
        res += "\u{001B}[38;5;244m└\(border)┘\u{001B}[0m\u{001B}[K"
        return res
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
    
    // MARK: - Safe TUI Box Padding Helpers
    private func visibleCharCount(_ str: String) -> Int {
        var count = 0
        var inEscape = false
        let chars = Array(str)
        var i = 0
        while i < chars.count {
            if chars[i] == "\u{001B}" {
                inEscape = true
                i += 1
                continue
            }
            if inEscape {
                let c = chars[i]
                if (c >= "a" && c <= "z") || (c >= "A" && c <= "Z") {
                    inEscape = false
                }
                i += 1
                continue
            }
            count += 1
            i += 1
        }
        return count
    }
    
    private func getHeader(title: String, width: Int, border: String) -> String {
        let cleanTitle = title.replacingOccurrences(of: "\u{001B}\\[[0-9;]*[a-zA-Z]", with: "", options: .regularExpression)
        let dashes = max(0, width - cleanTitle.count - 3)
        return border + "┌─ \(title) " + String(repeating: "─", count: dashes) + "┐\u{001B}[0m"
    }
    
    private func getLine(content: String, width: Int, border: String) -> String {
        let visibleWidth = visibleCharCount(content)
        let pad = max(0, width - visibleWidth)
        return border + "│\u{001B}[0m" + content + String(repeating: " ", count: pad) + border + "│\u{001B}[0m"
    }
    
    private func getFooter(width: Int, border: String) -> String {
        return border + "└" + String(repeating: "─", count: width) + "┘\u{001B}[0m"
    }
}
