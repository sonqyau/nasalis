import Foundation

enum AppAction: Sendable, Equatable {
    case telemetryUpdated(TelemetrySnapshot)
    case systemMetricsUpdated(SystemMetrics)
    case launchAtLoginToggled(Bool)
}
