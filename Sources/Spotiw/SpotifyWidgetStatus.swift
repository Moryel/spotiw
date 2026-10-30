import Foundation

public struct SpotifyTrack: Equatable {
    public var id: String
    public var name: String
    public var artist: String
    public var artworkURL: URL?
    /// seconds; 0 when unknown
    public var duration: Double = 0
    /// seconds, at the moment the status was read
    public var position: Double?

    public var title: String {
        artist.isEmpty ? name : "\(name) - \(artist)"
    }
}

public enum SpotifyWidgetStatus: Equatable {
    case playing(SpotifyTrack)
    case paused(SpotifyTrack?)
    case closed

    public var track: SpotifyTrack? {
        switch self {
        case .playing(let track):
            return track
        case .paused(let track):
            return track
        case .closed:
            return nil
        }
    }

    public var message: String {
        switch self {
        case .playing(let track):
            return track.title
        case .paused(let track):
            return track?.title ?? "Spotify paused"
        case .closed:
            return "Spotify is not open"
        }
    }
}
