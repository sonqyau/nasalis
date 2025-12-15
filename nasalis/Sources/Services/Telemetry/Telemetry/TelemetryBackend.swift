import Foundation

enum TelemetryBackend: String, Sendable {
    case smcBridge

    static let userDefaultsKey = "nasalis.telemetry.backend"

    static func current() -> Self {
        let raw = UserDefaults.standard.string(forKey: userDefaultsKey) ?? Self.smcBridge.rawValue
        return Self(rawValue: raw) ?? .smcBridge
    }
}
