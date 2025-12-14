import Foundation

typealias Reducer<State, Action> = @Sendable (_ state: inout State, _ action: Action) -> Void

let appReducer: Reducer<AppState, AppAction> = { state, action in
    switch action {
    case let .telemetryUpdated(snapshot):
        state.telemetry = snapshot
    }
}
