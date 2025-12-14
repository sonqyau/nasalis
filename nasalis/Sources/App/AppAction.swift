import Foundation

enum AppAction: Sendable, Equatable {
    case telemetryUpdated(TelemetrySnapshot)
}
