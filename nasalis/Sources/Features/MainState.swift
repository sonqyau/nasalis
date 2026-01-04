import Foundation

@MainActor
final class MainState: ViewModelOutput {
  @Published var currentTelemetry: TelemetrySnapshot = .empty
  @Published var systemMetrics: SystemMetrics = .empty
  @Published var launchAtLogin: Bool = false
  @Published var isLoading: Bool = false
  @Published var error: NSError?

  private static let chargingPowerThreshold: Float32 = 0.5
  private static let chargingAmperageThreshold: Float32 = 0.05

  private static let accessibilityBatteryPrefix = "Battery: "
  private static let accessibilityChargingStatus = "Charging"
  private static let accessibilityNotChargingStatus = "Not Charging"
  private static let accessibilityDefaultBatteryText = "Battery"
  private static let accessibilitySeparator = ", "

  private static let batteryIconCharging = "battery.100percent.bolt"
  private static let batteryIcon100 = "battery.100percent"
  private static let batteryIcon75 = "battery.75percent"
  private static let batteryIcon50 = "battery.50percent"
  private static let batteryIcon25 = "battery.25percent"
  private static let batteryIcon0 = "battery.0percent"

  @inline(__always)
  var batteryLevel: Int? {
    currentTelemetry.batteryPercentInt
  }

  @inline(__always)
  var isBatteryCharging: Bool {
    if currentTelemetry.isBatteryCharging { return true }

    if let power = currentTelemetry.batteryPowerW, power > Self.chargingPowerThreshold {
      return true
    }

    if let amperage = currentTelemetry.batteryAmperageA, amperage > Self.chargingAmperageThreshold {
      return true
    }

    return false
  }

  @inline(__always)
  var batteryStatusIconName: String {
    if isBatteryCharging { return Self.batteryIconCharging }

    guard let percentage = batteryLevel else { return Self.batteryIcon0 }

    if percentage >= 88 { return Self.batteryIcon100 }
    if percentage >= 63 { return Self.batteryIcon75 }
    if percentage >= 38 { return Self.batteryIcon50 }
    if percentage >= 13 { return Self.batteryIcon25 }
    return Self.batteryIcon0
  }

  @inline(__always)
  var accessibilityLabel: String {
    let percentage = batteryLevel
    let isCharging = isBatteryCharging

    if let percentage {
      let percentText = Self.accessibilityBatteryPrefix + String(percentage) + "%"
      let statusText =
        isCharging ? Self.accessibilityChargingStatus : Self.accessibilityNotChargingStatus
      return percentText + Self.accessibilitySeparator + statusText
    }

    return isCharging ? Self.accessibilityChargingStatus : Self.accessibilityNotChargingStatus
  }

  func reset() {
    currentTelemetry = .empty
    systemMetrics = .empty
    launchAtLogin = false
    isLoading = false
    error = nil
  }
}
