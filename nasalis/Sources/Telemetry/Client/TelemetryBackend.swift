import Foundation

enum TelemetryBackend: String, Sendable {
    case smcBridge

    static let userDefaultsKey = "nasalis.telemetry.backend"

    static func current() -> TelemetryBackend {
        let raw = UserDefaults.standard.string(forKey: userDefaultsKey) ?? TelemetryBackend.smcBridge.rawValue
        return TelemetryBackend(rawValue: raw) ?? .smcBridge
    }
}
