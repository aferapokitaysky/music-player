import Cocoa
import SwiftUI

// Borderless window must opt-in to becoming key/main, otherwise text fields
// can't receive paste / keyboard events.
final class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        // If a text input has focus, let standard text editing and caret movement handle the keystrokes.
        if let responder = firstResponder, responder.isKind(of: NSText.self) {
            super.keyDown(with: event)
            return
        }

        switch event.keyCode {
        case 126: // Up Arrow
            NotificationCenter.default.post(name: NSNotification.Name("appVolumeUp"), object: nil)
        case 125: // Down Arrow
            NotificationCenter.default.post(name: NSNotification.Name("appVolumeDown"), object: nil)
        case 123: // Left Arrow
            NotificationCenter.default.post(name: NSNotification.Name("appSeekBackward"), object: nil)
        case 124: // Right Arrow
            NotificationCenter.default.post(name: NSNotification.Name("appSeekForward"), object: nil)
        default:
            super.keyDown(with: event)
        }
    }
}

// Thin singleton so SwiftUI traffic-light buttons can drive AppKit behaviour
final class WindowController {
    static let shared = WindowController()
    weak var window: NSWindow?
    private var savedFrame: NSRect?

    func close()    { NSApplication.shared.terminate(nil) }
    func minimize() { window?.miniaturize(nil) }

    /// Zoom: toggles between standard size and the screen's visible frame.
    func zoom() {
        guard let w = window, let screen = w.screen ?? NSScreen.main else { return }
        let target = screen.visibleFrame
        if w.frame.equalTo(target), let saved = savedFrame {
            w.setFrame(saved, display: true, animate: true)
            savedFrame = nil
        } else {
            savedFrame = w.frame
            w.setFrame(target, display: true, animate: true)
        }
    }
}

// SwiftUI-friendly drag region for the borderless window
struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { _DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class _DragView: NSView {
        override func mouseDown(with event: NSEvent) {
            if event.clickCount == 2 {
                WindowController.shared.zoom()
            } else {
                window?.performDrag(with: event)
            }
        }
        // Pass-through: don't claim hits unless the point is actually inside our bounds!
        override func hitTest(_ point: NSPoint) -> NSView? {
            return NSPointInRect(point, self.bounds) ? self : nil
        }
    }
}

final class NotchWindow: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class NotchHostingView<Content: View>: NSHostingView<Content> {
    var isNotchExpanded = false
    private var trackingArea: NSTrackingArea?
    
    required init(rootView: Content) {
        super.init(rootView: rootView)
        NotificationCenter.default.addObserver(forName: NSNotification.Name("NotchHoverStateChanged"), object: nil, queue: .main) { [weak self] notification in
            if let expanded = notification.object as? Bool {
                self?.isNotchExpanded = expanded
            }
        }
    }
    
    @objc required dynamic init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways, .inVisibleRect]
        let newArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(newArea)
        trackingArea = newArea
    }
    
    override func mouseEntered(with event: NSEvent) {
        NotificationCenter.default.post(name: NSNotification.Name("NotchHoverStateChanged"), object: true)
    }
    
    override func mouseExited(with event: NSEvent) {
        NotificationCenter.default.post(name: NSNotification.Name("NotchHoverStateChanged"), object: false)
    }
    
    // Natively pass through clicks that are outside the actual physical notch UI!
    override func hitTest(_ point: NSPoint) -> NSView? {
        if isNotchExpanded {
            // New premium visual notch dimensions: 500x240 (max possible height with volume slider expanded), dynamically centered in window bounds
            let visualWidth: CGFloat = 500
            let visualHeight: CGFloat = 240
            let minX = (bounds.width - visualWidth) / 2.0
            let maxX = bounds.width - minX
            let minY = bounds.height - visualHeight
            let maxY = bounds.height
            
            if point.x >= minX && point.x <= maxX && point.y >= minY && point.y <= maxY {
                return super.hitTest(point)
            }
        } else {
            // Collapsed: let everything pass through! Clicks are never needed when collapsed.
            return nil
        }
        
        return nil
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    var notchWindow: NSWindow?
    var visualEffectView: NSVisualEffectView!
    private let themeManager = ThemeManager.shared
    var viewModel: PlayerViewModel!

    func applicationDidFinishLaunching(_ notification: Notification) {
        viewModel = PlayerViewModel()
        installMainMenu()

        // Default window size (3-column layout)
        let width: CGFloat = 1160
        let height: CGFloat = 700

        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1024, height: 768)
        let rect = NSRect(
            x: screenFrame.midX - width / 2.0,
            y: screenFrame.midY - height / 2.0,
            width: width,
            height: height
        )

        // Create full-size transparent titlebar window with native traffic lights
        window = KeyableWindow(
            contentRect: rect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.acceptsMouseMovedEvents = true

        window.center()
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.hasShadow = false
        window.delegate = self
        window.minSize = NSSize(width: 980, height: 580)

        // We provide an explicit drag area at the top instead — otherwise
        // dragging on top of slider gestures (volume / progress) triggers a window move.
        window.isMovableByWindowBackground = false

        // Glassmorphic backing
        visualEffectView = NSVisualEffectView()
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.material = themeManager.theme.nsMaterial
        visualEffectView.appearance = themeManager.theme.nsAppearance
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 22
        visualEffectView.layer?.masksToBounds = true
        // soft outer border
        visualEffectView.layer?.borderWidth = 1
        visualEffectView.layer?.borderColor = NSColor.white.withAlphaComponent(0.10).cgColor

        window.contentView = visualEffectView

        // Host the SwiftUI MainView with shared ThemeManager
        let contentView = MainView(viewModel: viewModel).environmentObject(themeManager)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        visualEffectView.addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: visualEffectView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor)
        ])

        // React to theme switch — animate window material/appearance
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applyTheme),
            name: .themeDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateNotchWindowFrame(_:)),
            name: NSNotification.Name("NotchHoverStateChanged"),
            object: nil
        )

        WindowController.shared.window = window

        // Setup Notch mini player window
        setupNotchWindow()

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeKey()
    }

    private func setupNotchWindow() {
        let screen = window?.screen ?? NSScreen.main ?? NSScreen.screens.first
        let screenFrame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        
        // Starts compact (172x32) matching MacBook physical notch exactly
        let wWidth: CGFloat = 172
        let wHeight: CGFloat = 32
        let notchRect = NSRect(
            x: screenFrame.midX - wWidth / 2.0,
            y: screenFrame.maxY - wHeight,
            width: wWidth,
            height: wHeight
        )
        
        let notchWin = NotchWindow(
            contentRect: notchRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        notchWin.isOpaque = false
        notchWin.backgroundColor = .clear
        notchWin.hasShadow = false
        notchWin.level = .statusBar
        notchWin.ignoresMouseEvents = false
        notchWin.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        notchWin.acceptsMouseMovedEvents = true
        notchWin.canHide = false
        notchWin.hidesOnDeactivate = false
        notchWin.appearance = themeManager.theme.nsAppearance
        
        let notchView = NotchMiniPlayerView(viewModel: viewModel)
            .environmentObject(themeManager)
        let hostingView = NotchHostingView(rootView: notchView)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        
        notchWin.contentView = hostingView
        notchWin.orderFrontRegardless()
        
        self.notchWindow = notchWin
    }

    private var isNotchExpanded = false
    private var collapseWorkItem: DispatchWorkItem?

    @objc private func updateNotchWindowFrame(_ notification: Notification) {
        guard let notchWin = notchWindow,
              let expanded = notification.object as? Bool else { return }
        
        self.isNotchExpanded = expanded
        
        let screen = window?.screen ?? notchWin.screen ?? NSScreen.main ?? NSScreen.screens.first
        guard let screenFrame = screen?.frame else { return }

        if expanded {
            collapseWorkItem?.cancel()
            collapseWorkItem = nil
            
            let targetFrame = NSRect(
                x: screenFrame.midX - 560 / 2.0,
                y: screenFrame.maxY - 260,
                width: 560,
                height: 260
            )
            notchWin.setFrame(targetFrame, display: true, animate: false)
        } else {
            collapseWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self, weak notchWin] in
                guard let self = self, let notchWin = notchWin, !self.isNotchExpanded else { return }
                
                let screen = self.window?.screen ?? notchWin.screen ?? NSScreen.main ?? NSScreen.screens.first
                let screenFrame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
                let collapsedFrame = NSRect(
                    x: screenFrame.midX - 172 / 2.0,
                    y: screenFrame.maxY - 32,
                    width: 172,
                    height: 32
                )
                notchWin.setFrame(collapsedFrame, display: true, animate: false)
            }
            collapseWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.38, execute: workItem)
        }
    }
 
    @objc private func applyTheme() {
        guard let view = visualEffectView else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.30
            ctx.allowsImplicitAnimation = true
            view.material = themeManager.theme.nsMaterial
            view.appearance = themeManager.theme.nsAppearance
            notchWindow?.appearance = themeManager.theme.nsAppearance
            let borderAlpha: CGFloat = themeManager.theme == .dark ? 0.10 : 0.20
            view.layer?.borderColor = (themeManager.theme == .dark
                ? NSColor.white.withAlphaComponent(borderAlpha)
                : NSColor.black.withAlphaComponent(borderAlpha)).cgColor
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        if let w = window {
            if w.isMiniaturized {
                w.deminiaturize(nil)
            }
            w.makeKeyAndOrderFront(nil)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if let w = window {
            if w.isMiniaturized {
                w.deminiaturize(nil)
            }
            w.makeKeyAndOrderFront(nil)
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationDidResignActive(_ notification: Notification) {
        collapseNotchWindow()
    }

    func windowDidMiniaturize(_ notification: Notification) {
        collapseNotchWindow()
    }

    private func collapseNotchWindow() {
        NotificationCenter.default.post(name: NSNotification.Name("NotchHoverStateChanged"), object: false)
    }

    // Install a minimal main menu so that Cmd+C / Cmd+V / Cmd+X / Cmd+A
    // are routed to the first responder (e.g. NSTextField's field editor).
    private func installMainMenu() {
        let mainMenu = NSMenu()

        // App menu (required so the OS knows app name & has Quit)
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Aferapokitaysky Player",
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                        keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Hide",
                        action: #selector(NSApplication.hide(_:)),
                        keyEquivalent: "h")
        appMenu.addItem(withTitle: "Quit",
                        action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")
        appItem.submenu = appMenu

        // Edit menu — gives us Cut / Copy / Paste / Select All wired into the responder chain
        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo",
                         action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: "Redo",
                                    action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut",
                         action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy",
                         action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste",
                         action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All",
                         action: #selector(NSResponder.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu

        NSApp.mainMenu = mainMenu
    }
}

func startCli() {
    Task { @MainActor in
        let viewModel = PlayerViewModel()
        let app = TerminalPlayerApp(viewModel: viewModel)
        app.run()
    }
    RunLoop.main.run()
}

if CommandLine.arguments.contains("--cli") || CommandLine.arguments.contains("-c") {
    startCli()
} else {
    let delegate = AppDelegate()
    NSApplication.shared.delegate = delegate
    _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
}
