import SwiftUI

private struct WidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct PowerView: View {
    let adapterPowerW: Double?
    let batteryPowerW: Double?
    let systemLoadW: Double?
    let isCharging: Bool

    static let iconSize: CGFloat = 16
    static let flowHeight: CGFloat = 40
    static let spacing: CGFloat = 5
    static let cornerRadius: CGFloat = 12
    static let iconFrame: CGFloat = iconSize + 20
    private static let animationInterval: TimeInterval = 4.0

    @State private var middleSectionWidth: CGFloat = 50
    @State private var animationPhase: UInt8 = 0
    @State private var flowProgress: CGFloat = 0
    @State private var animationWorkItem: DispatchWorkItem?

    var body: some View {
        let inputPower = adapterPowerW ?? 0
        let batteryPower = batteryPowerW ?? 0
        let systemLoad = systemLoadW ?? (batteryPower < 0 ? -batteryPower : 0)
        let isInputActive = inputPower > 0.01
        let isBatteryDischarging = batteryPower < 0
        let isChargePhase = animationPhase & 1 == 1
        let isLoadPhase = animationPhase & 2 == 2

        HStack(spacing: Self.spacing) {
            VStack(alignment: .leading, spacing: Self.flowHeight) {
                if isInputActive {
                    IconContainer(
                        icon: "powerplug.portrait",
                        height: batteryPower > 0 ? Self.flowHeight * 1.5 : Self.flowHeight,
                        isAnimated: isChargePhase,
                        color: .yellow,
                        corners: [true, false, false, true],
                    )
                }

                if isBatteryDischarging {
                    IconContainer(
                        icon: "battery.75",
                        height: Self.flowHeight,
                        isAnimated: isChargePhase,
                        color: .orange,
                        corners: [true, false, false, true],
                    )
                }
            }

            FlowSection(
                inputPower: inputPower,
                batteryPower: batteryPower,
                systemLoad: systemLoad,
                flowProgress: flowProgress,
                middleSectionWidth: middleSectionWidth,
                animationPhase: animationPhase,
            )

            VStack(alignment: .trailing, spacing: Self.flowHeight) {
                if batteryPower > 0 {
                    IconContainer(
                        icon: "battery.100.bolt",
                        height: Self.flowHeight,
                        isAnimated: isLoadPhase,
                        color: .green,
                        corners: [false, true, true, false],
                        offset: CGPoint(x: -1, y: 0),
                    )
                }

                IconContainer(
                    icon: "laptopcomputer",
                    height: (isBatteryDischarging && isInputActive) ? Self.flowHeight * 1.5 : Self.flowHeight,
                    isAnimated: isLoadPhase,
                    color: .blue,
                    corners: [false, true, true, false],
                    offset: CGPoint(x: -1, y: 0),
                )
            }
            .frame(width: Self.iconFrame)
        }
        .onAppear(perform: startAnimation)
        .onDisappear(perform: stopAnimation)
        .onPreferenceChange(WidthPreferenceKey.self) { width in
            if width > middleSectionWidth {
                middleSectionWidth = width
            }
        }
    }

    private func startAnimation() {
        guard middleSectionWidth <= 50 else { return }
        let screenWidth = NSScreen.main?.frame.width ?? 800
        middleSectionWidth = max(screenWidth * 0.4 - (Self.iconFrame * 2) - (Self.spacing * 2), 50)

        scheduleNextCycle()
    }

    private func stopAnimation() {
        animationWorkItem?.cancel()
        animationWorkItem = nil
    }

    private func scheduleNextCycle() {
        animationWorkItem?.cancel()

        let workItem = DispatchWorkItem {
            Task { @MainActor in
                runAnimationCycle()
                scheduleNextCycle()
            }
        }

        animationWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.animationInterval, execute: workItem)
    }

    @MainActor
    private func runAnimationCycle() {
        withAnimation(.easeInOut(duration: 1.0)) {
            animationPhase = 1
            flowProgress = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.linear(duration: 2.0)) {
                flowProgress = 1.0
            }
            withAnimation(.easeInOut(duration: 1.0).delay(1.0)) {
                animationPhase = 2
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 1.0)) {
                    animationPhase = 0
                    flowProgress = 0
                }
            }
        }
    }

    static func watts(_ value: Double) -> String {
        String(format: "%.2f W", value)
    }
}

private struct IconContainer: View {
    let icon: String
    let height: CGFloat
    let isAnimated: Bool
    let color: Color
    let corners: [Bool]
    var offset: CGPoint = .init(x: 1, y: 0)

    private static let iconFont = Font.system(size: PowerView.iconSize)

    var body: some View {
        ZStack {
            SquircleShape(
                width: PowerView.iconFrame,
                height: height,
                radius: PowerView.cornerRadius,
                corners: corners,
            )
            .fill(.ultraThickMaterial)

            Image(systemName: icon)
                .font(Self.iconFont)
                .foregroundColor(isAnimated ? color : .primary)
                .offset(x: offset.x, y: offset.y)
        }
        .frame(width: PowerView.iconFrame, height: height)
    }
}

private struct FlowSection: View {
    let inputPower: Double
    let batteryPower: Double
    let systemLoad: Double
    let flowProgress: CGFloat
    let middleSectionWidth: CGFloat
    let animationPhase: UInt8

    private var flowColor: Color {
        switch animationPhase {
        case 1: .yellow.opacity(0.8)
        case 2: .blue.opacity(0.8)
        default: .clear
        }
    }

    private var flowWidth: CGFloat {
        flowProgress * middleSectionWidth
    }

    var body: some View {
        Group {
            if inputPower > 0.01 {
                if abs(batteryPower) < 0.0001 {
                    FlowBar(
                        height: PowerView.flowHeight,
                        label: PowerView.watts(inputPower),
                        flowWidth: flowWidth,
                        flowColor: flowColor,
                        middleSectionWidth: middleSectionWidth,
                    )
                } else if batteryPower > 0 {
                    VStack(spacing: 0) {
                        FlowShaped(
                            height: PowerView.flowHeight * 1.5,
                            startLength: PowerView.flowHeight * 0.75,
                            endLength: PowerView.flowHeight,
                            direction: 1,
                            label: PowerView.watts(batteryPower),
                            flowWidth: flowWidth,
                            flowColor: flowColor,
                            middleSectionWidth: middleSectionWidth,
                        )
                        FlowShaped(
                            height: PowerView.flowHeight * 1.5,
                            startLength: PowerView.flowHeight * 0.75,
                            endLength: PowerView.flowHeight,
                            direction: 0,
                            label: PowerView.watts(systemLoad),
                            flowWidth: flowWidth,
                            flowColor: flowColor,
                            middleSectionWidth: middleSectionWidth,
                        )
                    }
                } else {
                    VStack(spacing: 0) {
                        FlowShaped(
                            height: PowerView.flowHeight * 1.5,
                            startLength: PowerView.flowHeight,
                            endLength: PowerView.flowHeight * 0.75,
                            direction: 0,
                            label: PowerView.watts(inputPower),
                            flowWidth: flowWidth,
                            flowColor: flowColor,
                            middleSectionWidth: middleSectionWidth,
                        )
                        FlowShaped(
                            height: PowerView.flowHeight * 1.5,
                            startLength: PowerView.flowHeight,
                            endLength: PowerView.flowHeight * 0.75,
                            direction: 1,
                            label: PowerView.watts(-batteryPower),
                            flowWidth: flowWidth,
                            flowColor: flowColor,
                            middleSectionWidth: middleSectionWidth,
                        )
                    }
                }
            } else {
                FlowBar(
                    height: PowerView.flowHeight,
                    label: PowerView.watts(-batteryPower),
                    flowWidth: flowWidth,
                    flowColor: flowColor,
                    middleSectionWidth: middleSectionWidth,
                )
            }
        }
    }
}

private struct FlowBar: View {
    let height: CGFloat
    let label: String
    let flowWidth: CGFloat
    let flowColor: Color
    let middleSectionWidth: CGFloat

    private static let gradient = LinearGradient(
        colors: [.clear, .white],
        startPoint: .leading,
        endPoint: .trailing,
    )

    var body: some View {
        ZStack {
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(.ultraThickMaterial)
                    .frame(height: height)
                    .background(
                        GeometryReader { geometry in
                            Color.clear.preference(key: WidthPreferenceKey.self, value: geometry.size.width)
                        },
                    )

                Rectangle()
                    .fill(Self.gradient)
                    .colorMultiply(flowColor)
                    .blur(radius: 1.5)
                    .frame(width: flowWidth, height: height)
            }

            Text(label)
                .font(.body)
        }
    }
}

private struct FlowShaped: View {
    let height: CGFloat
    let startLength: CGFloat
    let endLength: CGFloat
    let direction: Int
    let label: String
    let flowWidth: CGFloat
    let flowColor: Color
    let middleSectionWidth: CGFloat

    private static let gradient = LinearGradient(
        colors: [.clear, .white],
        startPoint: .leading,
        endPoint: .trailing,
    )

    private var clipShape: FlowClipShape {
        FlowClipShape(
            width: middleSectionWidth,
            height: height,
            startLength: startLength,
            endLength: endLength,
            direction: direction,
        )
    }

    var body: some View {
        ZStack {
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(.ultraThickMaterial)
                    .frame(width: middleSectionWidth, height: height)
                    .clipShape(clipShape)

                Rectangle()
                    .fill(Self.gradient)
                    .colorMultiply(flowColor)
                    .blur(radius: 1.5)
                    .frame(width: flowWidth, height: height)
                    .clipShape(clipShape)
            }

            Text(label)
                .font(.body)
        }
    }
}

private struct SquircleShape: Shape {
    let width: CGFloat
    let height: CGFloat
    let radius: CGFloat
    let corners: [Bool]

    private static let coefficients: [CGFloat] = [0.0, 6.6844, 14.4275, 23.6278, 36.7519, 63.0]
    private static let anchors: [CGFloat] = [11.457, 8.843]

    func path(in _: CGRect) -> Path {
        generateSquircle(width: width, height: height, radius: radius, corners: corners)
    }
}

func generateSquircle(width: CGFloat, height: CGFloat, radius: CGFloat, corners: [Bool]) -> Path {
    var path = Path()

    let ratio = radius * 0.02857142857
    let coeffs: (CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat) = (
        0, 6.6844 * ratio, 14.4275 * ratio, 23.6278 * ratio, 36.7519 * ratio, 63.0 * ratio,
    )
    let anchors: (CGFloat, CGFloat) = (11.457 * ratio, 8.843 * ratio)

    let (s0, s1, s2, s3, s4, s5) = coeffs
    let (s6, s7) = anchors

    let w = (width - s0, width - s1, width - s2, width - s3, width - s4, width - s5, width - s6, width - s7)
    let h = (height - s0, height - s1, height - s2, height - s3, height - s4, height - s5, height - s6, height - s7)

    path.move(to: CGPoint(x: s0, y: s5))

    if corners[3] {
        path.addCurve(to: CGPoint(x: s1, y: s2), control1: CGPoint(x: s0, y: s4), control2: CGPoint(x: s0, y: s3))
        path.addCurve(to: CGPoint(x: s2, y: s1), control1: CGPoint(x: s7, y: s6), control2: CGPoint(x: s6, y: s7))
        path.addCurve(to: CGPoint(x: s5, y: s0), control1: CGPoint(x: s3, y: s0), control2: CGPoint(x: s4, y: s0))
    } else {
        path.addLine(to: CGPoint(x: s0, y: s0))
        path.addLine(to: CGPoint(x: s5, y: s0))
    }

    path.addLine(to: CGPoint(x: w.4, y: s0))

    if corners[2] {
        path.addCurve(to: CGPoint(x: w.1, y: s1), control1: CGPoint(x: w.3, y: s0), control2: CGPoint(x: w.2, y: s0))
        path.addCurve(to: CGPoint(x: w.0, y: s2), control1: CGPoint(x: w.5, y: s7), control2: CGPoint(x: w.6, y: s6))
        path.addCurve(to: CGPoint(x: w.0, y: s5), control1: CGPoint(x: w.0, y: s3), control2: CGPoint(x: w.0, y: s4))
    } else {
        path.addLine(to: CGPoint(x: w.0, y: s0))
        path.addLine(to: CGPoint(x: w.0, y: s5))
    }

    path.addLine(to: CGPoint(x: w.0, y: h.4))

    if corners[1] {
        path.addCurve(to: CGPoint(x: w.0, y: h.1), control1: CGPoint(x: w.0, y: h.3), control2: CGPoint(x: w.0, y: h.2))
        path.addCurve(to: CGPoint(x: w.1, y: h.0), control1: CGPoint(x: w.6, y: h.5), control2: CGPoint(x: w.5, y: h.6))
        path.addCurve(to: CGPoint(x: w.4, y: h.0), control1: CGPoint(x: w.2, y: h.0), control2: CGPoint(x: w.3, y: h.0))
    } else {
        path.addLine(to: CGPoint(x: w.0, y: h.0))
        path.addLine(to: CGPoint(x: w.4, y: h.0))
    }

    path.addLine(to: CGPoint(x: s5, y: h.0))

    if corners[0] {
        path.addCurve(to: CGPoint(x: s2, y: h.0), control1: CGPoint(x: s4, y: h.0), control2: CGPoint(x: s3, y: h.0))
        path.addCurve(to: CGPoint(x: s1, y: h.1), control1: CGPoint(x: s6, y: h.6), control2: CGPoint(x: s7, y: h.5))
        path.addCurve(to: CGPoint(x: s0, y: h.4), control1: CGPoint(x: s0, y: h.2), control2: CGPoint(x: s0, y: h.3))
    } else {
        path.addLine(to: CGPoint(x: s0, y: h.0))
        path.addLine(to: CGPoint(x: s0, y: h.4))
    }

    path.closeSubpath()
    return path
}

struct FlowClipShape: Shape {
    let width: CGFloat
    let height: CGFloat
    let startLength: CGFloat
    let endLength: CGFloat
    let direction: Int

    func path(in _: CGRect) -> Path {
        flowShape(width: width, height: height, startLength: startLength, endLength: endLength, direction: direction)
    }
}

func flowShape(width: CGFloat, height: CGFloat, startLength: CGFloat, endLength: CGFloat, direction: Int) -> Path {
    var path = Path()

    let w3 = width * 0.3
    let w7 = width * 0.7

    if direction == 0 {
        let endY = height - endLength
        path.move(to: .zero)
        path.addCurve(to: CGPoint(x: width, y: endY), control1: CGPoint(x: w3, y: 0), control2: CGPoint(x: w7, y: endY))
        path.addLine(to: CGPoint(x: width, y: height))
        path.addCurve(to: CGPoint(x: 0, y: startLength), control1: CGPoint(x: w7, y: height), control2: CGPoint(x: w3, y: startLength))
    } else {
        let startY = height - startLength
        path.move(to: CGPoint(x: 0, y: startY))
        path.addCurve(to: CGPoint(x: width, y: 0), control1: CGPoint(x: w3, y: startY), control2: CGPoint(x: w7, y: 0))
        path.addLine(to: CGPoint(x: width, y: endLength))
        path.addCurve(to: CGPoint(x: 0, y: height), control1: CGPoint(x: w7, y: endLength), control2: CGPoint(x: w3, y: height))
    }

    path.closeSubpath()
    return path
}
