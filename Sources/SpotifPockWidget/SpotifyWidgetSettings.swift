import AppKit

public enum EqualizerStyle: String, CaseIterable {
    case bars
    case wave
    case dots

    var title: String {
        switch self {
        case .bars:
            return "Bars"
        case .wave:
            return "Wave"
        case .dots:
            return "Dots"
        }
    }
}

public enum WidgetAccentColor: String, CaseIterable {
    case green
    case blue
    case pink
    case orange
    case white

    var title: String {
        switch self {
        case .green:
            return "Green"
        case .blue:
            return "Blue"
        case .pink:
            return "Pink"
        case .orange:
            return "Orange"
        case .white:
            return "White"
        }
    }

    var color: NSColor {
        switch self {
        case .green:
            return .systemGreen
        case .blue:
            return .systemBlue
        case .pink:
            return .systemPink
        case .orange:
            return .systemOrange
        case .white:
            return .white
        }
    }
}

public enum ControlButtonStyle: String, CaseIterable {
    case icon
    case filled
    case pill
    case glass

    var title: String {
        switch self {
        case .icon:
            return "Icon"
        case .filled:
            return "Filled"
        case .pill:
            return "Pill"
        case .glass:
            return "Glass"
        }
    }
}

public struct SpotifyWidgetSettings: Equatable {
    public var equalizerStyle: EqualizerStyle
    public var accentColor: WidgetAccentColor
    public var useArtworkColors: Bool
    public var buttonStyle: ControlButtonStyle
    public var showAlbumArtwork: Bool
    public var equalizerSensitivity: Double
    public var equalizerSpeed: Double

    public static let defaults = SpotifyWidgetSettings(
        equalizerStyle: .bars,
        accentColor: .green,
        useArtworkColors: true,
        buttonStyle: .filled,
        showAlbumArtwork: false
        , equalizerSensitivity: 1.0
        , equalizerSpeed: 1.0
    )
}

public extension Notification.Name {
    static let spotifyWidgetSettingsDidChange = Notification.Name("SpotifyWidgetSettingsDidChange")
}

public final class SpotifyWidgetSettingsStore {
    public static let shared = SpotifyWidgetSettingsStore()

    private enum Key {
        static let equalizerStyle = "equalizerStyle"
        static let accentColor = "accentColor"
        static let useArtworkColors = "useArtworkColors"
        static let buttonStyle = "buttonStyle"
        static let showAlbumArtwork = "showAlbumArtwork"
        static let equalizerSensitivity = "equalizerSensitivity"
        static let equalizerSpeed = "equalizerSpeed"
    }

    private let defaults = UserDefaults(suiteName: "com.yuksel.spotiw") ?? .standard

    private init() {}

    public var settings: SpotifyWidgetSettings {
        get {
            SpotifyWidgetSettings(
                equalizerStyle: EqualizerStyle(rawValue: defaults.string(forKey: Key.equalizerStyle) ?? "") ?? SpotifyWidgetSettings.defaults.equalizerStyle,
                accentColor: WidgetAccentColor(rawValue: defaults.string(forKey: Key.accentColor) ?? "") ?? SpotifyWidgetSettings.defaults.accentColor,
                useArtworkColors: defaults.object(forKey: Key.useArtworkColors) as? Bool ?? SpotifyWidgetSettings.defaults.useArtworkColors,
                buttonStyle: ControlButtonStyle(rawValue: defaults.string(forKey: Key.buttonStyle) ?? "") ?? SpotifyWidgetSettings.defaults.buttonStyle,
                showAlbumArtwork: defaults.object(forKey: Key.showAlbumArtwork) as? Bool ?? SpotifyWidgetSettings.defaults.showAlbumArtwork
                , equalizerSensitivity: defaults.object(forKey: Key.equalizerSensitivity) as? Double ?? SpotifyWidgetSettings.defaults.equalizerSensitivity
                , equalizerSpeed: defaults.object(forKey: Key.equalizerSpeed) as? Double ?? SpotifyWidgetSettings.defaults.equalizerSpeed
            )
        }
        set {
            defaults.set(newValue.equalizerStyle.rawValue, forKey: Key.equalizerStyle)
            defaults.set(newValue.accentColor.rawValue, forKey: Key.accentColor)
            defaults.set(newValue.useArtworkColors, forKey: Key.useArtworkColors)
            defaults.set(newValue.buttonStyle.rawValue, forKey: Key.buttonStyle)
            defaults.set(newValue.showAlbumArtwork, forKey: Key.showAlbumArtwork)
            defaults.set(newValue.equalizerSensitivity, forKey: Key.equalizerSensitivity)
            defaults.set(newValue.equalizerSpeed, forKey: Key.equalizerSpeed)
            NotificationCenter.default.post(name: .spotifyWidgetSettingsDidChange, object: newValue)
        }
    }

    public func reset() {
        settings = .defaults
    }
}
