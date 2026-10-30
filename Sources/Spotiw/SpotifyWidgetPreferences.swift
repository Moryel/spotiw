import AppKit

public final class SpotifyWidgetPreferences: NSViewController {
    private let stylePopup = NSPopUpButton()
    private let colorPopup = NSPopUpButton()
    private let widthSlider = NSSlider(value: 46, minValue: 30, maxValue: 400, target: nil, action: nil)
    private let widthValueLabel = NSTextField(labelWithString: "")
    private let fullWidthButton = NSButton(checkboxWithTitle: "Fill the whole Touch Bar", target: nil, action: nil)
    private let sensitivitySlider = NSSlider(value: 1.0, minValue: 0.5, maxValue: 3.0, target: nil, action: nil)
    private let speedSlider = NSSlider(value: 1.0, minValue: 0.5, maxValue: 2.0, target: nil, action: nil)
    private let animationDurationSlider = NSSlider(value: 0.12, minValue: 0.05, maxValue: 0.5, target: nil, action: nil)
    private let buttonStylePopup = NSPopUpButton()
    private let albumArtworkButton = NSButton(checkboxWithTitle: "Show album art", target: nil, action: nil)
    private let showOnLaunchButton = NSButton(checkboxWithTitle: "Show on Touch Bar at launch", target: nil, action: nil)
    private let controlStripButton = NSButton(checkboxWithTitle: "Keep volume / brightness strip", target: nil, action: nil)
    private let resetButton = NSButton(title: "Reset to Defaults", target: nil, action: nil)

    /// First entry of the color menu; the rest are `WidgetAccentColor.allCases`.
    private let albumColorTitle = "Album cover"

    public override func loadView() {
        view = NSView()
        setupView()
        loadSettings()
    }

    public func reset() {
        SpotifyWidgetSettingsStore.shared.reset()
        loadSettings()
    }

    private func setupView() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        stylePopup.addItems(withTitles: EqualizerStyle.allCases.map(\.title))
        colorPopup.addItems(withTitles: [albumColorTitle] + WidgetAccentColor.allCases.map(\.title))
        colorPopup.menu?.insertItem(.separator(), at: 1)
        buttonStylePopup.addItems(withTitles: ControlButtonStyle.allCases.map(\.title))

        widthValueLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        widthValueLabel.textColor = .secondaryLabelColor
        widthValueLabel.widthAnchor.constraint(equalToConstant: 48).isActive = true

        for control in [stylePopup, colorPopup, widthSlider, fullWidthButton, sensitivitySlider, speedSlider,
                        animationDurationSlider, buttonStylePopup, albumArtworkButton, showOnLaunchButton, controlStripButton] {
            control.target = self
            control.action = #selector(updateSettings)
        }
        resetButton.target = self
        resetButton.action = #selector(resetSettings)

        let widthRow = NSStackView(views: [widthSlider, widthValueLabel])
        widthRow.spacing = 6
        widthSlider.widthAnchor.constraint(equalToConstant: 160).isActive = true

        stack.addArrangedSubview(makeHeader("Sound bar"))
        stack.addArrangedSubview(makeRow(label: "Style", control: stylePopup))
        stack.addArrangedSubview(makeRow(label: "Color", control: colorPopup))
        stack.addArrangedSubview(makeRow(label: "Width", control: widthRow, fixedWidth: false))
        stack.addArrangedSubview(makeRow(label: "", control: fullWidthButton))
        stack.addArrangedSubview(makeRow(label: "Sensitivity", control: sensitivitySlider))
        stack.addArrangedSubview(makeRow(label: "Speed", control: speedSlider))
        stack.addArrangedSubview(makeRow(label: "Smoothness", control: animationDurationSlider))

        stack.addArrangedSubview(makeHeader("Buttons"))
        stack.addArrangedSubview(makeRow(label: "Style", control: buttonStylePopup))

        stack.addArrangedSubview(makeHeader("Track"))
        stack.addArrangedSubview(makeRow(label: "", control: albumArtworkButton))

        stack.addArrangedSubview(makeHeader("Touch Bar"))
        stack.addArrangedSubview(makeRow(label: "", control: showOnLaunchButton))
        stack.addArrangedSubview(makeRow(label: "", control: controlStripButton))

        stack.setCustomSpacing(18, after: stack.arrangedSubviews.last!)
        stack.addArrangedSubview(resetButton)

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -18)
        ])
    }

    private func makeHeader(_ title: String) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        let container = NSStackView(views: [label])
        container.edgeInsets = NSEdgeInsets(top: 8, left: 0, bottom: 0, right: 0)
        return container
    }

    private func makeRow(label: String, control: NSView, fixedWidth: Bool = true) -> NSView {
        let titleLabel = NSTextField(labelWithString: label)
        titleLabel.font = NSFont.systemFont(ofSize: 12)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.alignment = .right
        titleLabel.widthAnchor.constraint(equalToConstant: 84).isActive = true

        if fixedWidth {
            control.widthAnchor.constraint(equalToConstant: 214).isActive = true
        }

        let row = NSStackView(views: [titleLabel, control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        return row
    }

    private func loadSettings() {
        let settings = SpotifyWidgetSettingsStore.shared.settings
        stylePopup.selectItem(at: EqualizerStyle.allCases.firstIndex(of: settings.equalizerStyle) ?? 0)
        if settings.useArtworkColors {
            colorPopup.selectItem(withTitle: albumColorTitle)
        } else {
            colorPopup.selectItem(withTitle: settings.accentColor.title)
        }
        widthSlider.doubleValue = settings.equalizerWidth
        fullWidthButton.state = settings.equalizerFullWidth ? .on : .off
        sensitivitySlider.doubleValue = settings.equalizerSensitivity
        speedSlider.doubleValue = settings.equalizerSpeed
        animationDurationSlider.doubleValue = settings.equalizerAnimationDuration
        buttonStylePopup.selectItem(at: ControlButtonStyle.allCases.firstIndex(of: settings.buttonStyle) ?? 0)
        albumArtworkButton.state = settings.showAlbumArtwork ? .on : .off
        showOnLaunchButton.state = settings.showOnLaunch ? .on : .off
        controlStripButton.state = settings.keepControlStrip ? .on : .off
        updateWidthControls()
    }

    private func updateWidthControls() {
        let full = fullWidthButton.state == .on
        widthSlider.isEnabled = !full
        widthValueLabel.stringValue = full ? "Full" : "\(Int(widthSlider.doubleValue)) pt"
    }

    @objc private func updateSettings() {
        let current = SpotifyWidgetSettingsStore.shared.settings
        let styleIndex = max(0, stylePopup.indexOfSelectedItem)
        let buttonStyleIndex = max(0, buttonStylePopup.indexOfSelectedItem)
        let colorTitle = colorPopup.titleOfSelectedItem ?? albumColorTitle
        let useArtworkColors = colorTitle == albumColorTitle
        // "Album cover" keeps the last fixed color for the buttons
        let accentColor = WidgetAccentColor.allCases.first { $0.title == colorTitle } ?? current.accentColor

        updateWidthControls()
        SpotifyWidgetSettingsStore.shared.settings = SpotifyWidgetSettings(
            equalizerStyle: EqualizerStyle.allCases[styleIndex],
            accentColor: accentColor,
            useArtworkColors: useArtworkColors,
            buttonStyle: ControlButtonStyle.allCases[buttonStyleIndex],
            showAlbumArtwork: albumArtworkButton.state == .on,
            equalizerSensitivity: sensitivitySlider.doubleValue,
            equalizerSpeed: speedSlider.doubleValue,
            equalizerAnimationDuration: animationDurationSlider.doubleValue,
            showOnLaunch: showOnLaunchButton.state == .on,
            keepControlStrip: controlStripButton.state == .on,
            equalizerWidth: widthSlider.doubleValue.rounded(),
            equalizerFullWidth: fullWidthButton.state == .on
        )
    }

    @objc private func resetSettings() {
        reset()
    }
}
