import AppKit
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let store = Store()
    private var timer: Timer?
    private var cancellable: AnyCancellable?
    private var popoverClosedAt = Date.distantPast
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: prSymbol, accessibilityDescription: "Pull requests")
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(togglePopover)
        }

        Prefs.registerDefaults()
        Notifier.shared.setup()
        NSApp.mainMenu = makeMainMenu()

        let content = ContentView(
            store: store,
            dismiss: { [weak self] in self?.popover.performClose(nil) },
            openSettings: { [weak self] in self?.openSettings() }
        )
        let hosting = NSHostingController(rootView: content)
        hosting.sizingOptions = .preferredContentSize
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = false
        popover.contentViewController = hosting
        popover.delegate = self

        cancellable = store.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.updateBadge() }
            }

        Task {
            await store.refresh()
            if ProcessInfo.processInfo.environment["NOTIFBAR_OPEN"] != nil {
                togglePopover()
            }
            if let capturePath = ProcessInfo.processInfo.environment["NOTIFBAR_CAPTURE"] {
                if !popover.isShown { togglePopover() }
                try? await Task.sleep(for: .seconds(1))
                capturePopover(to: capturePath)
            }
            if let capturePath = ProcessInfo.processInfo.environment["NOTIFBAR_CAPTURE_SETTINGS"] {
                openSettings()
                try? await Task.sleep(for: .seconds(1))
                if let view = settingsWindow?.contentView { captureView(view, to: capturePath) }
            }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { @MainActor [weak self] in await self?.store.refresh() }
        }
    }

    private func updateBadge() {
        guard let button = statusItem.button else { return }
        let count = store.badgeCount
        button.title = count > 0 ? " \(count)" : ""
        button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
    }

    private func capturePopover(to path: String) {
        guard let view = popover.contentViewController?.view else { return }
        captureView(view, to: path)
    }

    private func captureView(_ view: NSView, to path: String) {
        view.wantsLayer = true
        let previousBackground = view.layer?.backgroundColor
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        defer { view.layer?.backgroundColor = previousBackground }
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        if let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: path))
        }
    }

    private func makeMainMenu() -> NSMenu {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit NotificationBar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        return mainMenu
    }

    private func openSettings() {
        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: SettingsView())
            let window = NSWindow(contentViewController: hosting)
            window.title = "NotificationBar Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            settingsWindow = window
        }
        popover.performClose(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) === settingsWindow else { return }
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
        }
        return true
    }

    func popoverDidClose(_ notification: Notification) {
        popoverClosedAt = Date()
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            guard Date().timeIntervalSince(popoverClosedAt) > 0.3 else { return }
            Task { await store.refresh() }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
