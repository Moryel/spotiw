import AppKit
import PockKit

@objc(SpotifyWidgetPreferences)
public final class SpotifyWidgetPreferences: NSViewController, PKWidgetPreference {
    public static let nibName = NSNib.Name("SpotifyWidgetPreferences")

    private let stylePopup = NSPopUpButton()
    private let colorPopup = NSPopUpButton()
    private let buttonStylePopup = NSPopUpButton()
    private let artworkColorsButton = NSButton(checkboxWithTitle: "Use album colors", target: nil, action: nil)
    private let albumArtworkButton = NSButton(checkboxWithTitle: "Show album art", target: nil, action: nil)
    private let resetButton = NSButton(title: "Reset", target: nil, action: nil)
    private let sensitivitySlider = NSSlider(value: 1.0, minValue: 0.5, maxValue: 3.0, target: nil, action: nil)
    private let speedSlider = NSSlider(value: 1.0, minValue: 0.5, maxValue: 2.0, target: nil, action: nil)
    private let animationDurationSlider = NSSlider(value: 0.12, minValue: 0.05, maxValue: 0.5, target: nil, action: nil)

    public override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 230))
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
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        stylePopup.addItems(withTitles: EqualizerStyle.allCases.map(\.title))
        colorPopup.addItems(withTitles: WidgetAccentColor.allCases.map(\.title))
        buttonStylePopup.addItems(withTitles: ControlButtonStyle.allCases.map(\.title))

        stylePopup.target = self
        stylePopup.action = #selector(updateSettings)
        colorPopup.target = self
        colorPopup.action = #selector(updateSettings)
        buttonStylePopup.target = self
        buttonStylePopup.action = #selector(updateSettings)
        artworkColorsButton.target = self
        artworkColorsButton.action = #selector(updateSettings)
        albumArtworkButton.target = self
        albumArtworkButton.action = #selector(updateSettings)
        sensitivitySlider.target = self
        sensitivitySlider.action = #selector(updateSettings)
        speedSlider.target = self
        speedSlider.action = #selector(updateSettings)
        animationDurationSlider.target = self
        animationDurationSlider.action = #selector(updateSettings)
        resetButton.target = self
        resetButton.action = #selector(resetSettings)

        stack.addArrangedSubview(makeRow(label: "Soundbar", control: stylePopup))
        stack.addArrangedSubview(makeRow(label: "Color", control: colorPopup))
        stack.addArrangedSubview(makeRow(label: "Buttons", control: buttonStylePopup))
        stack.addArrangedSubview(makeRow(label: "Album colors", control: artworkColorsButton))
        stack.addArrangedSubview(makeRow(label: "Album art", control: albumArtworkButton))
        stack.addArrangedSubview(makeRow(label: "Sensitivity", control: sensitivitySlider))
        stack.addArrangedSubview(makeRow(label: "Speed", control: speedSlider))
        stack.addArrangedSubview(makeRow(label: "Animation", control: animationDurationSlider))
        stack.addArrangedSubview(resetButton)

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 18)
        ])
    }

    private func makeRow(label: String, control: NSView) -> NSView {
        let titleLabel = NSTextField(labelWithString: label)
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.widthAnchor.constraint(equalToConstant: 84).isActive = true

        control.widthAnchor.constraint(equalToConstant: 170).isActive = true

        let row = NSStackView(views: [titleLabel, control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        return row
    }

    private func loadSettings() {
        let settings = SpotifyWidgetSettingsStore.shared.settings
        stylePopup.selectItem(at: EqualizerStyle.allCases.firstIndex(of: settings.equalizerStyle) ?? 0)
        colorPopup.selectItem(at: WidgetAccentColor.allCases.firstIndex(of: settings.accentColor) ?? 0)
        buttonStylePopup.selectItem(at: ControlButtonStyle.allCases.firstIndex(of: settings.buttonStyle) ?? 0)
        artworkColorsButton.state = settings.useArtworkColors ? .on : .off
        albumArtworkButton.state = settings.showAlbumArtwork ? .on : .off
        sensitivitySlider.doubleValue = settings.equalizerSensitivity
        speedSlider.doubleValue = settings.equalizerSpeed
        animationDurationSlider.doubleValue = settings.equalizerAnimationDuration
    }

    @objc private func updateSettings() {
        let styleIndex = max(0, stylePopup.indexOfSelectedItem)
        let colorIndex = max(0, colorPopup.indexOfSelectedItem)
        let buttonStyleIndex = max(0, buttonStylePopup.indexOfSelectedItem)

        SpotifyWidgetSettingsStore.shared.settings = SpotifyWidgetSettings(
            equalizerStyle: EqualizerStyle.allCases[styleIndex],
            accentColor: WidgetAccentColor.allCases[colorIndex],
            useArtworkColors: artworkColorsButton.state == .on,
            buttonStyle: ControlButtonStyle.allCases[buttonStyleIndex],
            showAlbumArtwork: albumArtworkButton.state == .on,
            equalizerSensitivity: sensitivitySlider.doubleValue,
            equalizerSpeed: speedSlider.doubleValue,
            equalizerAnimationDuration: animationDurationSlider.doubleValue
        )
    }

    @objc private func resetSettings() {
        reset()
    }
}
