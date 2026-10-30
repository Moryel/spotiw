import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let touchBarController = TouchBarController()
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var launchAtLoginItem: NSMenuItem?
    private var keepControlStrip = SpotifyWidgetSettingsStore.shared.settings.keepControlStrip

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()

        guard TouchBarPrivate.isAvailable else {
            let alert = NSAlert()
            alert.messageText = "Touch Bar not available"
            alert.informativeText = "Spotiw needs a Mac with a Touch Bar."
            alert.runModal()
            return
        }

        touchBarController.install()
        if SpotifyWidgetSettingsStore.shared.settings.showOnLaunch {
            touchBarController.present()
        }

        NotificationCenter.default.addObserver(self, selector: #selector(settingsDidChange(_:)), name: .spotifyWidgetSettingsDidChange, object: nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        touchBarController.uninstall()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "Spotiw")

        let menu = NSMenu()
        menu.addItem(withTitle: "Show on Touch Bar", action: #selector(showTouchBar), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",").target = self
        if #available(macOS 13.0, *) {
            let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
            loginItem.target = self
            menu.addItem(loginItem)
            launchAtLoginItem = loginItem
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Spotiw", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.delegate = self

        item.menu = menu
        statusItem = item
    }

    @objc private func showTouchBar() {
        touchBarController.present()
    }

    @objc private func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: SpotifyWidgetPreferences())
            window.title = "Spotiw Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func toggleLaunchAtLogin() {
        guard #available(macOS 13.0, *) else { return }
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }

    @objc private func settingsDidChange(_ notification: Notification) {
        guard let settings = notification.object as? SpotifyWidgetSettings,
              settings.keepControlStrip != keepControlStrip else { return }
        keepControlStrip = settings.keepControlStrip
        // placement only takes effect when the bar is presented again
        touchBarController.present()
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        if #available(macOS 13.0, *) {
            launchAtLoginItem?.state = SMAppService.mainApp.status == .enabled ? .on : .off
        }
    }
}
