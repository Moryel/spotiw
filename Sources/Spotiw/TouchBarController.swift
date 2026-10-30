import AppKit

/// Puts a Spotiw button in the Control Strip and, when tapped, shows the
/// player as a system-wide Touch Bar that stays up whatever app is in front.
final class TouchBarController: NSObject, NSTouchBarDelegate {
    private let trayIdentifier = NSTouchBarItem.Identifier("com.yuksel.spotiw.tray")
    private let playerIdentifier = NSTouchBarItem.Identifier("com.yuksel.spotiw.player")

    private let playerView = SpotifyWidgetView(frame: NSRect(x: 0, y: 0, width: 640, height: 30))
    private lazy var playerWidth = playerView.widthAnchor.constraint(equalToConstant: 640)
    private lazy var trayItem = makeTrayItem()
    private lazy var touchBar: NSTouchBar = {
        let bar = NSTouchBar()
        bar.delegate = self
        bar.defaultItemIdentifiers = [playerIdentifier]
        return bar
    }()

    func install() {
        TouchBarPrivate.setShowsCloseBox(true)
        TouchBarPrivate.addSystemTrayItem(trayItem)
        TouchBarPrivate.setControlStripPresence(trayIdentifier, true)
        playerView.onClose = { [weak self] in self?.minimize() }
        playerView.startObservingSpotify()
    }

    func uninstall() {
        playerView.stopObservingSpotify()
        TouchBarPrivate.dismissSystemModal(touchBar)
        TouchBarPrivate.setControlStripPresence(trayIdentifier, false)
        TouchBarPrivate.removeSystemTrayItem(trayItem)
    }

    @objc func present() {
        let keepControlStrip = SpotifyWidgetSettingsStore.shared.settings.keepControlStrip
        let placement: Int64 = keepControlStrip ? 0 : 1
        // 13" Touch Bar: ~1000 pt in full width, the collapsed Control Strip takes ~300 pt
        // the system adds its own close box next to a bar that keeps the Control Strip
        playerWidth.constant = keepControlStrip ? 600 : 960
        playerView.showsCloseButton = !keepControlStrip
        TouchBarPrivate.presentSystemModal(touchBar, placement: placement, trayIdentifier: trayIdentifier)
    }

    func minimize() {
        TouchBarPrivate.minimizeSystemModal(touchBar)
    }

    /// The placement (full width or next to the Control Strip) is only read when the bar
    /// comes up, so take it down first and show it again with the new setting.
    func representWithCurrentSettings() {
        minimize()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            self.present()
        }
    }

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        guard identifier == playerIdentifier else { return nil }
        let item = NSCustomTouchBarItem(identifier: identifier)
        playerView.translatesAutoresizingMaskIntoConstraints = false
        playerWidth.isActive = true
        item.view = playerView
        item.customizationLabel = "Spotiw"
        return item
    }

    private func makeTrayItem() -> NSCustomTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: trayIdentifier)
        let image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "Spotiw") ?? NSImage()
        let button = NSButton(image: image, target: self, action: #selector(present))
        button.contentTintColor = .systemGreen
        item.view = button
        return item
    }
}
