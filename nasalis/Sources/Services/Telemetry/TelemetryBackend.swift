import Foundation

enum TelemetryBackend: String, Sendable {
    case smcBridge

    private static let userDefaultsKey = "nasalis.telemetry.backend"
    private static let defaultBackend: Self = .smcBridge

    @inline(__always)
    static func current() -> Self {
        defaultBackend
    }
}
