import Foundation

public enum SpotifyWidgetStatus: Equatable {
    case playing(String)
    case paused
    case closed

    public var message: String {
        switch self {
        case .playing(let text):
            return text
        case .paused:
            return "Spotify paused"
        case .closed:
            return "Spotify is not open"
        }
    }
}
