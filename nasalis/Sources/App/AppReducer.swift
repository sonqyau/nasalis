import Foundation

@inline(__always)
let appReducer: Reducer<AppState, AppAction> = { state, action in
  switch action {
  case .telemetryUpdated(let snapshot):
    state.telemetry = snapshot
  case .systemMetricsUpdated(let metrics):
    state.systemMetrics = metrics
  case .launchAtLoginToggled(let enabled):
    state.launchAtLogin = enabled
  }
}
