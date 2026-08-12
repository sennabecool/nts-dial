import Foundation

struct Station: Identifiable, Hashable {
    enum Kind: Hashable {
        case radio
        case mixtape
    }

    let id: String
    let displayName: String
    let playlistResource: String
    let kind: Kind
}

enum StationCatalog {
    static let radioOne = Station(
        id: "radio-1",
        displayName: "NTS Radio 1",
        playlistResource: "nts-radio-1",
        kind: .radio
    )

    static let radioTwo = Station(
        id: "radio-2",
        displayName: "NTS Radio 2",
        playlistResource: "nts-radio-2",
        kind: .radio
    )

    static let defaultMixtape = Station(
        id: "poolside",
        displayName: "Poolside",
        playlistResource: "nts-poolside",
        kind: .mixtape
    )

    static let mixtapes: [Station] = [
        defaultMixtape,
        Station(id: "slow-focus", displayName: "Slow Focus", playlistResource: "nts-slow-focus", kind: .mixtape),
        Station(id: "low-key", displayName: "Low Key", playlistResource: "nts-low-key", kind: .mixtape),
        Station(id: "memory-lane", displayName: "Memory Lane", playlistResource: "nts-memory-lane", kind: .mixtape),
        Station(id: "4-to-the-floor", displayName: "4 to the Floor", playlistResource: "nts-4-to-the-floor", kind: .mixtape),
        Station(id: "island-time", displayName: "Island Time", playlistResource: "nts-island-time", kind: .mixtape),
        Station(id: "the-tube", displayName: "The Tube", playlistResource: "nts-the-tube", kind: .mixtape),
        Station(id: "sheet-music", displayName: "Sheet Music", playlistResource: "nts-sheet-music", kind: .mixtape),
        Station(id: "feelings", displayName: "Feelings", playlistResource: "nts-feelings", kind: .mixtape),
        Station(id: "expansions", displayName: "Expansions", playlistResource: "nts-expansions", kind: .mixtape),
        Station(id: "labyrinth", displayName: "Labyrinth", playlistResource: "nts-labyrinth", kind: .mixtape),
        Station(id: "sweat", displayName: "Sweat", playlistResource: "nts-sweat", kind: .mixtape),
        Station(id: "otaku", displayName: "Otaku", playlistResource: "nts-otaku", kind: .mixtape),
        Station(id: "the-pit", displayName: "The Pit", playlistResource: "nts-the-pit", kind: .mixtape),
        Station(id: "rap-house", displayName: "Rap House", playlistResource: "nts-rap-house", kind: .mixtape),
        Station(id: "field-recordings", displayName: "Field Recordings", playlistResource: "nts-field-recordings", kind: .mixtape),
    ]

    static let allSources = [radioOne, radioTwo] + mixtapes
}
