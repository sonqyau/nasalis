import Foundation

@inline(__always)
let appReducer: Reducer<AppState, AppAction> = { state, action in
    if case let .telemetryUpdated(snapshot) = action {
        state.telemetry = snapshot
    }
}
