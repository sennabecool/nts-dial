import Foundation

enum PlaylistParserError: LocalizedError {
    case missingPlaylist(String)
    case unreadablePlaylist(String)
    case missingStreamURL(String)
    case insecureStreamURL(String)

    var errorDescription: String? {
        switch self {
        case .missingPlaylist(let name):
            return "Missing playlist: \(name)"
        case .unreadablePlaylist(let name):
            return "Cannot read playlist: \(name)"
        case .missingStreamURL(let name):
            return "No stream URL in \(name)"
        case .insecureStreamURL(let name):
            return "Invalid HTTPS stream in \(name)"
        }
    }
}

enum PlaylistParser {
    static func streamURL(for station: Station, bundle: Bundle = .main) throws -> URL {
        guard let playlistURL = bundle.url(forResource: station.playlistResource, withExtension: "m3u") else {
            throw PlaylistParserError.missingPlaylist(station.displayName)
        }

        guard let contents = try? String(contentsOf: playlistURL, encoding: .utf8) else {
            throw PlaylistParserError.unreadablePlaylist(station.displayName)
        }

        guard let rawURL = contents
            .components(separatedBy: .newlines)
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { !$0.isEmpty && !$0.hasPrefix("#") }),
              let url = URL(string: rawURL) else {
            throw PlaylistParserError.missingStreamURL(station.displayName)
        }

        guard url.scheme?.lowercased() == "https", url.host != nil else {
            throw PlaylistParserError.insecureStreamURL(station.displayName)
        }

        return url
    }
}
