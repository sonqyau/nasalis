import Foundation

@MainActor
final class MainViewModel: ViewModelProtocol {
    let input: BatteryInput
    let output: MainState

    private let store: Store<AppState, AppAction>
    private let telemetryService: TelemetryServiceProtocol

    private var actionHandlingTask: Task<Void, Never>?
    private var stateSubscriptionTask: Task<Void, Never>?
    private var pollingTask: Task<Void, Never>?

    init(
        store: Store<AppState, AppAction>,
        telemetryService: TelemetryServiceProtocol = TelemetryService(),
        ) {
        self.store = store
        self.telemetryService = telemetryService
        input = BatteryInput()
        output = MainState()

        setupActionHandling()
        setupStateSubscription()
    }

    deinit {
        actionHandlingTask?.cancel()
        stateSubscriptionTask?.cancel()
        pollingTask?.cancel()
    }

    private func setupActionHandling() {
        actionHandlingTask = Task { [weak self] in
            guard let self else { return }

            for await action in input.actions {
                await handle(action)
            }
        }
    }

    private func setupStateSubscription() {
        stateSubscriptionTask = Task { [weak self] in
            guard let self else { return }

            for await state in await store.states() {
                output.telemetry = state.telemetry
            }
        }
    }

    private func handle(_ action: MainActions) async {
        switch action {
        case .viewAppeared:
            await startTelemetryPolling()

        case .viewDisappeared:
            stopTelemetryPolling()

        case .refreshRequested:
            await refreshTelemetry()

        case let .telemetryUpdated(snapshot):
            await store.dispatch(.telemetryUpdated(snapshot))
        }
    }

    private func startTelemetryPolling() async {
        guard pollingTask == nil else { return }

        output.isLoading = true

        pollingTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                let snapshot = await telemetryService.fetchSnapshot()
                input.send(.telemetryUpdated(snapshot))

                await MainActor.run {
                    self.output.isLoading = false
                    self.output.error = nil
                }

                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func stopTelemetryPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        output.isLoading = false
    }

    private func refreshTelemetry() async {
        output.isLoading = true

        let snapshot = await telemetryService.fetchSnapshot()
        input.send(.telemetryUpdated(snapshot))
        output.error = nil
        output.isLoading = false
    }
}

protocol TelemetryServiceProtocol: Sendable {
    func fetchSnapshot() async -> TelemetrySnapshot
}

final class TelemetryService: TelemetryServiceProtocol {
    private let client = TelemetryClient()

    func fetchSnapshot() async -> TelemetrySnapshot {
        await client.fetchSnapshot()
    }
}
