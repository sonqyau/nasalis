import Foundation

@MainActor
final class MainState: ViewModelOutput {
    @Published var telemetry: TelemetrySnapshot = .empty
    @Published var isLoading: Bool = false
    @Published var error: String?

    private static let chargingThresholdPower: Float32 = 0.5
    private static let chargingThresholdAmperage: Float32 = 0.05
    private static let batteryPrefix = "Battery: "
    private static let chargingText = "Charging"
    private static let notChargingText = "Not charging"
    private static let fallbackText = "Battery"
    private static let separator = ", "

    private static let iconCharging = "battery.100percent.bolt"
    private static let icon100 = "battery.100percent"
    private static let icon75 = "battery.75percent"
    private static let icon50 = "battery.50percent"
    private static let icon25 = "battery.25percent"
    private static let icon0 = "battery.0percent"

    @inline(__always)
    var batteryPercentage: Int? {
        telemetry.batteryPercentInt
    }

    @inline(__always)
    var isCharging: Bool {
        let charging = telemetry.isCharging
        if charging { return true }

        if let power = telemetry.batteryPowerW, power > Self.chargingThresholdPower {
            return true
        }

        if let amperage = telemetry.batteryAmperageA, amperage > Self.chargingThresholdAmperage {
            return true
        }

        return false
    }

    @inline(__always)
    var batteryIconName: String {
        if isCharging { return Self.iconCharging }

        guard let percentage = batteryPercentage else { return Self.icon0 }

        if percentage >= 88 { return Self.icon100 }
        if percentage >= 63 { return Self.icon75 }
        if percentage >= 38 { return Self.icon50 }
        if percentage >= 13 { return Self.icon25 }
        return Self.icon0
    }

    @inline(__always)
    var accessibilityText: String {
        let percentage = batteryPercentage
        let charging = isCharging

        if let percentage {
            let percentText = Self.batteryPrefix + String(percentage) + "%"
            let statusText = charging ? Self.chargingText : Self.notChargingText
            return percentText + Self.separator + statusText
        }

        return charging ? Self.chargingText : Self.notChargingText
    }
}
