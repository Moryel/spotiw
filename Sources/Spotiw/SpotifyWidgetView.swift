import AppKit

public class SpotifyWidgetView: NSView {
    private let closeButton = NSButton()
    private let contentStack = NSStackView()
    private let textStack = NSStackView()
    private let titleLabel = MarqueeLabel()
    private let artistLabel = NSTextField(labelWithString: "")
    private let albumArtView = NSImageView()
    private let controlsStack = NSStackView()
    private let elapsedLabel = NSTextField(labelWithString: "0:00")
    private let remainingLabel = NSTextField(labelWithString: "0:00")
    private let progressSlider = NSSlider(value: 0, minValue: 0, maxValue: 1, target: nil, action: nil)
    private let equalizerView = EqualizerView()
    private var refreshTimer: Timer?
    private var progressTimer: Timer?
    private var isObserving = false
    private var currentSettings = SpotifyWidgetSettingsStore.shared.settings
    private var controlButtons: [NSButton] = []
    private var playPauseButton: NSButton?
    private var lastToggleTime: Date?
    private var status: SpotifyWidgetStatus = .closed

    // playback position: `position` was true at `positionDate`
    private var position: Double = 0
    private var positionDate = Date()
    private var duration: Double = 0
    private var isScrubbing = false
    private var pendingSeek: DispatchWorkItem?

    // equalizer placement: a sized slot at the right end, or the whole bar behind the controls
    private lazy var equalizerWidth = equalizerView.widthAnchor.constraint(equalToConstant: 46)
    private lazy var slotConstraints: [NSLayoutConstraint] = [
        equalizerView.leadingAnchor.constraint(equalTo: remainingLabel.trailingAnchor, constant: 10),
        equalizerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
        equalizerView.centerYAnchor.constraint(equalTo: centerYAnchor),
        equalizerView.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.62),
        equalizerWidth
    ]
    private lazy var fullWidthConstraints: [NSLayoutConstraint] = [
        remainingLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
        equalizerView.leadingAnchor.constraint(equalTo: leadingAnchor),
        equalizerView.trailingAnchor.constraint(equalTo: trailingAnchor),
        equalizerView.topAnchor.constraint(equalTo: topAnchor),
        equalizerView.bottomAnchor.constraint(equalTo: bottomAnchor)
    ]

    // artwork is fetched once per track
    private var artworkTrackID: String?
    private var artworkImage: NSImage?
    private var artworkPalette: [NSColor] = []

    /// Called by the X button; returns the Touch Bar to its normal state.
    public var onClose: (() -> Void)?

    /// Off when the system draws its own close box (Control Strip kept visible).
    public var showsCloseButton = true {
        didSet {
            closeButton.isHidden = !showsCloseButton
            closeWidth.constant = showsCloseButton ? 30 : 0
        }
    }
    private lazy var closeWidth = closeButton.widthAnchor.constraint(equalToConstant: 30)

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

        closeButton.image = symbol("xmark", size: 12)
        closeButton.imagePosition = .imageOnly
        closeButton.isBordered = false
        closeButton.contentTintColor = NSColor.white.withAlphaComponent(0.7)
        closeButton.target = self
        closeButton.action = #selector(closeTapped)
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        // artwork + title/artist; tapping it opens Spotify
        albumArtView.translatesAutoresizingMaskIntoConstraints = false
        albumArtView.imageScaling = .scaleProportionallyUpOrDown
        albumArtView.isHidden = true
        albumArtView.wantsLayer = true
        albumArtView.layer?.cornerRadius = 4
        albumArtView.layer?.masksToBounds = true
        albumArtView.widthAnchor.constraint(equalToConstant: 28).isActive = true
        albumArtView.heightAnchor.constraint(equalToConstant: 28).isActive = true

        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.heightAnchor.constraint(equalToConstant: 15).isActive = true

        artistLabel.font = NSFont.systemFont(ofSize: 10.5, weight: .regular)
        artistLabel.textColor = NSColor.white.withAlphaComponent(0.6)
        artistLabel.lineBreakMode = .byTruncatingTail
        artistLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 0
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(artistLabel)
        titleLabel.widthAnchor.constraint(equalTo: textStack.widthAnchor).isActive = true
        artistLabel.widthAnchor.constraint(lessThanOrEqualTo: textStack.widthAnchor).isActive = true

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.orientation = .horizontal
        contentStack.alignment = .centerY
        contentStack.spacing = 8
        contentStack.addArrangedSubview(albumArtView)
        contentStack.addArrangedSubview(textStack)

        // only the track area opens Spotify, so the control buttons don't also bring it forward
        let contentTap = NSClickGestureRecognizer(target: self, action: #selector(toggleSpotify))
        contentTap.allowedTouchTypes = [.direct]
        contentStack.addGestureRecognizer(contentTap)

        controlsStack.translatesAutoresizingMaskIntoConstraints = false
        controlsStack.orientation = .horizontal
        controlsStack.alignment = .centerY
        controlsStack.distribution = .fillEqually
        controlsStack.spacing = 6

        let previousButton = makeControlButton(symbolName: "backward.fill", fallbackTitle: "<<", action: #selector(previousTrack))
        let playButton = makeControlButton(symbolName: "play.fill", fallbackTitle: ">", action: #selector(playPause))
        let nextButton = makeControlButton(symbolName: "forward.fill", fallbackTitle: ">>", action: #selector(nextTrack))
        playPauseButton = playButton
        controlButtons = [previousButton, playButton, nextButton]
        controlButtons.forEach { button in
            controlsStack.addArrangedSubview(button)
            button.widthAnchor.constraint(equalToConstant: 46).isActive = true
            button.heightAnchor.constraint(equalToConstant: 30).isActive = true
        }

        for label in [elapsedLabel, remainingLabel] {
            label.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
            label.textColor = NSColor.white.withAlphaComponent(0.6)
            label.translatesAutoresizingMaskIntoConstraints = false
        }
        elapsedLabel.alignment = .right
        remainingLabel.alignment = .left

        progressSlider.target = self
        progressSlider.action = #selector(scrub(_:))
        progressSlider.isContinuous = true
        progressSlider.trackFillColor = .white
        progressSlider.isEnabled = false
        progressSlider.translatesAutoresizingMaskIntoConstraints = false

        equalizerView.translatesAutoresizingMaskIntoConstraints = false

        // the equalizer goes first so it stays behind everything in full-width mode
        [equalizerView, closeButton, contentStack, controlsStack, elapsedLabel, progressSlider, remainingLabel].forEach(addSubview)
        // a wide slot gives way before the progress bar's minimum width
        equalizerWidth.priority = .defaultHigh

        // the title gives up width before the progress bar does
        let preferredTextWidth = textStack.widthAnchor.constraint(equalToConstant: 200)
        preferredTextWidth.priority = .defaultLow

        NSLayoutConstraint.activate([
            closeButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeWidth,
            closeButton.heightAnchor.constraint(equalTo: heightAnchor),

            contentStack.leadingAnchor.constraint(equalTo: closeButton.trailingAnchor, constant: 6),
            contentStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            contentStack.heightAnchor.constraint(equalTo: heightAnchor),
            textStack.widthAnchor.constraint(lessThanOrEqualToConstant: 200),
            textStack.widthAnchor.constraint(greaterThanOrEqualToConstant: 90),
            preferredTextWidth,

            controlsStack.leadingAnchor.constraint(equalTo: contentStack.trailingAnchor, constant: 12),
            controlsStack.centerYAnchor.constraint(equalTo: centerYAnchor),

            elapsedLabel.leadingAnchor.constraint(equalTo: controlsStack.trailingAnchor, constant: 12),
            elapsedLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            elapsedLabel.widthAnchor.constraint(equalToConstant: 38),

            progressSlider.leadingAnchor.constraint(equalTo: elapsedLabel.trailingAnchor, constant: 6),
            progressSlider.centerYAnchor.constraint(equalTo: centerYAnchor),
            progressSlider.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),

            remainingLabel.leadingAnchor.constraint(equalTo: progressSlider.trailingAnchor, constant: 6),
            remainingLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            remainingLabel.widthAnchor.constraint(equalToConstant: 42)
        ])
        NSLayoutConstraint.activate(slotConstraints)

        titleLabel.stringValue = SpotifyWidgetStatus.closed.message

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettingsChange(_:)),
            name: .spotifyWidgetSettingsDidChange,
            object: nil
        )
    }

    private func symbol(_ name: String, size: CGFloat) -> NSImage? {
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil) else { return nil }
        return image.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: size, weight: .semibold)) ?? image
    }

    private func makeControlButton(symbolName: String, fallbackTitle: String, action: Selector) -> NSButton {
        let button = NSButton(title: fallbackTitle, target: self, action: action)
        button.bezelStyle = .rounded
        button.wantsLayer = true
        button.translatesAutoresizingMaskIntoConstraints = false

        if let image = symbol(symbolName, size: 13) {
            button.image = image
            button.imagePosition = .imageOnly
        } else {
            button.imagePosition = .noImage
            button.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        }

        applyButtonStyle(button, style: currentSettings.buttonStyle)
        return button
    }

    private func applyButtonStyle(_ button: NSButton, style: ControlButtonStyle) {
        let tint = currentSettings.accentColor.color
        button.image?.isTemplate = true

        switch style {
        case .native:
            // the system's own Touch Bar key look
            button.isBordered = true
            button.bezelStyle = .rounded
            button.contentTintColor = nil
            button.layer?.backgroundColor = nil
            button.layer?.borderWidth = 0
            button.layer?.cornerRadius = 0
        case .icon:
            button.isBordered = false
            button.contentTintColor = tint
            button.layer?.backgroundColor = nil
            button.layer?.borderColor = nil
            button.layer?.borderWidth = 0
            button.layer?.cornerRadius = 0
        case .filled:
            button.isBordered = false
            button.contentTintColor = tint
            button.layer?.backgroundColor = tint.withAlphaComponent(0.18).cgColor
            button.layer?.borderColor = tint.withAlphaComponent(0.28).cgColor
            button.layer?.borderWidth = 0.8
            button.layer?.cornerRadius = 6
        case .pill:
            button.isBordered = false
            button.contentTintColor = tint
            button.layer?.backgroundColor = tint.withAlphaComponent(0.12).cgColor
            button.layer?.borderColor = tint.withAlphaComponent(0.22).cgColor
            button.layer?.borderWidth = 0.8
            button.layer?.cornerRadius = 15
        case .glass:
            button.isBordered = false
            button.contentTintColor = tint
            button.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.12).cgColor
            button.layer?.borderColor = tint.withAlphaComponent(0.22).cgColor
            button.layer?.borderWidth = 0.6
            button.layer?.cornerRadius = 8
        }
    }

    public func startObservingSpotify() {
        guard !isObserving else { return }
        isObserving = true

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleSpotifyPlaybackChange(_:)),
            name: SpotifyClient.playbackStateChanged,
            object: nil
        )

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceCenter.addObserver(self, selector: #selector(handleApplicationChange(_:)), name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        workspaceCenter.addObserver(self, selector: #selector(handleApplicationChange(_:)), name: NSWorkspace.didTerminateApplicationNotification, object: nil)

        // Spotify posts a notification on every change; the timer only catches missed ones
        // and keeps the progress bar in step with Spotify.
        let timer = Timer(timeInterval: 20, target: self, selector: #selector(updateSpotifyInfo), userInfo: nil, repeats: true)
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer

        updateSpotifyInfo()
    }

    public func stopObservingSpotify() {
        guard isObserving else { return }
        isObserving = false

        DistributedNotificationCenter.default().removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        refreshTimer?.invalidate()
        refreshTimer = nil
        setProgressTimer(running: false)
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
        if settings.equalizerFullWidth {
            NSLayoutConstraint.deactivate(slotConstraints)
            NSLayoutConstraint.activate(fullWidthConstraints)
            equalizerView.alphaValue = 0.35
        } else {
            NSLayoutConstraint.deactivate(fullWidthConstraints)
            NSLayoutConstraint.activate(slotConstraints)
            equalizerView.alphaValue = 1
        }
        equalizerWidth.constant = CGFloat(settings.equalizerWidth)
        controlButtons.forEach { button in
            applyButtonStyle(button, style: settings.buttonStyle)
        }
        showArtwork()
        loadArtworkIfNeeded(for: status.track)
    }

    @objc private func handleSpotifyPlaybackChange(_ notification: Notification) {
        if let newStatus = SpotifyClient.status(from: notification.userInfo) {
            applyStatus(newStatus)
        } else {
            updateSpotifyInfo()
        }
    }

    @objc private func handleApplicationChange(_ notification: Notification) {
        let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        guard app?.bundleIdentifier == SpotifyClient.bundleIdentifier else { return }
        if notification.name == NSWorkspace.didTerminateApplicationNotification {
            applyStatus(.closed)
        } else {
            // give Spotify a moment to answer AppleScript
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.updateSpotifyInfo() }
        }
    }

    @objc private func updateSpotifyInfo() {
        DispatchQueue.global(qos: .utility).async {
            let status = SpotifyClient.currentStatus()
            DispatchQueue.main.async {
                self.applyStatus(status)
            }
        }
    }

    private func applyStatus(_ newStatus: SpotifyWidgetStatus) {
        let previousTrackID = status.track?.id
        status = newStatus

        let track = newStatus.track
        titleLabel.stringValue = track?.name ?? newStatus.message
        artistLabel.stringValue = track?.artist ?? ""

        let isPlaying: Bool
        switch newStatus {
        case .playing:
            isPlaying = true
            titleLabel.alphaValue = 1
            titleLabel.startMarqueeIfNeeded()
            equalizerView.startAnimation()
        case .paused, .closed:
            isPlaying = false
            titleLabel.alphaValue = 0.6
            titleLabel.stopMarquee()
            equalizerView.stopAnimation()
        }
        playPauseButton?.image = symbol(isPlaying ? "pause.fill" : "play.fill", size: 13)

        // progress
        if let track = track {
            if track.duration > 0 { duration = track.duration }
            if let trackPosition = track.position {
                position = trackPosition
                positionDate = Date()
            } else if track.id != previousTrackID {
                position = 0
                positionDate = Date()
            } else {
                position = currentPosition(wasPlaying: !isPlaying)
                positionDate = Date()
            }
        } else {
            duration = 0
            position = 0
        }
        progressSlider.isEnabled = track != nil && duration > 0
        setProgressTimer(running: isPlaying)
        updateProgress()

        if track?.id != artworkTrackID {
            artworkTrackID = nil
            artworkImage = nil
            artworkPalette = []
            showArtwork()
        }
        loadArtworkIfNeeded(for: track)
    }

    // MARK: - Progress

    private var isPlaying: Bool {
        if case .playing = status { return true }
        return false
    }

    private func currentPosition(wasPlaying: Bool? = nil) -> Double {
        let advancing = wasPlaying ?? isPlaying
        let value = advancing ? position + Date().timeIntervalSince(positionDate) : position
        return duration > 0 ? min(max(0, value), duration) : max(0, value)
    }

    private func setProgressTimer(running: Bool) {
        if running, progressTimer == nil {
            let timer = Timer(timeInterval: 0.5, target: self, selector: #selector(progressTick), userInfo: nil, repeats: true)
            timer.tolerance = 0.1
            RunLoop.main.add(timer, forMode: .common)
            progressTimer = timer
        } else if !running {
            progressTimer?.invalidate()
            progressTimer = nil
        }
    }

    @objc private func progressTick() {
        guard !isScrubbing else { return }
        updateProgress()
    }

    private func updateProgress(showing value: Double? = nil) {
        let shown = value ?? currentPosition()
        if duration > 0 {
            progressSlider.doubleValue = shown / duration
            elapsedLabel.stringValue = formatTime(shown)
            remainingLabel.stringValue = "-" + formatTime(duration - shown)
        } else {
            progressSlider.doubleValue = 0
            elapsedLabel.stringValue = "0:00"
            remainingLabel.stringValue = "0:00"
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let total = Int(max(0, seconds).rounded(.down))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    @objc private func scrub(_ sender: NSSlider) {
        guard duration > 0 else { return }
        isScrubbing = true
        let target = sender.doubleValue * duration
        updateProgress(showing: target)

        // seek once the finger rests or lifts, not on every pixel of the drag
        pendingSeek?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            SpotifyClient.seek(to: target)
            self.position = target
            self.positionDate = Date()
            self.isScrubbing = false
            self.updateProgress()
        }
        pendingSeek = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        onClose?()
    }

    @objc private func previousTrack() {
        SpotifyClient.send("previous track")
    }

    @objc private func playPause() {
        SpotifyClient.send("playpause")
    }

    @objc private func nextTrack() {
        SpotifyClient.send("next track")
    }

    @objc private func toggleSpotify() {
        // debounce repeated toggles
        if let last = lastToggleTime, Date().timeIntervalSince(last) < 0.8 {
            return
        }
        lastToggleTime = Date()
        SpotifyClient.openOrActivate()
    }

    // MARK: - Artwork

    private func loadArtworkIfNeeded(for track: SpotifyTrack?) {
        guard let track = track, !track.id.isEmpty,
              currentSettings.useArtworkColors || currentSettings.showAlbumArtwork,
              artworkTrackID != track.id else { return }
        artworkTrackID = track.id

        DispatchQueue.global(qos: .utility).async {
            // the playback notification carries no artwork URL; ask Spotify once for this track
            var url = track.artworkURL
            if url == nil, let current = SpotifyClient.currentStatus().track, current.id == track.id {
                url = current.artworkURL
            }
            guard let artworkURL = url else { return }

            URLSession.shared.dataTask(with: artworkURL) { data, _, _ in
                guard let data = data, let image = NSImage(data: data) else { return }
                let palette = ArtworkColorExtractor.palette(from: data, count: 7)
                DispatchQueue.main.async {
                    guard self.artworkTrackID == track.id else { return }
                    self.artworkImage = image
                    self.artworkPalette = palette
                    self.showArtwork()
                }
            }.resume()
        }
    }

    private func showArtwork() {
        if currentSettings.showAlbumArtwork, let image = artworkImage {
            albumArtView.image = image
            albumArtView.isHidden = false
        } else {
            albumArtView.image = nil
            albumArtView.isHidden = true
        }

        if currentSettings.useArtworkColors, !artworkPalette.isEmpty {
            equalizerView.ambientColors = artworkPalette
        } else {
            let c = currentSettings.accentColor.color
            equalizerView.ambientColors = [c, c.withAlphaComponent(0.72)]
        }
    }
}
