import SwiftUI

struct WidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct PowerView: View {
    let adapterPowerW: Double?
    let batteryPowerW: Double?
    let systemLoadW: Double?
    let isCharging: Bool?

    private let iconSize: CGFloat = 16
    private let flowHeight: CGFloat = 40
    private let spacing: CGFloat = 5
    private let cornerRadius: CGFloat = 12

    @State private var middleSectionWidth: CGFloat = 10
    @State private var animateCharge = false
    @State private var animateLoad = false
    @State private var animateFlowWidth: CGFloat = 0
    @State private var animateFlowColor = Color.yellow.opacity(0.8)
    @State private var animationTimer: Timer?

    var body: some View {
        let inputPower = adapterPowerW ?? 0
        let batteryPower = batteryPowerW ?? 0
        let systemLoad = systemLoadW ?? (batteryPower < 0 ? abs(batteryPower) : 0)

        HStack(spacing: spacing) {
            VStack(alignment: .leading, spacing: flowHeight) {
                if inputPower > 0.01 {
                    ZStack {
                        generateSquircle(width: iconSize + 20, height: batteryPower > 0 ? flowHeight * 1.5 : flowHeight, radius: cornerRadius, corners: [true, false, false, true])
                            .fill(.ultraThickMaterial)
                        Image(systemName: "powerplug.portrait")
                            .font(.system(size: iconSize))
                            .foregroundColor(animateCharge ? Color.yellow : Color.primary)
                            .offset(x: 1, y: 0)
                    }
                    .frame(width: iconSize + 20, height: batteryPower > 0 ? flowHeight * 1.5 : flowHeight)
                }

                if batteryPower < 0 {
                    ZStack {
                        generateSquircle(width: iconSize + 20, height: flowHeight, radius: cornerRadius, corners: [true, false, false, true])
                            .fill(.ultraThickMaterial)
                        Image(systemName: "battery.75")
                            .font(.system(size: iconSize))
                            .foregroundColor(animateCharge ? Color.orange : Color.primary)
                            .offset(x: 1, y: 0)
                    }
                    .frame(width: iconSize + 20, height: flowHeight)
                }
            }

            Group {
                if inputPower > 0.01 {
                    if abs(batteryPower) < 0.0001 {
                        flowBar(height: flowHeight, label: watts(inputPower))
                    } else if batteryPower > 0 {
                        VStack(spacing: 0) {
                            flowShaped(height: flowHeight * 1.5, startLength: flowHeight * 0.75, endLength: flowHeight, direction: 1, label: watts(batteryPower))
                            flowShaped(height: flowHeight * 1.5, startLength: flowHeight * 0.75, endLength: flowHeight, direction: 0, label: watts(systemLoad))
                        }
                    } else {
                        VStack(spacing: 0) {
                            flowShaped(height: flowHeight * 1.5, startLength: flowHeight, endLength: flowHeight * 0.75, direction: 0, label: watts(inputPower))
                            flowShaped(height: flowHeight * 1.5, startLength: flowHeight, endLength: flowHeight * 0.75, direction: 1, label: watts(abs(batteryPower)))
                        }
                    }
                } else {
                    flowBar(height: flowHeight, label: watts(abs(batteryPower)))
                }
            }

            VStack(alignment: .trailing, spacing: flowHeight) {
                if batteryPower > 0 {
                    ZStack {
                        generateSquircle(width: iconSize + 20, height: flowHeight, radius: cornerRadius, corners: [false, true, true, false])
                            .fill(.ultraThickMaterial)
                        Image(systemName: "battery.100.bolt")
                            .font(.system(size: iconSize))
                            .foregroundColor(animateLoad ? Color.green : Color.primary)
                            .offset(x: -1, y: 0)
                    }
                    .frame(width: iconSize + 20, height: flowHeight)
                }

                ZStack {
                    generateSquircle(width: iconSize + 20, height: (batteryPower < 0 && inputPower > 0.01) ? flowHeight * 1.5 : flowHeight, radius: cornerRadius, corners: [false, true, true, false])
                        .fill(.ultraThickMaterial)
                    Image(systemName: "laptopcomputer")
                        .font(.system(size: iconSize))
                        .foregroundColor(animateLoad ? Color.blue : Color.primary)
                        .offset(x: -1, y: 0)
                }
                .frame(width: iconSize + 20, height: (batteryPower < 0 && inputPower > 0.01) ? flowHeight * 1.5 : flowHeight)
            }
            .frame(width: iconSize + 20)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if middleSectionWidth <= 10 {
                    let screenWidth = NSScreen.main?.frame.width ?? 800
                    let parentWidth = screenWidth * 0.4 - ((iconSize + 20) * 2) - (spacing * 2)
                    middleSectionWidth = max(parentWidth, 50)
                }
            }

            startAnimationCycle()
            animationTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
                Task { @MainActor in
                    startAnimationCycle()
                }
            }
        }
        .onDisappear {
            animationTimer?.invalidate()
            animationTimer = nil
        }
        .onPreferenceChange(WidthPreferenceKey.self) { width in
            if width > 10 {
                middleSectionWidth = width
            }
        }
    }

    @MainActor
    private func startAnimationCycle() {
        animateFlowWidth = 0
        animateFlowColor = Color.yellow.opacity(0.8)
        withAnimation(.easeOut(duration: 1.0)) {
            animateCharge = true
            animateLoad = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeIn(duration: 1.0)) {
                animateCharge = false
            }
            withAnimation(.linear(duration: 1.0)) {
                animateFlowWidth = middleSectionWidth / 2
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeOut(duration: 0.5)) {
                    animateFlowColor = Color.blue.opacity(0.8)
                }
                withAnimation(.linear(duration: 1.0)) {
                    animateFlowWidth = middleSectionWidth
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 1.0)) {
                    animateFlowColor = Color.clear
                    animateLoad = true
                }
            }
        }
    }

    private func flowBar(height: CGFloat, label: String) -> some View {
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
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.clear, animateFlowColor]),
                            startPoint: .leading,
                            endPoint: .trailing,
                            ),
                        )
                    .blur(radius: 1.5)
                    .frame(width: animateFlowWidth, height: height)
            }
            Text(label)
                .font(.body)
        }
    }

    private func flowShaped(height: CGFloat, startLength: CGFloat, endLength: CGFloat, direction: Int, label: String) -> some View {
        ZStack {
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(.ultraThickMaterial)
                    .frame(width: middleSectionWidth, height: height)
                    .clipShape(flowShape(width: middleSectionWidth, height: height, startLength: startLength, endLength: endLength, direction: direction))
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.clear, animateFlowColor]),
                            startPoint: .leading,
                            endPoint: .trailing,
                            ),
                        )
                    .blur(radius: 1.5)
                    .frame(width: animateFlowWidth, height: height)
                    .clipShape(flowShape(width: middleSectionWidth, height: height, startLength: startLength, endLength: endLength, direction: direction))
            }
            Text(label)
                .font(.body)
        }
    }

    private func watts(_ value: Double) -> String {
        String(format: "%.2f W", value)
    }
}

func generateSquircle(width: CGFloat, height: CGFloat, radius: CGFloat, corners: [Bool]) -> Path {
    precondition(corners.count == 4)
    var path = Path()

    let f5: CGFloat = 63.0
    let f4: CGFloat = 36.7519
    let f3: CGFloat = 23.6278
    let f2: CGFloat = 14.4275
    let f1: CGFloat = 6.6844
    let f0: CGFloat = 0.0
    let a0: CGFloat = 11.457
    let a1: CGFloat = 8.843

    let refRadius: CGFloat = 35
    let ratio: CGFloat = refRadius == 0 ? 0 : radius / refRadius

    let s0 = f0 * ratio
    let s1 = f1 * ratio
    let s2 = f2 * ratio
    let s3 = f3 * ratio
    let s4 = f4 * ratio
    let s5 = f5 * ratio
    let s6 = a0 * ratio
    let s7 = a1 * ratio

    let w0 = width - s0
    let w1 = width - s1
    let w2 = width - s2
    let w3 = width - s3
    let w4 = width - s4
    let w5 = width - s5
    let w6 = width - s6
    let w7 = width - s7

    let h0 = height - s0
    let h1 = height - s1
    let h2 = height - s2
    let h3 = height - s3
    let h4 = height - s4
    let h5 = height - s5
    let h6 = height - s6
    let h7 = height - s7

    path.move(to: CGPoint(x: s0, y: s5))

    let tl = corners[0]
    let tr = corners[1]
    let br = corners[2]
    let bl = corners[3]

    if bl {
        path.addCurve(to: CGPoint(x: s1, y: s2), control1: CGPoint(x: s0, y: s4), control2: CGPoint(x: s0, y: s3))
        path.addCurve(to: CGPoint(x: s2, y: s1), control1: CGPoint(x: s7, y: s6), control2: CGPoint(x: s6, y: s7))
        path.addCurve(to: CGPoint(x: s5, y: s0), control1: CGPoint(x: s3, y: s0), control2: CGPoint(x: s4, y: s0))
    } else {
        path.addLine(to: CGPoint(x: s0, y: s0))
        path.addLine(to: CGPoint(x: s5, y: s0))
    }

    path.addLine(to: CGPoint(x: w5, y: s0))

    if br {
        path.addCurve(to: CGPoint(x: w2, y: s1), control1: CGPoint(x: w4, y: s0), control2: CGPoint(x: w3, y: s0))
        path.addCurve(to: CGPoint(x: w1, y: s2), control1: CGPoint(x: w6, y: s7), control2: CGPoint(x: w7, y: s6))
        path.addCurve(to: CGPoint(x: w0, y: s5), control1: CGPoint(x: w0, y: s3), control2: CGPoint(x: w0, y: s4))
    } else {
        path.addLine(to: CGPoint(x: w0, y: s0))
        path.addLine(to: CGPoint(x: w0, y: s5))
    }

    path.addLine(to: CGPoint(x: w0, y: h5))

    if tr {
        path.addCurve(to: CGPoint(x: w1, y: h2), control1: CGPoint(x: w0, y: h4), control2: CGPoint(x: w0, y: h3))
        path.addCurve(to: CGPoint(x: w2, y: h1), control1: CGPoint(x: w7, y: h6), control2: CGPoint(x: w6, y: h7))
        path.addCurve(to: CGPoint(x: w5, y: h0), control1: CGPoint(x: w3, y: h0), control2: CGPoint(x: w4, y: h0))
    } else {
        path.addLine(to: CGPoint(x: w0, y: h0))
        path.addLine(to: CGPoint(x: w5, y: h0))
    }

    path.addLine(to: CGPoint(x: s5, y: h0))

    if tl {
        path.addCurve(to: CGPoint(x: s2, y: h1), control1: CGPoint(x: s4, y: h0), control2: CGPoint(x: s3, y: h0))
        path.addCurve(to: CGPoint(x: s1, y: h2), control1: CGPoint(x: s6, y: h7), control2: CGPoint(x: s7, y: h6))
        path.addCurve(to: CGPoint(x: s0, y: h5), control1: CGPoint(x: s0, y: h3), control2: CGPoint(x: s0, y: h4))
    } else {
        path.addLine(to: CGPoint(x: s0, y: h0))
        path.addLine(to: CGPoint(x: s0, y: h5))
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

    if direction == 0 {
        path.move(to: CGPoint(x: 0, y: 0))
        let c1 = CGPoint(x: width * 0.3, y: 0)
        let c2 = CGPoint(x: width * 0.7, y: height - endLength)
        path.addCurve(to: CGPoint(x: width, y: height - endLength), control1: c1, control2: c2)
        path.addLine(to: CGPoint(x: width, y: height))
        let c3 = CGPoint(x: width * 0.7, y: height)
        let c4 = CGPoint(x: width * 0.3, y: startLength)
        path.addCurve(to: CGPoint(x: 0, y: startLength), control1: c3, control2: c4)
        path.closeSubpath()
    } else {
        path.move(to: CGPoint(x: 0, y: height - startLength))
        let c1 = CGPoint(x: width * 0.3, y: height - startLength)
        let c2 = CGPoint(x: width * 0.7, y: 0)
        path.addCurve(to: CGPoint(x: width, y: 0), control1: c1, control2: c2)
        path.addLine(to: CGPoint(x: width, y: endLength))
        let c3 = CGPoint(x: width * 0.7, y: endLength)
        let c4 = CGPoint(x: width * 0.3, y: height)
        path.addCurve(to: CGPoint(x: 0, y: height), control1: c3, control2: c4)
        path.closeSubpath()
    }

    return path
}
