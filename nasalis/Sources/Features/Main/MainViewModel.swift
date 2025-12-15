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

    private static let pollingInterval: Duration = .seconds(1)
    private static let telemetryUpdatedAction = AppAction.telemetryUpdated

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
        actionHandlingTask = Task {
            for await action in input.actions {
                await self.handle(action)
            }
        }
    }

    private func setupStateSubscription() {
        stateSubscriptionTask = Task {
            for await state in await store.states() {
                self.output.telemetry = state.telemetry
            }
        }
    }

    @inline(__always)
    private func handle(_ action: MainActions) async {
        switch action {
        case .viewAppeared:
            await startTelemetryPolling()
        case .viewDisappeared:
            stopTelemetryPolling()
        case .refreshRequested:
            await refreshTelemetry()
        case let .telemetryUpdated(snapshot):
            await store.dispatch(Self.telemetryUpdatedAction(snapshot))
        }
    }

    private func startTelemetryPolling() async {
        guard pollingTask == nil else { return }

        output.isLoading = true

        pollingTask = Task {
            while !Task.isCancelled {
                let snapshot = await self.telemetryService.fetchSnapshot()
                self.input.send(.telemetryUpdated(snapshot))

                self.output.isLoading = false
                self.output.error = nil

                try? await Task.sleep(for: Self.pollingInterval)
            }
        }
    }

    @inline(__always)
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

    @inline(__always)
    func fetchSnapshot() async -> TelemetrySnapshot {
        await client.fetchSnapshot()
    }
}
