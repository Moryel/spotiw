import AppKit
import PockKit

public final class SpotifyWidget: NSObject, PKWidget {
    public static let identifier = "com.yuksel.spotiw"

    public var customizationLabel = "Spotify"
    public var view: NSView!

    private let widgetView = SpotifyWidgetView(frame: NSRect(x: 0, y: 0, width: 260, height: 30))

    public required override init() {
        super.init()
        view = widgetView
    }

    public func viewWillAppear() {
        widgetView.startObservingSpotify()
    }

    public func viewWillDisappear() {
        widgetView.stopObservingSpotify()
    }

    deinit {
        widgetView.stopObservingSpotify()
    }
}
