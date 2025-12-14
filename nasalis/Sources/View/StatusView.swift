import SwiftUI

struct StatusView: View {
    let feature: MainFeature

    @State private var state: AppState = .init()

    var body: some View {
        Image(systemName: symbolName)
            .imageScale(.large)
            .symbolRenderingMode(.hierarchical)
            .task {
                feature.actions.send(.appear)
                for await s in feature.state {
                    state = s
                }
            }
            .onDisappear {
                feature.actions.send(.disappear)
            }
            .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var parts: [String] = []
        if let percent = state.telemetry.batteryPercent { parts.append("Battery: \(percent)%") }
        if let isCharging = state.telemetry.isCharging {
            parts.append(isCharging ? "Charging" : "Not charging")
        }
        return parts.isEmpty ? "Battery" : parts.joined(separator: ", ")
    }

    private var inferredCharging: Bool {
        if let isCharging = state.telemetry.isCharging { return isCharging }
        if let p = state.telemetry.batteryPowerW { return p > 0.5 }
        if let a = state.telemetry.batteryAmperageA { return a > 0.05 }
        return false
    }

    private var symbolName: String {
        if inferredCharging {
            return "battery.100percent.bolt"
        }

        guard let p = state.telemetry.batteryPercent else {
            return "battery.0percent"
        }

        switch p {
        case 88...:
            return "battery.100percent"
        case 63 ... 87:
            return "battery.75percent"
        case 38 ... 62:
            return "battery.50percent"
        case 13 ... 37:
            return "battery.25percent"
        default:
            return "battery.0percent"
        }
    }
}
