import AppKit

/// Talks to the Spotify app. State reads go through one osascript call;
/// whether Spotify is running is answered by NSWorkspace, without AppleScript.
enum SpotifyClient {
    static let bundleIdentifier = "com.spotify.client"
    static let playbackStateChanged = NSNotification.Name("com.spotify.client.PlaybackStateChanged")

    private static let fieldSeparator = "\u{1F}"

    private static let stateScript = """
tell application "Spotify"
    set playerState to player state as string
    try
        set t to current track
        set positionMs to ((player position * 1000) as integer) as string
        return playerState & "\(fieldSeparator)" & (id of t) & "\(fieldSeparator)" & (name of t) & "\(fieldSeparator)" & (artist of t) & "\(fieldSeparator)" & (artwork url of t) & "\(fieldSeparator)" & ((duration of t) as string) & "\(fieldSeparator)" & positionMs
    on error
        return playerState
    end try
end tell
"""

    static var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty
    }

    /// Blocking; call off the main thread.
    static func currentStatus() -> SpotifyWidgetStatus {
        guard isRunning else { return .closed }

        let fields = runAppleScript(stateScript).components(separatedBy: fieldSeparator)
        let state = fields.first ?? ""
        var track: SpotifyTrack?
        if fields.count >= 4 {
            track = SpotifyTrack(
                id: fields[1],
                name: fields[2],
                artist: fields[3],
                artworkURL: fields.count >= 5 ? URL(string: fields[4]) : nil,
                duration: fields.count >= 6 ? (Double(fields[5]) ?? 0) / 1000 : 0,
                position: fields.count >= 7 ? Double(fields[6]).map { $0 / 1000 } : nil
            )
        }

        switch state {
        case "playing":
            return track.map { .playing($0) } ?? .paused(nil)
        case "paused", "stopped":
            return .paused(track)
        default:
            // Spotify is launching or AppleScript access was denied.
            return isRunning ? .paused(nil) : .closed
        }
    }

    /// Builds a status from the userInfo of `com.spotify.client.PlaybackStateChanged`.
    /// The notification has no artwork URL, so `artworkURL` is nil.
    static func status(from userInfo: [AnyHashable: Any]?) -> SpotifyWidgetStatus? {
        guard let info = userInfo, let state = info["Player State"] as? String else { return nil }
        if state == "Stopped" && !isRunning {
            return .closed
        }

        var track: SpotifyTrack?
        if let id = info["Track ID"] as? String, let name = info["Name"] as? String {
            track = SpotifyTrack(
                id: id,
                name: name,
                artist: info["Artist"] as? String ?? "",
                artworkURL: nil,
                duration: ((info["Duration"] as? NSNumber)?.doubleValue ?? 0) / 1000,
                position: (info["Playback Position"] as? NSNumber)?.doubleValue
            )
        }

        if state == "Playing", let track = track {
            return .playing(track)
        }
        return .paused(track)
    }

    static func seek(to seconds: Double) {
        send("set player position to \(String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), max(0, seconds)))")
    }

    /// Fire and forget; does nothing when Spotify is not running.
    static func send(_ command: String) {
        guard isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            _ = runAppleScript("tell application \"Spotify\" to \(command)")
        }
    }

    static func openOrActivate() {
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first {
            app.activate(options: [])
        } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    /// The script goes in on stdin, so nothing is written to disk.
    private static func runAppleScript(_ script: String) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")

        let input = Pipe()
        let output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return ""
        }
        input.fileHandleForWriting.write(Data(script.utf8))
        try? input.fileHandleForWriting.close()

        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
