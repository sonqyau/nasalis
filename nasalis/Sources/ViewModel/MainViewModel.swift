import Foundation

@MainActor
final class MainViewModel: ObservableObject {
    let feature: MainFeature

    private let store: AppStoreType
    private let telemetryClient = TelemetryClient()

    private var actionHandlingTask: Task<Void, Never>?
    private var pollingTask: Task<Void, Never>?

    init(store: AppStoreType) {
        self.store = store

        let actions = ActionChannel<MainAction>()
        feature = MainFeature(actions: actions, state: AsyncStream { continuation in
            Task {
                for await s in await store.states() {
                    continuation.yield(s)
                }
            }
        })

        actionHandlingTask = Task { [weak self] in
            guard let self else { return }
            for await action in actions.stream {
                await handle(action)
            }
        }
    }

    private func handle(_ action: MainAction) async {
        switch action {
        case .appear:
            startPollingIfNeeded()
        case .disappear:
            stopPolling()
        }
    }

    private func startPollingIfNeeded() {
        guard pollingTask == nil else { return }

        pollingTask = Task { [store, telemetryClient] in
            while !Task.isCancelled {
                let snapshot = await telemetryClient.fetchSnapshot()
                await store.dispatch(.telemetryUpdated(snapshot))
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
}
