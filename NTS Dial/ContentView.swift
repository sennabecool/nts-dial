import AVKit
import SwiftUI

private enum BundledImageCache {
    static let radioOneIcon = load(named: "radio-1-icon")
    static let radioTwoIcon = load(named: "radio-2-icon")
    static let dialRim = load(named: "dial-rim")
    static let dialMarker = load(named: "dial-marker")
    static let mixtapesLogo = load(named: "mixtapes-logo")
    static let airPlayIcon = loadTemplate(named: "Airplay")
    static let airPlayOuter = loadTemplate(named: "AirplayOuter")
    static let airPlayMiddle = loadTemplate(named: "AirplayMiddle")
    static let airPlayInner = loadTemplate(named: "AirplayInner")
    static let airPlayArrow = loadTemplate(named: "AirplayArrow")
    static let mixtapeIcons: [String: NSImage] = Dictionary(
        uniqueKeysWithValues: [
            "slow-focus", "expansions", "low-key", "labyrinth", "memory-lane", "sweat",
            "4-to-the-floor", "otaku", "island-time", "the-pit", "the-tube", "rap-house",
            "sheet-music", "field-recordings", "feelings", "poolside",
        ].compactMap { id in
            load(named: "\(id)-icon").map { (id, $0) }
        }
    )

    private static func load(named name: String) -> NSImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "svg") else { return nil }
        return NSImage(contentsOf: url)
    }

    private static func loadTemplate(named name: String) -> NSImage? {
        let image = load(named: name)
        image?.isTemplate = true
        return image
    }
}

struct ContentView: View {
    @EnvironmentObject private var radioPlayer: RadioPlayer
    @EnvironmentObject private var appUpdater: AppUpdater

    private static let appVersion = Bundle.main.object(
        forInfoDictionaryKey: "CFBundleShortVersionString"
    ) as? String ?? "Unknown"

    var body: some View {
        HStack(spacing: 2) {
            VStack(spacing: 2) {
                RadioStationZone(station: StationCatalog.radioOne)
                    .frame(width: 178, height: 178)

                RadioStationZone(station: StationCatalog.radioTwo)
                    .frame(width: 178, height: 178)
            }

            MixtapeZone()
                .frame(width: 358, height: 358)
        }
        .frame(width: 540, height: 360)
        .padding(1)
        .frame(width: 542, height: 362)
        .background(Color(red: 0.11, green: 0.11, blue: 0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color(red: 0.11, green: 0.11, blue: 0.12), lineWidth: 2)
                .allowsHitTesting(false)
        }
        .contextMenu {
            Button("Version \(Self.appVersion)") {}
                .disabled(true)

            Button("Check for Updates…") {
                appUpdater.checkForUpdates()
            }
            .disabled(!appUpdater.canCheckForUpdates)

            Divider()

            Button("Quit NTS Dial", role: .destructive) {
                radioPlayer.shutdown()
            }
        }
    }
}

private struct TileInnerShadowLayer: View {
    let topLeadingRadius: CGFloat
    let bottomLeadingRadius: CGFloat
    let bottomTrailingRadius: CGFloat
    let topTrailingRadius: CGFloat

    var body: some View {
        let tileShape = UnevenRoundedRectangle(
            topLeadingRadius: topLeadingRadius,
            bottomLeadingRadius: bottomLeadingRadius,
            bottomTrailingRadius: bottomTrailingRadius,
            topTrailingRadius: topTrailingRadius
        )

        GeometryReader { proxy in
            ZStack {
                invertedShapeShadow(
                    color: .white.opacity(0.32),
                    offset: CGSize(width: 1, height: 1),
                    size: proxy.size,
                    tileShape: tileShape
                )

                invertedShapeShadow(
                    color: .black.opacity(0.32),
                    offset: CGSize(width: -1, height: -1),
                    size: proxy.size,
                    tileShape: tileShape
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func invertedShapeShadow(
        color: Color,
        offset: CGSize,
        size: CGSize,
        tileShape: UnevenRoundedRectangle
    ) -> some View {
        let overscan: CGFloat = 6

        return ZStack {
            Canvas { context, canvasSize in
                context.fill(
                    Path(CGRect(origin: .zero, size: canvasSize)),
                    with: .color(color)
                )
                context.blendMode = .destinationOut
                context.fill(
                    tileShape.path(
                        in: CGRect(
                            x: overscan,
                            y: overscan,
                            width: size.width,
                            height: size.height
                        )
                    ),
                    with: .color(.black)
                )
            }
            .frame(width: size.width + (overscan * 2), height: size.height + (overscan * 2))
            .position(x: size.width / 2, y: size.height / 2)
            .blur(radius: 1)
            .offset(offset)
        }
        .frame(width: size.width, height: size.height)
        .mask(tileShape.fill(.white))
        .compositingGroup()
    }
}

private struct RadioStationZone: View {
    @EnvironmentObject private var radioPlayer: RadioPlayer
    let station: Station

    private var isEngaged: Bool {
        radioPlayer.activeStation?.id == station.id && radioPlayer.playbackState.isEngaged
    }

    private var isRadioOne: Bool {
        station.id == "radio-1"
    }

    private var ledState: LEDState {
        guard radioPlayer.activeStation?.id == station.id else { return .idle }
        return LEDState(playbackState: radioPlayer.playbackState)
    }

    private var errorMessage: String? {
        guard radioPlayer.activeStation?.id == station.id else { return nil }
        return radioPlayer.playbackState.errorMessage
    }

    var body: some View {
        ZStack {
            if isRadioOne {
                HStack(alignment: .top, spacing: 102) {
                    if let icon = BundledImageCache.radioOneIcon {
                        Image(nsImage: icon)
                            .frame(width: 26, height: 26)
                    } else {
                        Text("1")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(red: 0.33, green: 0.35, blue: 0.36))
                            .frame(width: 26, height: 26)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 1))
                    }

                    StatusLED(state: ledState, loadingStartedAt: radioPlayer.loadingStartedAt)
                        .frame(width: 26, height: 26)
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 140)
                .frame(height: 178, alignment: .top)
                .background(
                    LinearGradient(
                        stops: [
                            .init(color: Color(red: 0.32, green: 0.33, blue: 0.35), location: 0),
                            .init(color: Color(red: 0.2, green: 0.22, blue: 0.22), location: 1)
                        ],
                        startPoint: UnitPoint(x: 0.5, y: 0),
                        endPoint: UnitPoint(x: 0.5, y: 1)
                    )
                )
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 14,
                        bottomLeadingRadius: 3,
                        bottomTrailingRadius: 3,
                        topTrailingRadius: 3
                    )
                )
            } else {
                HStack(alignment: .top, spacing: 102) {
                    if let icon = BundledImageCache.radioTwoIcon {
                        Image(nsImage: icon)
                            .frame(width: 26, height: 26)
                    } else {
                        Text("2")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(red: 0.33, green: 0.35, blue: 0.36))
                            .frame(width: 26, height: 26)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 1))
                    }

                    StatusLED(state: ledState, loadingStartedAt: radioPlayer.loadingStartedAt)
                        .frame(width: 26, height: 26)
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 140)
                .frame(height: 178, alignment: .top)
                .background(
                    LinearGradient(
                        stops: [
                            .init(color: Color(red: 0.2, green: 0.22, blue: 0.22), location: 0),
                            .init(color: Color(red: 0.08, green: 0.1, blue: 0.1), location: 1)
                        ],
                        startPoint: UnitPoint(x: 0.5, y: 0),
                        endPoint: UnitPoint(x: 0.5, y: 1)
                    )
                )
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 3,
                        bottomLeadingRadius: 14,
                        bottomTrailingRadius: 3,
                        topTrailingRadius: 3
                    )
                )
            }

            TileInnerShadowLayer(
                topLeadingRadius: isRadioOne ? 14 : 3,
                bottomLeadingRadius: isRadioOne ? 3 : 14,
                bottomTrailingRadius: 3,
                topTrailingRadius: 3
            )
            .frame(width: 178, height: 178)

            ZStack {
                Circle()
                    .fill(Color(red: 28.0 / 255, green: 29.0 / 255, blue: 31.0 / 255))
                    .frame(width: 96, height: 96)

                Button {
                    radioPlayer.completeStationButtonPress(station)
                } label: {
                    ZStack {
                        if isRadioOne {
                        Circle()
                            .fill(
                                LinearGradient(
                                    stops: [
                                        .init(color: Color(red: 204.0 / 255, green: 43.0 / 255, blue: 50.0 / 255), location: 0),
                                        .init(color: Color(red: 75.0 / 255, green: 20.0 / 255, blue: 18.0 / 255), location: 1)
                                    ],
                                    startPoint: UnitPoint(x: 0.5, y: 0),
                                    endPoint: UnitPoint(x: 0.5, y: 1)
                                )
                                .shadow(.inner(color: .white.opacity(0.56), radius: 3, x: 0, y: 3))
                            )
                            .frame(width: 92, height: 92)
                            .modifier(RadioDialOuterShadow())
                            .overlay(
                                Circle()
                                    .inset(by: 0.5)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 105.0 / 255, green: 16.0 / 255, blue: 23.0 / 255),
                                                Color(red: 49.0 / 255, green: 7.0 / 255, blue: 10.0 / 255)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ),
                                        lineWidth: 1
                                    )
                            )

                        Circle()
                            .fill(
                                LinearGradient(
                                    stops: [
                                        .init(color: Color(red: 129.0 / 255, green: 24.0 / 255, blue: 26.0 / 255), location: 0),
                                        .init(color: Color(red: 147.0 / 255, green: 32.0 / 255, blue: 40.0 / 255), location: 0.35),
                                        .init(color: Color(red: 219.0 / 255, green: 26.0 / 255, blue: 34.0 / 255), location: 0.75),
                                        .init(color: Color(red: 0.91, green: 0.32, blue: 0.35), location: 1)
                                    ],
                                    startPoint: UnitPoint(x: 0.5, y: 0),
                                    endPoint: UnitPoint(x: 0.5, y: 1)
                                )
                                .shadow(.inner(color: .white.opacity(0.56), radius: 9, x: 0, y: -4))
                                .shadow(
                                    .inner(
                                        color: Color(red: 0.321569, green: 0.019608, blue: 0.050980).opacity(0.72),
                                        radius: 18,
                                        x: 0,
                                        y: 12
                                    )
                                )
                            )
                            .frame(width: 84, height: 84)

                        Rectangle()
                            .foregroundColor(.clear)
                            .frame(width: 52, height: 52)
                            .background(Color(red: 0.71, green: 0.16, blue: 0.18))
                            .cornerRadius(52)
                            .blur(radius: 4)
                        } else {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        stops: [
                                            .init(color: .white, location: 0),
                                            .init(color: Color(red: 122.0 / 255, green: 126.0 / 255, blue: 122.0 / 255), location: 1)
                                        ],
                                        startPoint: UnitPoint(x: 0.5, y: 0),
                                        endPoint: UnitPoint(x: 0.5, y: 1)
                                    )
                                    .shadow(.inner(color: .white.opacity(0.48), radius: 3, x: 0, y: 3))
                                )
                                .frame(width: 92, height: 92)
                                .modifier(RadioDialOuterShadow())
                                .overlay(
                                    Circle()
                                        .inset(by: 0.5)
                                        .stroke(
                                            LinearGradient(
                                                colors: [
                                                    Color(red: 143.0 / 255, green: 148.0 / 255, blue: 144.0 / 255),
                                                    .black
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            ),
                                            lineWidth: 1
                                        )
                                )

                            Circle()
                                .fill(
                                    LinearGradient(
                                        stops: [
                                            .init(color: Color(red: 128.0 / 255, green: 130.0 / 255, blue: 127.0 / 255), location: 0),
                                            .init(color: Color(red: 173.0 / 255, green: 174.0 / 255, blue: 169.0 / 255), location: 0.35),
                                            .init(color: Color(red: 253.0 / 255, green: 253.0 / 255, blue: 249.0 / 255), location: 0.75),
                                            .init(color: .white, location: 1)
                                        ],
                                        startPoint: UnitPoint(x: 0.5, y: 0),
                                        endPoint: UnitPoint(x: 0.5, y: 1)
                                    )
                                    .shadow(.inner(color: .white, radius: 18, x: 0, y: -12))
                                    .shadow(
                                        .inner(
                                            color: Color(red: 119.0 / 255, green: 123.0 / 255, blue: 119.0 / 255).opacity(0.72),
                                            radius: 18,
                                            x: 0,
                                            y: 12
                                        )
                                    )
                                )
                                .frame(width: 84, height: 84)

                            Rectangle()
                                .foregroundColor(.clear)
                                .frame(width: 52, height: 52)
                                .background(Color(red: 217.0 / 255, green: 217.0 / 255, blue: 213.0 / 255))
                                .cornerRadius(52)
                                .blur(radius: 4)
                        }
                    }
                    .frame(width: 92, height: 92)
                    .contentShape(Circle())
                }
                .buttonStyle(
                    RadioDialPressStyle(
                        isActive: isEngaged,
                        isPressingActive: radioPlayer.stationPressedWhileActiveID == station.id,
                        isHovering: radioPlayer.hoveredButtonID == station.id,
                        onPressBegan: { radioPlayer.beginStationButtonPress(station) },
                        onPressEnded: { radioPlayer.endStationButtonPress(station) }
                    )
                )
                .onHover { hovering in
                    radioPlayer.setButtonHovering(station.id, hovering: hovering)
                    if hovering { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
                }
                .help(isEngaged ? "Stop \(station.displayName)" : "Play \(station.displayName)")
                .accessibilityLabel(isEngaged ? "Stop \(station.displayName)" : "Play \(station.displayName)")
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 160, height: 24)
                    .position(x: 89, y: 153)
            }
        }
    }
}

private struct MixtapeZone: View {
    @EnvironmentObject private var radioPlayer: RadioPlayer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let center = CGPoint(x: 179, y: 179)
    // 128 pt wheel radius + 8 pt gap + 13 pt icon radius.
    private let iconRadius: CGFloat = 149

    private var isEngaged: Bool {
        radioPlayer.activeStation?.kind == .mixtape && radioPlayer.playbackState.isEngaged
    }

    private var ledState: LEDState {
        guard radioPlayer.activeStation?.kind == .mixtape else { return .idle }
        return LEDState(playbackState: radioPlayer.playbackState)
    }

    private var errorMessage: String? {
        guard radioPlayer.activeStation?.kind == .mixtape else { return nil }
        return radioPlayer.playbackState.errorMessage
    }

    private var ledAccessibilityValue: String {
        guard ledState == .failed else { return ledState.accessibilityValue }
        return "Failed: \(errorMessage ?? "Playback failed")"
    }

    private func isInsideWheel(_ location: CGPoint) -> Bool {
        let radius: CGFloat = 124
        let deltaX = location.x - radius
        let deltaY = location.y - radius
        return (deltaX * deltaX) + (deltaY * deltaY) <= (radius * radius)
    }

    var body: some View {
        ZStack {
            TileInnerShadowLayer(
                topLeadingRadius: 3,
                bottomLeadingRadius: 3,
                bottomTrailingRadius: 14,
                topTrailingRadius: 14
            )
            .frame(width: 358, height: 358)

            ForEach(Array(StationCatalog.mixtapes.enumerated()), id: \.element.id) { index, station in
                mixtapeButton(for: station, index: index)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }

            Circle()
                .fill(Color(red: 16.0 / 255, green: 16.0 / 255, blue: 16.0 / 255))
                .overlay {
                    Circle()
                        .stroke(Color(red: 15.0 / 255, green: 15.0 / 255, blue: 15.0 / 255), lineWidth: 2)
                }
                .frame(width: 256, height: 256)
                .allowsHitTesting(false)

            ZStack {
                if let rim = BundledImageCache.dialRim {
                    Image(nsImage: rim)
                        .renderingMode(.template)
                        .foregroundStyle(Color(red: 40.0 / 255, green: 44.0 / 255, blue: 45.0 / 255))
                        .frame(width: 252, height: 252)
                        .overlay {
                            Image(nsImage: rim)
                                .renderingMode(.template)
                                .foregroundStyle(.white.opacity(0.32))
                                .blur(radius: 2)
                                .mask {
                                    Image(nsImage: rim)
                                        .renderingMode(.template)
                                }
                        }
                }

            }
            .frame(width: 256, height: 256)
            .rotationEffect(.degrees(radioPlayer.mixtapeWheelRotation))
            .animation(
                radioPlayer.isDraggingMixtapeWheel || reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.72),
                value: radioPlayer.mixtapeWheelRotation
            )
            .allowsHitTesting(false)

            RoundedRectangle(cornerRadius: 248)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color(red: 0.23, green: 0.28, blue: 0.29), location: 0),
                            .init(color: Color(red: 0.12, green: 0.13, blue: 0.14), location: 1)
                        ],
                        startPoint: UnitPoint(x: 0.5, y: 0),
                        endPoint: UnitPoint(x: 0.5, y: 1)
                    )
                    .shadow(.inner(color: .white.opacity(0.48), radius: 3, x: 0, y: 3))
                )
                .frame(width: 248, height: 248)
                .shadow(color: .black.opacity(0.9), radius: 32.18921, x: 0, y: 28.16556)
                .shadow(color: .black.opacity(0.25), radius: 1.96195, x: 0, y: 3.92389)
                .overlay(
                    RoundedRectangle(cornerRadius: 248)
                        .inset(by: 0.5)
                        .stroke(Color(red: 0.17, green: 0.18, blue: 0.18), lineWidth: 1)
                )
                .allowsHitTesting(false)

            RoundedRectangle(cornerRadius: 238)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color(red: 0.08, green: 0.1, blue: 0.1), location: 0),
                            .init(color: Color(red: 0.13, green: 0.15, blue: 0.15), location: 0.35),
                            .init(color: Color(red: 0.16, green: 0.18, blue: 0.18), location: 0.75),
                            .init(color: Color(red: 0.22, green: 0.24, blue: 0.24), location: 1)
                        ],
                        startPoint: UnitPoint(x: 0, y: 0),
                        endPoint: UnitPoint(x: 1, y: 1)
                    )
                    .shadow(
                        .inner(
                            color: Color(red: 0.1, green: 0.1, blue: 0.1),
                            radius: 48,
                            x: 0,
                            y: 32
                        )
                    )
                    .shadow(.inner(color: .white.opacity(0.12), radius: 48, x: 0, y: -32))
                )
                .frame(width: 238, height: 238)
                .shadow(color: Color(red: 0.13, green: 0.13, blue: 0.13).opacity(0.64), radius: 2, x: 0, y: 0)
                .allowsHitTesting(false)

            Rectangle()
                .foregroundStyle(.clear)
                .frame(width: 200, height: 200)
                .background(Color(red: 0.16, green: 0.18, blue: 0.18))
                .cornerRadius(200)
                .blur(radius: 12)
                .allowsHitTesting(false)

            Circle()
                .fill(.clear)
                .frame(width: 248, height: 248)
                .contentShape(Circle())
                .onContinuousHover { phase in
                    guard !radioPlayer.isDraggingMixtapeWheel else { return }

                    switch phase {
                    case .active(let location):
                        (isInsideWheel(location) ? NSCursor.openHand : .arrow).set()
                    case .ended:
                        NSCursor.arrow.set()
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { value in
                            guard radioPlayer.isDraggingMixtapeWheel || isInsideWheel(value.location) else { return }
                            if !radioPlayer.isDraggingMixtapeWheel {
                                NSCursor.closedHand.set()
                            }
                            radioPlayer.updateMixtapeWheelDrag(at: value.location, in: CGSize(width: 248, height: 248))
                        }
                        .onEnded { value in
                            guard radioPlayer.isDraggingMixtapeWheel else { return }
                            radioPlayer.endMixtapeWheelDrag()
                            (isInsideWheel(value.location) ? NSCursor.openHand : .arrow).set()
                        }
                )

            if let marker = BundledImageCache.dialMarker {
                ZStack {
                    Image(nsImage: marker)
                        .renderingMode(.template)
                        .foregroundStyle(Color(red: 208.0 / 255, green: 208.0 / 255, blue: 208.0 / 255))
                        .frame(width: 17, height: 15)
                        // 18 pt inset from the wheel edge + 7.5 pt marker half-height.
                        .position(x: 128, y: 25.5)
                }
                    .frame(width: 256, height: 256)
                    .rotationEffect(.degrees(radioPlayer.mixtapeWheelRotation))
                    .animation(
                        radioPlayer.isDraggingMixtapeWheel || reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.72),
                        value: radioPlayer.mixtapeWheelRotation
                    )
                    .allowsHitTesting(false)
            }

            ForEach(Array(StationCatalog.mixtapes.enumerated()), id: \.element.id) { index, station in
                mixtapeHitTarget(for: station, index: index)
            }

            if let logo = BundledImageCache.mixtapesLogo {
                Image(nsImage: logo)
                    .frame(width: 81, height: 26)
                    .position(x: 52.5, y: 25)
            }

            StatusLED(state: ledState, loadingStartedAt: radioPlayer.loadingStartedAt)
                .frame(width: 26, height: 26)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Mixtape playback status")
                .accessibilityValue(Text(ledAccessibilityValue))
                .modifier(ErrorTooltip(message: ledState == .failed ? errorMessage ?? "Playback failed" : nil))
                .onChange(of: ledState) { _, state in
                    guard state == .failed else { return }
                    NSAccessibility.post(
                        element: NSApplication.shared,
                        notification: .announcementRequested,
                        userInfo: [
                            .announcement: "Mixtape playback failed. \(errorMessage ?? "Playback failed")",
                            .priority: NSAccessibilityPriorityLevel.high.rawValue
                        ]
                    )
                }
                .position(x: 333, y: 25)

            Button {
                radioPlayer.completeSelectedMixtapeButtonPress()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color(red: 28.0 / 255, green: 29.0 / 255, blue: 31.0 / 255))
                        .frame(width: 60, height: 60)

                    RoundedRectangle(cornerRadius: 56)
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: Color(red: 0.97, green: 0.97, blue: 0.95), location: 0),
                                    .init(color: Color(red: 0.87, green: 0.87, blue: 0.85), location: 0.35),
                                    .init(color: Color(red: 0.77, green: 0.78, blue: 0.75), location: 0.72),
                                    .init(color: Color(red: 0.65, green: 0.67, blue: 0.65), location: 1)
                                ],
                                startPoint: UnitPoint(x: 1.01, y: 1.03),
                                endPoint: UnitPoint(x: 0.04, y: 0.06)
                            )
                            .shadow(.inner(color: .black.opacity(0.48), radius: 3, x: -2, y: -2))
                            .shadow(.inner(color: .white, radius: 3, x: 2, y: 2))
                        )
                        .frame(width: 56, height: 56)
                        .overlay(
                            RoundedRectangle(cornerRadius: 56)
                                .inset(by: 0.5)
                                .stroke(Color(red: 0.54, green: 0.54, blue: 0.54), lineWidth: 1)
                        )
                        .modifier(MixtapePlayButtonShadow())
                }
            }
            .buttonStyle(
                MixtapeButtonPressStyle(
                    isActive: isEngaged,
                    isPressingActive: radioPlayer.selectedMixtapePressedWhileActive,
                    isHovering: radioPlayer.isMixtapeButtonHovering,
                    onPressBegan: { radioPlayer.beginSelectedMixtapeButtonPress() },
                    onPressEnded: { radioPlayer.endSelectedMixtapeButtonPress() }
                )
            )
            .onHover { hovering in
                radioPlayer.setMixtapeButtonHovering(hovering)
                if hovering { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
            }
            .help(isEngaged ? "Stop \(radioPlayer.selectedMixtape.displayName)" : "Play \(radioPlayer.selectedMixtape.displayName)")
            .accessibilityLabel(isEngaged ? "Stop \(radioPlayer.selectedMixtape.displayName)" : "Play \(radioPlayer.selectedMixtape.displayName)")

            AirPlayRoutePicker(player: radioPlayer.routingPlayer)
                .frame(width: 30, height: 30)
                .position(x: 331, y: 331)
        }
        .frame(width: 358, height: 358)
        .background(
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.32, green: 0.33, blue: 0.35), location: 0),
                    .init(color: Color(red: 0.08, green: 0.1, blue: 0.1), location: 1)
                ],
                startPoint: UnitPoint(x: 0.5, y: 0),
                endPoint: UnitPoint(x: 0.5, y: 1)
            )
        )
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 3,
                bottomLeadingRadius: 3,
                bottomTrailingRadius: 14,
                topTrailingRadius: 14
            )
        )
    }

    @ViewBuilder
    private func mixtapeButton(for station: Station, index: Int) -> some View {
        let angle = Angle.degrees(-90 + (Double(index) * (360 / Double(StationCatalog.mixtapes.count))))
        let x = center.x + iconRadius * cos(CGFloat(angle.radians))
        let y = center.y + iconRadius * sin(CGFloat(angle.radians))
        let isSelected = radioPlayer.selectedMixtape.id == station.id

        Button {
            radioPlayer.selectMixtape(station)
        } label: {
            if let icon = BundledImageCache.mixtapeIcons[station.id] {
                Image(nsImage: icon)
                    .renderingMode(.template)
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
            } else {
                Image(systemName: "\(index + 1).circle\(isSelected ? ".fill" : "")")
                    .foregroundStyle(.white)
                    .font(.system(size: 24, weight: isSelected ? .bold : .regular))
                    .frame(width: 26, height: 26)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
        }
        .help(station.displayName)
        .accessibilityLabel("Select \(station.displayName)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .position(x: x, y: y)
    }

    private func mixtapeHitTarget(for station: Station, index: Int) -> some View {
        let angle = Angle.degrees(-90 + (Double(index) * (360 / Double(StationCatalog.mixtapes.count))))
        let x = center.x + iconRadius * cos(CGFloat(angle.radians))
        let y = center.y + iconRadius * sin(CGFloat(angle.radians))
        let isSelected = radioPlayer.selectedMixtape.id == station.id

        return Button {
            radioPlayer.selectMixtape(station)
        } label: {
            Circle()
                .fill(.clear)
                .frame(width: 26, height: 26)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
        }
        .help(station.displayName)
        .accessibilityLabel("Select \(station.displayName)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .position(x: x, y: y)
    }
}

private enum LEDState: Equatable {
    case idle
    case loading
    case playing
    case failed

    init(playbackState: PlaybackState) {
        switch playbackState {
        case .stopped:
            self = .idle
        case .loading:
            self = .loading
        case .playing:
            self = .playing
        case .failed:
            self = .failed
        }
    }

    var accessibilityValue: String {
        switch self {
        case .idle:
            "Idle"
        case .loading:
            "Loading"
        case .playing:
            "Playing"
        case .failed:
            "Failed"
        }
    }
}

private struct StatusLED: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let state: LEDState
    let loadingStartedAt: Date

    private var color: Color {
        switch state {
        case .idle:
            Color(red: 15 / 255, green: 15 / 255, blue: 15 / 255)
        case .loading, .playing:
            .white
        case .failed:
            Color(red: 0.9, green: 0.12, blue: 0.14)
        }
    }

    private var glowColor: Color {
        switch state {
        case .idle:
            .clear
        case .loading, .playing:
            .white
        case .failed:
            Color(red: 0.9, green: 0.12, blue: 0.14)
        }
    }

    var body: some View {
        if state == .loading && !reduceMotion {
            TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                let elapsed = context.date.timeIntervalSince(loadingStartedAt)
                let brightness = (1 - cos((elapsed / 0.75) * 2 * .pi)) / 2
                led(fillColor: Color(white: brightness), shadowColor: Color.white.opacity(brightness))
            }
        } else {
            led(fillColor: color, shadowColor: glowColor)
        }
    }

    private func led(fillColor: Color, shadowColor: Color) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color(red: 0.12, green: 0.15, blue: 0.15), location: 0),
                            .init(color: Color(red: 0.35, green: 0.36, blue: 0.37), location: 1)
                        ],
                        startPoint: UnitPoint(x: 0.5, y: 0),
                        endPoint: UnitPoint(x: 0.5, y: 1)
                    )
                )
                .frame(width: 12, height: 12)

            if state == .idle {
                Circle()
                    .fill(fillColor)
                    .frame(width: 10, height: 10)
            } else {
                Circle()
                    .fill(shadowColor)
                    .frame(width: 10, height: 10)
                    .shadow(color: shadowColor, radius: 2)
                    .shadow(color: shadowColor.opacity(0.85), radius: 3.5)

                Circle()
                    .fill(fillColor)
                    .frame(width: 10, height: 10)
            }
        }
    }
}

private struct ErrorTooltip: ViewModifier {
    let message: String?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let message {
            content.help(message)
        } else {
            content
        }
    }
}

private struct RadioDialIsPressedKey: EnvironmentKey {
    static let defaultValue = false
}

private extension EnvironmentValues {
    var radioDialIsPressed: Bool {
        get { self[RadioDialIsPressedKey.self] }
        set { self[RadioDialIsPressedKey.self] = newValue }
    }
}

private struct RadioDialOuterShadow: ViewModifier {
    @Environment(\.radioDialIsPressed) private var isPressed

    func body(content: Content) -> some View {
        content
            .shadow(
                color: .black.opacity(isPressed ? 0.72 : 0.76),
                radius: isPressed ? 4 : 16,
                x: isPressed ? 1 : 4,
                y: isPressed ? 4 : 16
            )
            .shadow(
                color: .black.opacity(isPressed ? 0.48 : 0.42),
                radius: isPressed ? 1.5 : 3,
                x: isPressed ? 0 : 2,
                y: isPressed ? 2 : 7
            )
    }
}

private struct MixtapePlayButtonShadow: ViewModifier {
    @Environment(\.radioDialIsPressed) private var isPressed

    func body(content: Content) -> some View {
        content
            .shadow(
                color: .black.opacity(isPressed ? 0.72 : 0.9),
                radius: isPressed ? 4 : 12,
                x: isPressed ? 1 : 2,
                y: 4
            )
            .shadow(
                color: .black.opacity(isPressed ? 0.48 : 0),
                radius: 1.5,
                x: 0,
                y: 2
            )
    }
}

private struct RadioDialPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isActive: Bool
    let isPressingActive: Bool
    let isHovering: Bool
    let onPressBegan: () -> Void
    let onPressEnded: () -> Void

    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed
        let interaction: RadioDialInteraction = isPressed
            ? (isPressingActive ? .pressingActive : .pressingIdle)
            : (isActive ? .active : .idle)

        configuration.label
            .environment(\.radioDialIsPressed, interaction != .idle)
            .scaleEffect(interaction.scale * (isHovering && interaction != .pressingIdle && interaction != .pressingActive ? 1.01 : 1))
            .animation(reduceMotion ? nil : .interactiveSpring(response: 0.08, dampingFraction: 0.85, blendDuration: 0), value: interaction)
            .animation(reduceMotion ? nil : .interactiveSpring(response: 0.16, dampingFraction: 0.82, blendDuration: 0), value: isHovering)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    onPressBegan()
                } else {
                    onPressEnded()
                }
            }
    }
}

private struct MixtapeButtonPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isActive: Bool
    let isPressingActive: Bool
    let isHovering: Bool
    let onPressBegan: () -> Void
    let onPressEnded: () -> Void

    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed
        let interaction: RadioDialInteraction = isPressed
            ? (isPressingActive ? .pressingActive : .pressingIdle)
            : (isActive ? .active : .idle)

        return configuration.label
            .environment(\.radioDialIsPressed, interaction != .idle)
            .scaleEffect(interaction.scale * (isHovering && interaction != .pressingIdle && interaction != .pressingActive ? 1.01 : 1))
            .animation(reduceMotion ? nil : .interactiveSpring(response: 0.08, dampingFraction: 0.85, blendDuration: 0), value: interaction)
            .animation(reduceMotion ? nil : .interactiveSpring(response: 0.16, dampingFraction: 0.82, blendDuration: 0), value: isHovering)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    onPressBegan()
                } else {
                    onPressEnded()
                }
            }
    }
}

private enum RadioDialInteraction: Equatable {
    case idle
    case active
    case pressingIdle
    case pressingActive

    var scale: CGFloat {
        switch self {
        case .idle:
            1
        case .active, .pressingIdle:
            0.98
        case .pressingActive:
            0.96
        }
    }
}

private struct AirPlayRoutePicker: View {
    let player: AVPlayer
    @State private var isHovering = false
    @State private var isConnected = false
    @State private var isConnecting = false
    @State private var isPickerPresented = false
    @State private var connectionAnimationTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            NativeAirPlayRoutePicker(
                player: player,
                onConnectionChanged: handleConnectionChanged,
                onAudioRouteChanged: handleAudioRouteChanged,
                onPresentationChanged: handlePresentationChanged
            )

            AirPlayStatusIcon(
                isConnected: isConnected,
                isConnecting: isConnecting,
                isPickerPresented: isPickerPresented,
                isHovering: isHovering
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
            if hovering { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
        }
        .onDisappear {
            connectionAnimationTask?.cancel()
        }
    }

    private func handleConnectionChanged(_ connected: Bool, confirmed _: Bool) {
        if connected {
            connectionAnimationTask?.cancel()
            connectionAnimationTask = nil
            isConnected = true
            isConnecting = false
        } else if !isConnecting {
            isConnected = false
        }
    }

    private func handleAudioRouteChanged(_ hasExternalOutput: Bool) {
        connectionAnimationTask?.cancel()
        connectionAnimationTask = nil

        guard hasExternalOutput else {
            isConnected = false
            isConnecting = false
            return
        }

        finishConnectionAnimationAfterDelay()
    }

    private func handlePresentationChanged(_ isPresented: Bool) {
        isPickerPresented = isPresented

        if isPresented {
            connectionAnimationTask?.cancel()
            connectionAnimationTask = nil
            isConnected = false
            isConnecting = true
        } else if isConnecting {
            finishConnectionAnimationAfterDelay()
        }
    }

    private func finishConnectionAnimationAfterDelay() {
        connectionAnimationTask?.cancel()
        isConnected = false
        isConnecting = true

        connectionAnimationTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            isConnected = true
            isConnecting = false
            connectionAnimationTask = nil
        }
    }
}

private struct AirPlayStatusIcon: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isConnected: Bool
    let isConnecting: Bool
    let isPickerPresented: Bool
    let isHovering: Bool

    var body: some View {
        Group {
            if isConnecting && !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate

                    ZStack {
                        iconLayer(BundledImageCache.airPlayArrow, opacity: isHovering ? 1 : 0.65)
                        waveLayer(BundledImageCache.airPlayInner, time: time, index: 0)
                        waveLayer(BundledImageCache.airPlayMiddle, time: time, index: 1)
                        waveLayer(BundledImageCache.airPlayOuter, time: time, index: 2)
                    }
                }
            } else {
                iconLayer(
                    BundledImageCache.airPlayIcon,
                    opacity: isConnected || isPickerPresented || isHovering ? 1 : (isConnecting ? 0.7 : 0.4)
                )
            }
        }
        .frame(width: 17, height: 16)
    }

    private func waveLayer(_ image: NSImage?, time: TimeInterval, index: Int) -> some View {
        let pulse = (sin((time * 2 * .pi / 1.2) - (Double(index) * 0.9)) + 1) / 2

        return iconLayer(image, opacity: 0.2 + (pulse * 0.8))
            .scaleEffect(0.96 + (pulse * 0.04))
    }

    @ViewBuilder
    private func iconLayer(_ image: NSImage?, opacity: Double) -> some View {
        if let image {
            Image(nsImage: image)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white)
                .opacity(opacity)
                .frame(width: 17, height: 16)
        }
    }
}

private struct NativeAirPlayRoutePicker: NSViewRepresentable {
    let player: AVPlayer
    let onConnectionChanged: (Bool, Bool) -> Void
    let onAudioRouteChanged: (Bool) -> Void
    let onPresentationChanged: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> AirPlayRoutePickerView {
        let routePicker = AirPlayRoutePickerView()
        routePicker.player = player
        routePicker.delegate = context.coordinator
        context.coordinator.observe(player)
        return routePicker
    }

    func updateNSView(_ nsView: AirPlayRoutePickerView, context: Context) {
        context.coordinator.parent = self

        if nsView.player !== player {
            nsView.player = player
            context.coordinator.observe(player)
        }
    }

    static func dismantleNSView(_ nsView: AirPlayRoutePickerView, coordinator: Coordinator) {
        nsView.delegate = nil
        coordinator.stopObserving()
    }

    @MainActor
    final class Coordinator: NSObject, AVRoutePickerViewDelegate {
        var parent: NativeAirPlayRoutePicker
        private weak var observedPlayer: AVPlayer?
        private var externalPlaybackObservation: NSKeyValueObservation?
        private var audioOutputDeviceObservation: NSKeyValueObservation?
        private var isExternalPlaybackActive = false
        private var audioOutputDeviceUniqueID: String?
        private var hasReceivedInitialAudioOutput = false
        private var lastReportedConnectionState: (connected: Bool, confirmed: Bool)?

        init(parent: NativeAirPlayRoutePicker) {
            self.parent = parent
        }

        func observe(_ player: AVPlayer) {
            guard observedPlayer !== player else { return }
            stopObserving()
            observedPlayer = player

            externalPlaybackObservation = player.observe(
                \.isExternalPlaybackActive,
                options: [.initial, .new]
            ) { [weak self] _, change in
                let isActive = change.newValue ?? false
                Task { @MainActor [weak self] in
                    self?.isExternalPlaybackActive = isActive
                    self?.reportConnectionState()
                }
            }

            audioOutputDeviceObservation = player.observe(
                \.audioOutputDeviceUniqueID,
                options: [.initial, .new]
            ) { [weak self] player, _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let previousDeviceID = self.audioOutputDeviceUniqueID
                    let newDeviceID = player.audioOutputDeviceUniqueID
                    self.audioOutputDeviceUniqueID = newDeviceID

                    if self.hasReceivedInitialAudioOutput, previousDeviceID != newDeviceID {
                        self.parent.onAudioRouteChanged(newDeviceID != nil)
                    }

                    self.hasReceivedInitialAudioOutput = true
                    self.reportConnectionState()
                }
            }
        }

        func stopObserving() {
            externalPlaybackObservation?.invalidate()
            externalPlaybackObservation = nil
            audioOutputDeviceObservation?.invalidate()
            audioOutputDeviceObservation = nil
            observedPlayer = nil
            hasReceivedInitialAudioOutput = false
        }

        func routePickerViewWillBeginPresentingRoutes(_ routePickerView: AVRoutePickerView) {
            parent.onPresentationChanged(true)
        }

        func routePickerViewDidEndPresentingRoutes(_ routePickerView: AVRoutePickerView) {
            parent.onPresentationChanged(false)
        }

        private func reportConnectionState() {
            let state = (
                connected: isExternalPlaybackActive || audioOutputDeviceUniqueID != nil,
                confirmed: isExternalPlaybackActive
            )
            guard lastReportedConnectionState?.connected != state.connected ||
                    lastReportedConnectionState?.confirmed != state.confirmed else { return }
            lastReportedConnectionState = state
            parent.onConnectionChanged(state.connected, state.confirmed)
        }
    }
}

private final class AirPlayRoutePickerView: AVRoutePickerView {
    init() {
        super.init(frame: .zero)
        isRoutePickerButtonBordered = false
        toolTip = "Choose AirPlay device"
        setAccessibilityLabel("Choose AirPlay device")
        hideSystemIcon()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        hideSystemIcon()
    }

    private func hideSystemIcon() {
        setRoutePickerButtonColor(.clear, for: .normal)
        setRoutePickerButtonColor(.clear, for: .normalHighlighted)
        setRoutePickerButtonColor(.clear, for: .active)
        setRoutePickerButtonColor(.clear, for: .activeHighlighted)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(RadioPlayer())
            .environmentObject(AppUpdater(startingUpdater: false))
    }
}
