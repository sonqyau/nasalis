import Foundation

struct AppState: Sendable, Equatable {
    var telemetry: TelemetrySnapshot

    init(telemetry: TelemetrySnapshot = .empty) {
        self.telemetry = telemetry
    }
}

struct TelemetrySnapshot: Sendable, Equatable {
    var timestamp: Date

    var telemetryError: String?

    var chargeLimitPercent: Int?

    var batteryPercent: Int?
    // swiftlint:disable:next discouraged_optional_boolean
    var isCharging: Bool?

    var designCapacity_mAh: Int?
    var maxCapacity_mAh: Int?
    var cycleCount: Int?
    var temperatureC: Double?
    var serialNumber: String?

    var batteryVoltageV: Double?
    var batteryAmperageA: Double?

    var adapterVoltageV: Double?
    var adapterAmperageA: Double?

    var adapterPowerW: Double?
    var systemLoadW: Double?
    var batteryPowerW: Double?

    static let empty = Self(
        timestamp: .distantPast,
        telemetryError: nil,
        chargeLimitPercent: nil,
        batteryPercent: nil,
        isCharging: nil,
        designCapacity_mAh: nil,
        maxCapacity_mAh: nil,
        cycleCount: nil,
        temperatureC: nil,
        serialNumber: nil,
        batteryVoltageV: nil,
        batteryAmperageA: nil,
        adapterVoltageV: nil,
        adapterAmperageA: nil,
        adapterPowerW: nil,
        systemLoadW: nil,
        batteryPowerW: nil,
        )
}
