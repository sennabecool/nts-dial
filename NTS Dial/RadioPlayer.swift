import AppKit
import AVFoundation
import Combine
import Foundation
import MediaPlayer

enum PlaybackState: Equatable {
    case stopped
    case loading
    case playing
    case failed(String)

    var isEngaged: Bool {
        self == .loading || self == .playing
    }

    var errorMessage: String? {
        guard case .failed(let message) = self else { return nil }
        return message
    }
}

@MainActor
final class RadioPlayer: ObservableObject {
    @Published private(set) var activeStation: Station?
    @Published private(set) var selectedMixtape: Station
    @Published private(set) var playbackState: PlaybackState = .stopped
    @Published private(set) var loadingStartedAt = Date()
    @Published private(set) var stationPressedWhileActiveID: String?
    @Published private(set) var selectedMixtapePressedWhileActive = false
    @Published private(set) var hoveredButtonID: String?
    @Published private(set) var isMixtapeButtonHovering = false
    @Published private(set) var mixtapeWheelRotation = 0.0
    @Published private(set) var isDraggingMixtapeWheel = false

    private static let selectedMixtapeKey = "selectedMixtapeID"
    private static let playbackTimeoutNanoseconds: UInt64 = 20_000_000_000
    private static let artworkResources: [String: (name: String, extension: String)] = [
        "4-to-the-floor": ("4-to-the-floor-cover", "jpeg"),
        "expansions": ("expansions-cover", "jpeg"),
        "feelings": ("feelings-cover", "jpeg"),
        "field-recordings": ("field-recordings-cover", "png"),
        "island-time": ("island-time-cover", "jpeg"),
        "labyrinth": ("labyrinth-cover", "jpeg"),
        "low-key": ("low-key-cover", "jpeg"),
        "rap-house": ("rap-house-cover", "jpeg"),
        "radio-1": ("radio-1-cover", "png"),
        "radio-2": ("radio-2-cover", "png"),
        "poolside": ("poolside-cover", "jpeg"),
        "memory-lane": ("memory-lane-cover", "jpeg"),
        "otaku": ("otaku-cover", "jpeg"),
        "sheet-music": ("sheet-music-cover", "jpeg"),
        "slow-focus": ("slow-focus-cover", "jpeg"),
        "sweat": ("sweat-cover", "png"),
        "the-pit": ("the-pit-cover", "jpeg"),
        "the-tube": ("the-tube-cover", "jpeg"),
    ]

    private let player = AVPlayer()
    private let defaults: UserDefaults
    private var itemStatusObservation: NSKeyValueObservation?
    private var playerTimeControlObservation: NSKeyValueObservation?
    private var playbackFailureObserver: NSObjectProtocol?
    private var playbackStalledObserver: NSObjectProtocol?
    private var remoteCommandTargets: [(command: MPRemoteCommand, target: Any)] = []
    private var artworkCache: [String: MPMediaItemArtwork] = [:]
    private var pressFeedbackPlayer: AVAudioPlayer?
    private var activePressFeedbackPlayer: AVAudioPlayer?
    private var lastMixtapeWheelDragAngle: Double?
    private var lastMixtapeWheelTickDegree: Int?
    private var wheelTickPlayers: [AVAudioPlayer] = []
    private var wheelTickPlayerIndex = 0
    private var lastWheelTickPlaybackTime = 0.0
    private var wheelMotionTickTask: Task<Void, Never>?
    private var playbackTimeoutTask: Task<Void, Never>?

    var routingPlayer: AVPlayer {
        player
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let savedID = defaults.string(forKey: Self.selectedMixtapeKey),
           let savedStation = StationCatalog.mixtapes.first(where: { $0.id == savedID }) {
            selectedMixtape = savedStation
        } else {
            selectedMixtape = StationCatalog.defaultMixtape
        }
        mixtapeWheelRotation = Self.mixtapeWheelAngle(for: selectedMixtape.id) ?? 0

        if let soundURL = Bundle.main.url(forResource: "press-light", withExtension: "m4a") {
            pressFeedbackPlayer = try? AVAudioPlayer(contentsOf: soundURL)
            pressFeedbackPlayer?.prepareToPlay()
        }

        if let soundURL = Bundle.main.url(forResource: "press-dark", withExtension: "m4a") {
            activePressFeedbackPlayer = try? AVAudioPlayer(contentsOf: soundURL)
            activePressFeedbackPlayer?.prepareToPlay()
        }

        if let soundURL = Bundle.main.url(forResource: "wheel", withExtension: "mp3") {
            wheelTickPlayers = (0..<4).compactMap { _ in
                let player = try? AVAudioPlayer(contentsOf: soundURL)
                player?.prepareToPlay()
                return player
            }
        }

        configureRemoteCommands()
    }

    isolated deinit {
        wheelMotionTickTask?.cancel()
        playbackTimeoutTask?.cancel()

        if let playbackFailureObserver {
            NotificationCenter.default.removeObserver(playbackFailureObserver)
        }

        if let playbackStalledObserver {
            NotificationCenter.default.removeObserver(playbackStalledObserver)
        }

        for target in remoteCommandTargets {
            target.command.removeTarget(target.target)
        }
    }

    func toggle(_ station: Station) {
        if activeStation?.id == station.id && playbackState.isEngaged {
            stop()
        } else {
            play(station)
        }
    }

    func beginStationButtonPress(_ station: Station) {
        let wasActive = activeStation?.id == station.id && playbackState.isEngaged
        stationPressedWhileActiveID = wasActive ? station.id : nil

        if wasActive {
            playActivePressFeedback()
            return
        }

        playPressFeedback()
    }

    func completeStationButtonPress(_ station: Station) {
        if activeStation?.id == station.id, playbackState.isEngaged {
            playPressFeedback()
        }
        toggle(station)
    }

    func endStationButtonPress(_ station: Station) {
        guard stationPressedWhileActiveID == station.id else { return }
        stationPressedWhileActiveID = nil
    }

    private func playPressFeedback() {
        pressFeedbackPlayer?.currentTime = 0
        pressFeedbackPlayer?.play()
    }

    private func playActivePressFeedback() {
        activePressFeedbackPlayer?.currentTime = 0
        activePressFeedbackPlayer?.play()
    }

    private var isControlPanelOpen: Bool {
        NSApplication.shared.windows.contains {
            $0.isVisible && !$0.isMiniaturized && $0.occlusionState.contains(.visible)
        }
    }

    func toggleSelectedMixtape() {
        toggle(selectedMixtape)
    }

    func beginSelectedMixtapeButtonPress() {
        let wasActive = activeStation?.id == selectedMixtape.id && playbackState.isEngaged
        selectedMixtapePressedWhileActive = wasActive

        if wasActive {
            playActivePressFeedback()
        } else {
            playPressFeedback()
        }
    }

    func completeSelectedMixtapeButtonPress() {
        if activeStation?.id == selectedMixtape.id, playbackState.isEngaged {
            playPressFeedback()
        }
        toggleSelectedMixtape()
    }

    func endSelectedMixtapeButtonPress() {
        selectedMixtapePressedWhileActive = false
    }

    func setButtonHovering(_ stationID: String, hovering: Bool) {
        hoveredButtonID = hovering ? stationID : (hoveredButtonID == stationID ? nil : hoveredButtonID)
    }

    func setMixtapeButtonHovering(_ hovering: Bool) {
        isMixtapeButtonHovering = hovering
    }

    func selectMixtape(_ station: Station) {
        selectMixtape(station, rotatingWheel: true)
    }

    func updateMixtapeWheelDrag(at location: CGPoint, in size: CGSize) {
        wheelMotionTickTask?.cancel()
        let angle = atan2(location.y - (size.height / 2), location.x - (size.width / 2)) * 180 / .pi

        guard let lastMixtapeWheelDragAngle else {
            self.lastMixtapeWheelDragAngle = angle
            lastMixtapeWheelTickDegree = Int(floor(mixtapeWheelRotation / 2))
            isDraggingMixtapeWheel = true
            return
        }

        let previousRotation = mixtapeWheelRotation
        mixtapeWheelRotation += Self.shortestAngleDelta(from: lastMixtapeWheelDragAngle, to: angle)
        self.lastMixtapeWheelDragAngle = angle
        playWheelTicks(from: previousRotation, to: mixtapeWheelRotation)
    }

    func endMixtapeWheelDrag() {
        defer {
            lastMixtapeWheelDragAngle = nil
            lastMixtapeWheelTickDegree = nil
            isDraggingMixtapeWheel = false
        }

        let step = 360 / Double(StationCatalog.mixtapes.count)
        let normalizedRotation = mixtapeWheelRotation.truncatingRemainder(dividingBy: 360)
        let positiveRotation = normalizedRotation < 0 ? normalizedRotation + 360 : normalizedRotation
        let index = Int((positiveRotation / step).rounded()) % StationCatalog.mixtapes.count
        let station = StationCatalog.mixtapes[index]
        let targetAngle = Double(index) * step

        let snapDelta = Self.shortestAngleDelta(from: mixtapeWheelRotation, to: targetAngle)
        mixtapeWheelRotation += snapDelta
        selectMixtape(station, rotatingWheel: false)
    }

    private func selectMixtape(_ station: Station, rotatingWheel: Bool, startsPlayback: Bool = false) {
        guard station.kind == .mixtape else { return }

        let previousMixtapeID = selectedMixtape.id
        selectedMixtape = station
        defaults.set(station.id, forKey: Self.selectedMixtapeKey)
        if rotatingWheel {
            rotateMixtapeWheel(from: previousMixtapeID, to: station.id)
        }

        if startsPlayback {
            play(station)
        } else if activeStation?.kind == .mixtape && playbackState.isEngaged {
            play(station)
        } else if activeStation?.kind == .mixtape {
            activeStation = station
            publishNowPlaying(for: station, playbackRate: 0, playbackState: .paused)
        }
    }

    private static func mixtapeWheelAngle(for stationID: String) -> Double? {
        guard let index = StationCatalog.mixtapes.firstIndex(where: { $0.id == stationID }) else { return nil }
        return Double(index) * (360 / Double(StationCatalog.mixtapes.count))
    }

    private func rotateMixtapeWheel(from oldStationID: String, to newStationID: String) {
        guard let oldAngle = Self.mixtapeWheelAngle(for: oldStationID),
              let newAngle = Self.mixtapeWheelAngle(for: newStationID) else { return }

        let rotationDelta = Self.shortestAngleDelta(from: oldAngle, to: newAngle)
        mixtapeWheelRotation += rotationDelta
        playWheelMotionTicks(for: rotationDelta)
    }

    private static func shortestAngleDelta(from source: Double, to destination: Double) -> Double {
        var delta = (destination - source).truncatingRemainder(dividingBy: 360)
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        return delta
    }

    private func playWheelTicks(from previousRotation: Double, to currentRotation: Double) {
        let previousDegree = lastMixtapeWheelTickDegree ?? Int(floor(previousRotation / 2))
        let currentDegree = Int(floor(currentRotation / 2))

        guard currentDegree != previousDegree else { return }
        lastMixtapeWheelTickDegree = currentDegree
        playWheelTickIfDue()
    }

    private func playWheelTickIfDue() {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastWheelTickPlaybackTime >= (1 / 45) else { return }
        lastWheelTickPlaybackTime = now
        playWheelTick()
    }

    private func playWheelTick() {
        guard !wheelTickPlayers.isEmpty else { return }

        let player = wheelTickPlayers[wheelTickPlayerIndex]
        wheelTickPlayerIndex = (wheelTickPlayerIndex + 1) % wheelTickPlayers.count
        player.currentTime = 0
        player.play()
    }

    /// Icon selection animates the wheel, so supply tactile ticks for that movement.
    /// Drag-end alignment intentionally does not call this method.
    private func playWheelMotionTicks(for rotationDelta: Double) {
        wheelMotionTickTask?.cancel()
        guard isControlPanelOpen else { return }

        let tickCount = min(12, max(1, Int(abs(rotationDelta) / 12)))
        let interval = UInt64(30_000_000) // Match the short wheel spring without overloading audio playback.

        wheelMotionTickTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for tick in 0..<tickCount {
                guard !Task.isCancelled else { return }
                self.playWheelTick()

                guard tick < tickCount - 1 else { return }
                try? await Task.sleep(nanoseconds: interval)
            }
        }
    }

    func stop() {
        clearObservers()
        player.pause()
        player.replaceCurrentItem(with: nil)
        playbackState = .stopped

        if let activeStation {
            publishNowPlaying(for: activeStation, playbackRate: 0, playbackState: .paused)
        }
    }

    func shutdown() {
        stop()
        activeStation = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().playbackState = .stopped
        NSApplication.shared.terminate(nil)
    }

    func cycleSource(by offset: Int) {
        let sources = StationCatalog.allSources
        guard !sources.isEmpty else { return }

        let currentStation = activeStation ?? selectedMixtape
        let currentIndex = sources.firstIndex(where: { $0.id == currentStation.id }) ?? 0
        let targetIndex = ((currentIndex + offset) % sources.count + sources.count) % sources.count
        let target = sources[targetIndex]

        if isControlPanelOpen,
           !(currentStation.kind == .mixtape && target.kind == .mixtape) {
            playPressFeedback()
        }

        if target.kind == .mixtape {
            selectMixtape(target, rotatingWheel: true, startsPlayback: true)
        } else {
            play(target)
        }
    }

    private func play(_ station: Station) {
        clearObservers()
        player.pause()
        player.replaceCurrentItem(with: nil)
        activeStation = station
        loadingStartedAt = Date()
        playbackState = .loading
        publishNowPlaying(for: station, playbackRate: 0, playbackState: .paused)

        do {
            let streamURL = try PlaylistParser.streamURL(for: station)
            let item = AVPlayerItem(url: streamURL)
            observe(item)
            player.replaceCurrentItem(with: item)
            player.play()
            schedulePlaybackTimeout(for: item)
        } catch {
            playbackState = .failed(error.localizedDescription)
            publishNowPlaying(for: station, playbackRate: 0, playbackState: .stopped)
        }
    }

    private func observe(_ item: AVPlayerItem) {
        itemStatusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self, weak item] _, _ in
            guard let item else { return }
            Task { @MainActor [weak self] in
                self?.updateState(for: item)
            }
        }

        playerTimeControlObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self, weak item] _, _ in
            guard let item else { return }
            Task { @MainActor [weak self] in
                self?.updateTimeControlState(for: item)
            }
        }

        playbackFailureObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.failedToPlayToEndTimeNotification,
            object: item,
            queue: .main
        ) { [weak self, weak item] notification in
            guard let item else { return }
            let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
            Task { @MainActor [weak self] in
                self?.failPlayback(
                    for: item,
                    message: error?.localizedDescription ?? "Stream playback failed"
                )
            }
        }

        playbackStalledObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.playbackStalledNotification,
            object: item,
            queue: .main
        ) { [weak self, weak item] _ in
            guard let item else { return }
            Task { @MainActor [weak self] in
                self?.beginBuffering(for: item)
            }
        }
    }

    private func updateState(for item: AVPlayerItem) {
        guard activeStation != nil, player.currentItem === item else { return }

        switch item.status {
        case .unknown:
            playbackState = .loading
        case .readyToPlay:
            updateTimeControlState(for: item)
        case .failed:
            failPlayback(for: item, message: item.error?.localizedDescription ?? "Stream playback failed")
        @unknown default:
            failPlayback(for: item, message: "Unknown playback error")
        }
    }

    private func updateTimeControlState(for item: AVPlayerItem) {
        guard activeStation != nil, player.currentItem === item else { return }

        switch player.timeControlStatus {
        case .paused:
            if playbackState.isEngaged {
                beginBuffering(for: item)
            }
        case .waitingToPlayAtSpecifiedRate:
            beginBuffering(for: item)
        case .playing:
            playbackTimeoutTask?.cancel()
            playbackTimeoutTask = nil
            playbackState = .playing
            if let activeStation {
                publishNowPlaying(for: activeStation, playbackRate: 1, playbackState: .playing)
            }
        @unknown default:
            beginBuffering(for: item)
        }
    }

    private func beginBuffering(for item: AVPlayerItem) {
        guard player.currentItem === item, playbackState.errorMessage == nil else { return }

        if playbackState != .loading {
            loadingStartedAt = Date()
        }
        playbackState = .loading
        if let activeStation {
            publishNowPlaying(for: activeStation, playbackRate: 0, playbackState: .paused)
        }
        schedulePlaybackTimeout(for: item)
    }

    private func schedulePlaybackTimeout(for item: AVPlayerItem) {
        playbackTimeoutTask?.cancel()
        playbackTimeoutTask = Task { @MainActor [weak self, weak item] in
            try? await Task.sleep(nanoseconds: Self.playbackTimeoutNanoseconds)
            guard !Task.isCancelled,
                  let self,
                  let item,
                  self.player.currentItem === item,
                  self.playbackState == .loading else { return }

            self.failPlayback(for: item, message: self.playbackTimeoutMessage)
        }
    }

    private var playbackTimeoutMessage: String {
        if player.reasonForWaitingToPlay == .evaluatingBufferingRate {
            return "Stream timed out while evaluating the connection"
        }
        if player.reasonForWaitingToPlay == .toMinimizeStalls {
            return "Stream timed out while buffering"
        }
        if player.reasonForWaitingToPlay == .noItemToPlay {
            return "No stream available to play"
        }
        return "Stream playback timed out"
    }

    private func failPlayback(for item: AVPlayerItem, message: String) {
        guard player.currentItem === item else { return }

        playbackTimeoutTask?.cancel()
        playbackTimeoutTask = nil
        player.pause()
        playbackState = .failed(message)
        if let activeStation {
            publishNowPlaying(for: activeStation, playbackRate: 0, playbackState: .stopped)
        }
    }

    private func configureRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.stopCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.skipForwardCommand.isEnabled = false
        commandCenter.skipBackwardCommand.isEnabled = false
        commandCenter.changePlaybackPositionCommand.isEnabled = false

        addRemoteTarget(to: commandCenter.playCommand) { player in
            player.play(player.activeStation ?? player.selectedMixtape)
        }
        addRemoteTarget(to: commandCenter.pauseCommand) { player in
            player.stop()
        }
        addRemoteTarget(to: commandCenter.stopCommand) { player in
            player.stop()
        }
        addRemoteTarget(to: commandCenter.togglePlayPauseCommand) { player in
            if player.playbackState.isEngaged {
                player.stop()
            } else {
                player.play(player.activeStation ?? player.selectedMixtape)
            }
        }
        addRemoteTarget(to: commandCenter.nextTrackCommand) { player in
            player.cycleSource(by: 1)
        }
        addRemoteTarget(to: commandCenter.previousTrackCommand) { player in
            player.cycleSource(by: -1)
        }
    }

    private func addRemoteTarget(
        to command: MPRemoteCommand,
        action: @escaping @MainActor (RadioPlayer) -> Void
    ) {
        let target = command.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                action(self)
            }
            return .success
        }
        remoteCommandTargets.append((command, target))
    }

    private func publishNowPlaying(
        for station: Station,
        playbackRate: Float,
        playbackState: MPNowPlayingPlaybackState
    ) {
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: station.displayName,
            MPMediaItemPropertyArtist: "NTS Radio",
            MPMediaItemPropertyAlbumTitle: station.kind == .radio ? "Live Radio" : "Infinite Mixtapes",
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyPlaybackRate: playbackRate,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
        ]

        if let artwork = artwork(for: station) {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        MPNowPlayingInfoCenter.default().playbackState = playbackState
    }

    private func artwork(for station: Station) -> MPMediaItemArtwork? {
        if let cachedArtwork = artworkCache[station.id] {
            return cachedArtwork
        }

        guard let resource = Self.artworkResources[station.id],
              let artworkURL = Bundle.main.url(
                forResource: resource.name,
                withExtension: resource.extension
              ),
              let image = NSImage(contentsOf: artworkURL) else {
            return nil
        }

        let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        artworkCache[station.id] = artwork
        return artwork
    }

    private func clearObservers() {
        playbackTimeoutTask?.cancel()
        playbackTimeoutTask = nil

        itemStatusObservation?.invalidate()
        itemStatusObservation = nil

        playerTimeControlObservation?.invalidate()
        playerTimeControlObservation = nil

        if let playbackFailureObserver {
            NotificationCenter.default.removeObserver(playbackFailureObserver)
            self.playbackFailureObserver = nil
        }

        if let playbackStalledObserver {
            NotificationCenter.default.removeObserver(playbackStalledObserver)
            self.playbackStalledObserver = nil
        }
    }
}
