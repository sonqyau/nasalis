import Foundation

let appReducer: Reducer<AppState, AppAction> = { state, action in
    switch action {
    case let .telemetryUpdated(snapshot):
        state.telemetry = snapshot
    }
}
