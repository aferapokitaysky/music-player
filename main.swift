import Cocoa
import SwiftUI

// Borderless window must opt-in to becoming key/main, otherwise text fields
// can't receive paste / keyboard events.
final class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
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
            window?.performDrag(with: event)
        }
        // Pass-through: don't claim hits unless something is on top
        override func hitTest(_ point: NSPoint) -> NSView? {
            return self
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    var visualEffectView: NSVisualEffectView!
    private let themeManager = ThemeManager.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()

        // Default window size (3-column layout)
        let width: CGFloat = 1080
        let height: CGFloat = 640

        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1024, height: 768)
        let rect = NSRect(
            x: screenFrame.midX - width / 2.0,
            y: screenFrame.midY - height / 2.0,
            width: width,
            height: height
        )

        // Create pure borderless window (premium floating widget)
        window = KeyableWindow(
            contentRect: rect,
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        window.acceptsMouseMovedEvents = true

        window.center()
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
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
        let contentView = MainView().environmentObject(themeManager)
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

        WindowController.shared.window = window

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeKey()
    }

    @objc private func applyTheme() {
        guard let view = visualEffectView else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.30
            ctx.allowsImplicitAnimation = true
            view.material = themeManager.theme.nsMaterial
            view.appearance = themeManager.theme.nsAppearance
            let borderAlpha: CGFloat = themeManager.theme == .dark ? 0.10 : 0.20
            view.layer?.borderColor = (themeManager.theme == .dark
                ? NSColor.white.withAlphaComponent(borderAlpha)
                : NSColor.black.withAlphaComponent(borderAlpha)).cgColor
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    // Install a minimal main menu so that Cmd+C / Cmd+V / Cmd+X / Cmd+A
    // are routed to the first responder (e.g. NSTextField's field editor).
    private func installMainMenu() {
        let mainMenu = NSMenu()

        // App menu (required so the OS knows app name & has Quit)
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Aesthetic Player",
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

// Custom Main Entry Point
let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
