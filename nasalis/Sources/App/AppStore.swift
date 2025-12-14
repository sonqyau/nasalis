import Foundation

actor AppStore<State: Sendable, Action: Sendable> {
    private var state: State
    private let reducer: Reducer<State, Action>

    private var continuations: [UUID: AsyncStream<State>.Continuation] = [:]

    init(initialState: State, reducer: @escaping Reducer<State, Action>) {
        state = initialState
        self.reducer = reducer
    }

    func currentState() -> State {
        state
    }

    func dispatch(_ action: Action) {
        reducer(&state, action)
        broadcast(state)
    }

    func states() -> AsyncStream<State> {
        AsyncStream { continuation in
            let id = UUID()
            continuations[id] = continuation
            continuation.yield(state)

            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id: id) }
            }
        }
    }

    private func broadcast(_ state: State) {
        for (_, continuation) in continuations {
            continuation.yield(state)
        }
    }

    private func removeContinuation(id: UUID) {
        continuations[id] = nil
    }
}

typealias AppStoreType = AppStore<AppState, AppAction>
