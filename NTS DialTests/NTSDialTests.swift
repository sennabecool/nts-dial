import Foundation
import XCTest
@testable import NTS_Dial

final class PlaylistParserTests: XCTestCase {
    func testReturnsFirstHTTPSStreamIgnoringCommentsAndWhitespace() throws {
        let bundle = try makeBundle(
            playlistName: "valid",
            contents: """
            #EXTM3U

              https://stream.example.com/live\u{20}\u{20}
            https://stream.example.com/ignored
            """
        )
        let station = makeStation(playlistResource: "valid")

        let url = try PlaylistParser.streamURL(for: station, bundle: bundle)

        XCTAssertEqual(url, URL(string: "https://stream.example.com/live"))
    }

    func testReportsMissingPlaylist() throws {
        let bundle = try makeBundle()
        let station = makeStation(playlistResource: "missing")

        XCTAssertThrowsError(try PlaylistParser.streamURL(for: station, bundle: bundle)) { error in
            guard let parserError = error as? PlaylistParserError,
                  case .missingPlaylist(let name) = parserError else {
                return XCTFail("Expected missingPlaylist, got \(error)")
            }
            XCTAssertEqual(name, station.displayName)
        }
    }

    func testReportsPlaylistWithoutStreamURL() throws {
        let bundle = try makeBundle(playlistName: "empty", contents: "#EXTM3U\n# no stream")
        let station = makeStation(playlistResource: "empty")

        XCTAssertThrowsError(try PlaylistParser.streamURL(for: station, bundle: bundle)) { error in
            guard let parserError = error as? PlaylistParserError,
                  case .missingStreamURL(let name) = parserError else {
                return XCTFail("Expected missingStreamURL, got \(error)")
            }
            XCTAssertEqual(name, station.displayName)
        }
    }

    func testRejectsInsecureStreamURL() throws {
        let bundle = try makeBundle(playlistName: "insecure", contents: "http://stream.example.com/live")
        let station = makeStation(playlistResource: "insecure")

        XCTAssertThrowsError(try PlaylistParser.streamURL(for: station, bundle: bundle)) { error in
            guard let parserError = error as? PlaylistParserError,
                  case .insecureStreamURL(let name) = parserError else {
                return XCTFail("Expected insecureStreamURL, got \(error)")
            }
            XCTAssertEqual(name, station.displayName)
        }
    }

    private func makeStation(playlistResource: String) -> Station {
        Station(
            id: "test",
            displayName: "Test Station",
            playlistResource: playlistResource,
            kind: .radio
        )
    }

    private func makeBundle(playlistName: String? = nil, contents: String = "") throws -> Bundle {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("bundle")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }

        if let playlistName {
            try contents.write(
                to: directory.appendingPathComponent(playlistName).appendingPathExtension("m3u"),
                atomically: true,
                encoding: .utf8
            )
        }

        return try XCTUnwrap(Bundle(path: directory.path))
    }
}

final class PlaybackStateTests: XCTestCase {
    func testOnlyLoadingAndPlayingAreEngaged() {
        XCTAssertFalse(PlaybackState.stopped.isEngaged)
        XCTAssertTrue(PlaybackState.loading.isEngaged)
        XCTAssertTrue(PlaybackState.playing.isEngaged)
        XCTAssertFalse(PlaybackState.failed("Network unavailable").isEngaged)
    }

    func testOnlyFailureExposesAnErrorMessage() {
        XCTAssertNil(PlaybackState.stopped.errorMessage)
        XCTAssertNil(PlaybackState.loading.errorMessage)
        XCTAssertNil(PlaybackState.playing.errorMessage)
        XCTAssertEqual(PlaybackState.failed("Network unavailable").errorMessage, "Network unavailable")
    }
}

@MainActor
final class StationCatalogTests: XCTestCase {
    func testCatalogHasUniqueIdentifiersAndPlaylistResources() {
        let stations = StationCatalog.allSources

        XCTAssertEqual(Set(stations.map(\.id)).count, stations.count)
        XCTAssertEqual(Set(stations.map(\.playlistResource)).count, stations.count)
        XCTAssertEqual(stations.filter { $0.kind == .radio }.count, 2)
        XCTAssertEqual(stations.filter { $0.kind == .mixtape }.count, StationCatalog.mixtapes.count)
        XCTAssertTrue(StationCatalog.mixtapes.contains(StationCatalog.defaultMixtape))
    }

    func testEveryCatalogStationHasAValidBundledHTTPSPlaylist() {
        for station in StationCatalog.allSources {
            XCTAssertNoThrow(
                try PlaylistParser.streamURL(for: station),
                "Invalid bundled playlist for \(station.displayName)"
            )
        }
    }
}

@MainActor
final class RadioPlayerInteractionTests: XCTestCase {
    func testCanceledStationPressDoesNotChangePlayback() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let player = RadioPlayer(defaults: defaults)

        player.beginStationButtonPress(StationCatalog.radioOne)
        player.endStationButtonPress(StationCatalog.radioOne)

        XCTAssertNil(player.activeStation)
        XCTAssertEqual(player.playbackState, .stopped)
        XCTAssertNil(player.stationPressedWhileActiveID)
    }

    func testMixtapeSelectionIsPersisted() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let player = RadioPlayer(defaults: defaults)
        let station = try XCTUnwrap(StationCatalog.mixtapes.first { $0.id == "slow-focus" })

        player.selectMixtape(station)

        XCTAssertEqual(player.selectedMixtape, station)
        XCTAssertEqual(defaults.string(forKey: "selectedMixtapeID"), station.id)
    }

    private func makeDefaults() throws -> (UserDefaults, String) {
        let suiteName = "NTSDialTests.\(UUID().uuidString)"
        return (try XCTUnwrap(UserDefaults(suiteName: suiteName)), suiteName)
    }
}
