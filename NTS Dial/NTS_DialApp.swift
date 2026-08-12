import AppKit
import SwiftUI

@main
struct NTS_DialApp: App {
    @StateObject private var radioPlayer = RadioPlayer()

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(radioPlayer)
                .frame(width: 542, height: 362)
        } label: {
            MenuBarStatusIcon(
                activeStationID: radioPlayer.activeStation?.id,
                isPlaying: radioPlayer.playbackState.isEngaged
            )
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarStatusIcon: View {
    let activeStationID: String?
    let isPlaying: Bool

    private static let inactiveImage: NSImage? = {
        templateImage(named: "menu-bar-nts")
    }()

    private static let radioOneImage: NSImage? = {
        templateImage(named: "menu-bar-radio-1")
    }()

    private static let radioTwoImage: NSImage? = {
        templateImage(named: "menu-bar-radio-2")
    }()

    private static let mixtapeImages: [String: NSImage] = Dictionary(
        uniqueKeysWithValues: StationCatalog.mixtapes.compactMap { station in
            templateImage(named: "\(station.id)-icon").map { (station.id, $0) }
        }
    )

    private static func templateImage(named name: String) -> NSImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "svg"),
              let image = NSImage(contentsOf: url) else { return nil }
        image.isTemplate = true
        return image
    }

    private var accessibilityStatus: String {
        guard isPlaying else { return "Stopped" }
        guard let activeStationID,
              let station = StationCatalog.allSources.first(where: { $0.id == activeStationID }) else {
            return "Playing"
        }
        return "Playing \(station.displayName)"
    }

    var body: some View {
        Group {
        if isPlaying, activeStationID == "radio-1", let radioOneImage = Self.radioOneImage {
            Image(nsImage: radioOneImage)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
        } else if isPlaying, activeStationID == "radio-2", let radioTwoImage = Self.radioTwoImage {
            Image(nsImage: radioTwoImage)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
        } else if isPlaying,
                  let activeStationID,
                  let mixtapeImage = Self.mixtapeImages[activeStationID] {
            Image(nsImage: mixtapeImage)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
        } else if isPlaying {
            Image(systemName: "radio")
        } else if let inactiveImage = Self.inactiveImage {
            Image(nsImage: inactiveImage)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
        } else {
            Image(systemName: "radio")
        }
        }
        .transaction { $0.animation = nil }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("NTS Dial")
        .accessibilityValue(Text(accessibilityStatus))
    }
}
