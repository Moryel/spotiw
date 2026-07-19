import AppKit
import PockKit

public class SpotifyWidgetView: PKView {
    private let controlsStack = NSStackView()
    private let contentStack = NSStackView()
    private let trackLabel = MarqueeLabel()
    private let albumArtView = NSImageView()
    private let equalizerView = EqualizerView()
    private var refreshTimer: Timer?
    private var isObserving = false
    private var currentSettings = SpotifyWidgetSettingsStore.shared.settings
    private var controlButtons: [NSButton] = []
    private var lastToggleTime: Date?

    private let spotifyTrackScript = """
tell application "Spotify"
    if player state is playing then
        return name of current track & " - " & artist of current track
    end if
end tell
"""

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
        apply(settings: SpotifyWidgetSettingsStore.shared.settings)
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
        apply(settings: SpotifyWidgetSettingsStore.shared.settings)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        stopObservingSpotify()
    }

    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        controlsStack.translatesAutoresizingMaskIntoConstraints = false
        controlsStack.orientation = .horizontal
        controlsStack.alignment = .centerY
        controlsStack.distribution = .fillEqually
        controlsStack.spacing = 4

        let restartButton = makeControlButton(symbolName: "backward.end.fill", fallbackTitle: "|<", action: #selector(restartTrack), style: currentSettings.buttonStyle)
        let previousButton = makeControlButton(symbolName: "backward.fill", fallbackTitle: "<<", action: #selector(previousTrack), style: currentSettings.buttonStyle)
        let playPauseButton = makeControlButton(symbolName: "playpause.fill", fallbackTitle: ">", action: #selector(playPause), style: currentSettings.buttonStyle)
        let nextButton = makeControlButton(symbolName: "forward.fill", fallbackTitle: ">>", action: #selector(nextTrack), style: currentSettings.buttonStyle)

        controlButtons = [restartButton, previousButton, playPauseButton, nextButton]

        let widgetTap = NSClickGestureRecognizer(target: self, action: #selector(toggleSpotify))
        widgetTap.numberOfClicksRequired = 1
        addGestureRecognizer(widgetTap)

        controlButtons.forEach { button in
            controlsStack.addArrangedSubview(button)
            button.widthAnchor.constraint(equalToConstant: 24).isActive = true
        }

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.orientation = .horizontal
        contentStack.alignment = .centerY
        contentStack.spacing = 6

        albumArtView.translatesAutoresizingMaskIntoConstraints = false
        albumArtView.imageScaling = .scaleProportionallyDown
        albumArtView.isHidden = true
        albumArtView.widthAnchor.constraint(equalToConstant: 28).isActive = true
        albumArtView.heightAnchor.constraint(equalToConstant: 28).isActive = true

        trackLabel.translatesAutoresizingMaskIntoConstraints = false
        equalizerView.translatesAutoresizingMaskIntoConstraints = false

        contentStack.addArrangedSubview(albumArtView)
        contentStack.addArrangedSubview(trackLabel)

        addSubview(controlsStack)
        addSubview(contentStack)
        addSubview(equalizerView)

        NSLayoutConstraint.activate([
            controlsStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            controlsStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            controlsStack.widthAnchor.constraint(equalToConstant: 108),
            controlsStack.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.78),

            equalizerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            equalizerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            equalizerView.widthAnchor.constraint(equalToConstant: 70),
            equalizerView.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.72),

            contentStack.leadingAnchor.constraint(equalTo: controlsStack.trailingAnchor, constant: 8),
            contentStack.trailingAnchor.constraint(equalTo: equalizerView.leadingAnchor, constant: -8),
            contentStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            contentStack.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.72)
        ])

        trackLabel.stringValue = "Spotify is not open"

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettingsChange(_:)),
            name: .spotifyWidgetSettingsDidChange,
            object: nil
        )
    }

    private func makeControlButton(symbolName: String, fallbackTitle: String, action: Selector, style: ControlButtonStyle) -> NSButton {
        let button = NSButton(title: fallbackTitle, target: self, action: action)
        button.bezelStyle = .rounded
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.contentTintColor = .labelColor
        button.wantsLayer = true
        button.translatesAutoresizingMaskIntoConstraints = false

        if #available(macOS 11.0, *), let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
            button.image = image
        } else {
            button.imagePosition = .noImage
            button.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        }

        applyButtonStyle(button, style: style)
        return button
    }

    private func applyButtonStyle(_ button: NSButton, style: ControlButtonStyle) {
        let tint = currentSettings.accentColor.color
        button.contentTintColor = tint
        if let img = button.image {
            img.isTemplate = true
        }

        switch style {
        case .icon:
            button.wantsLayer = true
            button.layer?.backgroundColor = nil
            button.layer?.borderColor = nil
            button.layer?.borderWidth = 0
            button.layer?.cornerRadius = 0
            button.isBordered = false
        case .filled:
            button.wantsLayer = true
            button.layer?.backgroundColor = tint.withAlphaComponent(0.18).cgColor
            button.layer?.borderColor = tint.withAlphaComponent(0.28).cgColor
            button.layer?.borderWidth = 0.8
            button.layer?.cornerRadius = 6
            button.isBordered = false
        case .pill:
            button.wantsLayer = true
            button.layer?.backgroundColor = tint.withAlphaComponent(0.12).cgColor
            button.layer?.borderColor = tint.withAlphaComponent(0.22).cgColor
            button.layer?.borderWidth = 0.8
            button.layer?.cornerRadius = 10
            button.isBordered = false
        case .glass:
            button.wantsLayer = true
            button.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.5).cgColor
            button.layer?.borderColor = tint.withAlphaComponent(0.22).cgColor
            button.layer?.borderWidth = 0.6
            button.layer?.cornerRadius = 8
            button.isBordered = false
        }
    }

    public func startObservingSpotify() {
        guard !isObserving else { return }
        isObserving = true

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleSpotifyPlaybackChange(_:)),
            name: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil
        )

        refreshTimer = Timer.scheduledTimer(
            timeInterval: 5,
            target: self,
            selector: #selector(updateSpotifyInfo),
            userInfo: nil,
            repeats: true
        )

        updateSpotifyInfo()
    }

    public func stopObservingSpotify() {
        guard isObserving else { return }
        isObserving = false

        DistributedNotificationCenter.default().removeObserver(self)
        refreshTimer?.invalidate()
        refreshTimer = nil
        equalizerView.stopAnimation()
    }

    @objc private func handleSettingsChange(_ notification: Notification) {
        guard let settings = notification.object as? SpotifyWidgetSettings else { return }
        apply(settings: settings)
    }

    private func apply(settings: SpotifyWidgetSettings) {
        currentSettings = settings
        equalizerView.style = settings.equalizerStyle
        equalizerView.accentColor = settings.accentColor.color
        equalizerView.sensitivity = CGFloat(settings.equalizerSensitivity)
        equalizerView.speed = CGFloat(settings.equalizerSpeed)
        equalizerView.animationDuration = CGFloat(settings.equalizerAnimationDuration)
        controlButtons.forEach { button in
            applyButtonStyle(button, style: settings.buttonStyle)
        }
        if settings.useArtworkColors {
            // clear current ambientColors and request artwork palette
            equalizerView.ambientColors = []
            DispatchQueue.global(qos: .utility).async {
                self.loadArtworkDataIfNeeded()
            }
        } else {
            // use fallback accent color palette
            let c = settings.accentColor.color
            equalizerView.ambientColors = [c, c.withAlphaComponent(0.72)]
        }

        if !settings.showAlbumArtwork {
            albumArtView.image = nil
            albumArtView.isHidden = true
        } else {
            // if enabled, attempt to load artwork for current track
            DispatchQueue.global(qos: .utility).async {
                self.loadArtworkDataIfNeeded()
            }
        }
    }

    @objc private func handleSpotifyPlaybackChange(_ notification: Notification) {
        updateSpotifyInfo()
    }

    @objc private func updateSpotifyInfo() {
        DispatchQueue.global(qos: .utility).async {
            let status = self.currentSpotifyStatus()
            DispatchQueue.main.async {
                self.applyStatus(status)
            }
        }
    }

    private func applyStatus(_ status: SpotifyWidgetStatus) {
        switch status {
        case .playing(let text):
            trackLabel.stringValue = text
            trackLabel.startMarqueeIfNeeded()
            equalizerView.startAnimation()
            if currentSettings.useArtworkColors || currentSettings.showAlbumArtwork {
                loadArtworkDataIfNeeded()
            }
        case .paused:
            trackLabel.stringValue = "Spotify paused"
            trackLabel.stopMarquee()
            albumArtView.image = nil
            albumArtView.isHidden = true
            equalizerView.stopAnimation()
        case .closed:
            trackLabel.stringValue = "Spotify is not open"
            trackLabel.stopMarquee()
            albumArtView.image = nil
            albumArtView.isHidden = true
            equalizerView.stopAnimation()
        }
    }

    @objc private func restartTrack() {
        runSpotifyCommand("set player position to 0")
        updateSpotifyInfo()
    }

    @objc private func previousTrack() {
        runSpotifyCommand("previous track")
        updateSpotifyInfo()
    }

    @objc private func playPause() {
        runSpotifyCommand("playpause")
        updateSpotifyInfo()
    }

    @objc private func nextTrack() {
        runSpotifyCommand("next track")
        updateSpotifyInfo()
    }

    @objc private func toggleSpotify() {
        // debounce repeated toggles
        if let last = lastToggleTime, Date().timeIntervalSince(last) < 0.8 {
            return
        }
        lastToggleTime = Date()

        if spotifyIsRunning() {
            _ = runAppleScript("""
tell application "Spotify"
    activate
end tell
""")
        } else {
            _ = runAppleScript("""
do shell script "open -a Spotify"
""")
        }

        DispatchQueue.main.async {
            self.updateSpotifyInfo()
        }
    }

    private func currentSpotifyStatus() -> SpotifyWidgetStatus {
        guard spotifyIsRunning() else {
            return .closed
        }

        let result = runAppleScript(spotifyTrackScript)
        guard !result.isEmpty else {
            let playingStatus = runAppleScript("""
tell application "Spotify" to if player state is playing then return true else return false
""")
            if playingStatus.trimmingCharacters(in: .whitespacesAndNewlines) == "true" {
                return .playing("")
            }
            return .paused
        }
        return .playing(result)
    }

    private func spotifyIsRunning() -> Bool {
        let result = runAppleScript("""
tell application "System Events" to return (name of processes) contains "Spotify"
""")
        return result.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "true"
    }

    private func loadArtworkDataIfNeeded() {
        guard spotifyIsRunning() else {
            // If Spotify is not running, clear artwork and ambience
            DispatchQueue.main.async {
                self.albumArtView.image = nil
                self.albumArtView.isHidden = true
                self.equalizerView.ambientColors = []
            }
            return
        }

        DispatchQueue.global(qos: .utility).async {
            var finalImage: NSImage? = nil
            var finalPalette: [NSColor] = []

            // Try method 1: Use Spotify cache directly
            if finalImage == nil {
                finalImage = self.loadArtworkFromSpotifyCache()
            }

            // Try method 2: Try AppleScript as fallback (might work on some systems)
            if finalImage == nil {
                let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("spotify-artwork-\(UUID().uuidString)").appendingPathExtension("png")
                let script = """
tell application "Spotify"
    if it is running then
        try
            set artData to artwork data of current track
            if artData is not missing value then
                set outPath to POSIX path of "#TEMP_PATH#"
                set outFile to open for access POSIX file outPath with write permission
                set eof outFile to 0
                write artData to outFile
                close access outFile
                return outPath
            else
                return ""
            end if
        on error errMsg
            return ""
        end try
    else
        return ""
    end if
end tell
""".replacingOccurrences(of: "#TEMP_PATH#", with: tempURL.path)

                let savedPath = self.runAppleScript(script)
                if !savedPath.isEmpty {
                    let fileURL = URL(fileURLWithPath: savedPath)
                    if FileManager.default.fileExists(atPath: fileURL.path) {
                        if let data = try? Data(contentsOf: fileURL), !data.isEmpty {
                            finalImage = NSImage(data: data)
                            if self.currentSettings.useArtworkColors {
                                finalPalette = ArtworkColorExtractor.palette(from: data, count: 7)
                            }
                            // Clean up temp file
                            try? FileManager.default.removeItem(at: fileURL)
                        }
                    }
                }
            }

            // Extract palette from image if we have it
            if finalImage != nil && self.currentSettings.useArtworkColors && finalPalette.isEmpty {
                if let tiffData = finalImage?.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmap.representation(using: .png, properties: [:]) {
                    finalPalette = ArtworkColorExtractor.palette(from: pngData, count: 7)
                }
            }

            DispatchQueue.main.async {
                if self.currentSettings.showAlbumArtwork, let image = finalImage {
                    self.albumArtView.image = image
                    self.albumArtView.isHidden = false
                    self.albumArtView.wantsLayer = true
                    self.albumArtView.layer?.cornerRadius = 3
                    self.albumArtView.layer?.masksToBounds = true
                } else {
                    self.albumArtView.image = nil
                    self.albumArtView.isHidden = true
                }

                if self.currentSettings.useArtworkColors, !finalPalette.isEmpty {
                    self.equalizerView.ambientColors = finalPalette
                } else {
                    // fallback palette based on accent color
                    let c = self.currentSettings.accentColor.color
                    self.equalizerView.ambientColors = [c, c.withAlphaComponent(0.72)]
                }
            }
        }
    }

    private func loadArtworkFromSpotifyCache() -> NSImage? {
        let cacheBasePath = NSHomeDirectory() + "/Library/Caches/Spotify"
        let spotifyDataPath = NSHomeDirectory() + "/Library/Application Support/Spotify"

        // Try common Spotify cache locations
        let searchPaths = [
            cacheBasePath + "/Browser",
            cacheBasePath,
            spotifyDataPath + "/PersistentCache/Volume_0"
        ]

        for basePath in searchPaths {
            guard FileManager.default.fileExists(atPath: basePath) else { continue }

            // Look for image files (artwork is typically stored as binary data or image files)
            do {
                let contents = try FileManager.default.contentsOfDirectory(atPath: basePath)
                for file in contents {
                    let fullPath = (basePath as NSString).appendingPathComponent(file)
                    var isDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDir), !isDir.boolValue {
                        // Try to load as image
                        if let imageData = try? Data(contentsOf: URL(fileURLWithPath: fullPath)),
                           imageData.count > 1000,  // Filter out very small files
                           let image = NSImage(data: imageData) {
                            return image
                        }
                    }
                }
            } catch {
                continue
            }
        }

        return nil
    }

    private func runSpotifyCommand(_ command: String) {
        let script = """
tell application "Spotify"
    if it is running then
        #COMMAND#
    end if
end tell
""".replacingOccurrences(of: "#COMMAND#", with: command)

        DispatchQueue.global(qos: .utility).async {
            _ = self.runAppleScript(script)
        }
    }

    private func runAppleScript(_ script: String) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        if script.contains("\n") || script.count > 200 {
            // write script to temp file and run it to avoid osascript -e limitations
            let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString).appendingPathExtension("applescript")
            do {
                try script.write(to: tmp, atomically: true, encoding: .utf8)
                process.arguments = [tmp.path]
            } catch {
                process.arguments = ["-e", script]
            }
        } else {
            process.arguments = ["-e", script]
        }

        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ""
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
