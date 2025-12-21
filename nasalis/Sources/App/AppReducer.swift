import Foundation

@inline(__always)
let appReducer: Reducer<AppState, AppAction> = { state, action in
    switch action {
    case let .telemetryUpdated(snapshot):
        state.telemetry = snapshot
    case let .systemMetricsUpdated(metrics):
        state.systemMetrics = metrics
    case let .launchAtLoginToggled(enabled):
        state.launchAtLogin = enabled
    }
}
