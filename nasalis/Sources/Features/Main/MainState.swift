import Foundation

@MainActor
final class MainState: ViewModelOutput {
    @Published var telemetry: TelemetrySnapshot = .empty
    @Published var isLoading: Bool = false
    @Published var error: String?

    var batteryPercentage: Int? {
        telemetry.batteryPercent
    }

    var isCharging: Bool {
        if let isCharging = telemetry.isCharging {
            return isCharging
        }
        if let power = telemetry.batteryPowerW {
            return power > 0.5
        }
        if let amperage = telemetry.batteryAmperageA {
            return amperage > 0.05
        }
        return false
    }

    var batteryIconName: String {
        if isCharging {
            return "battery.100percent.bolt"
        }

        guard let percentage = batteryPercentage else {
            return "battery.0percent"
        }

        switch percentage {
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

    var accessibilityText: String {
        var parts: [String] = []
        if let percent = batteryPercentage {
            parts.append("Battery: \(percent)%")
        }
        parts.append(isCharging ? "Charging" : "Not charging")
        return parts.isEmpty ? "Battery" : parts.joined(separator: ", ")
    }
}
