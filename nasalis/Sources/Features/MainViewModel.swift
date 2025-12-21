import AppKit
@preconcurrency import Combine
import Foundation
import ServiceManagement

@MainActor
final class MainViewModel: ViewModelProtocol {
    let input: BatteryInput
    let output: MainState

    private let store: Store<AppState, AppAction>
    private let telemetryService: TelemetryServiceProtocol
    private let systemMonitor: SystemMonitor
    private let launchAtLoginService: LaunchAtLoginService

    private var pollingCancellable: AnyCancellable?
    private var powerStateCancellable: AnyCancellable?
    private var systemMetricsCancellable: AnyCancellable?
    private var stateCancellable: AnyCancellable?
    private var actionHandlingTask: Task<Void, Never>?
    private var currentPollingInterval: TimeInterval

    private static let fastPollingInterval: TimeInterval = 1.0
    private static let slowPollingInterval: TimeInterval = 5.0
    private static let telemetryUpdatedAction = AppAction.telemetryUpdated
    private static let systemMetricsUpdatedAction = AppAction.systemMetricsUpdated
    private static let launchAtLoginToggledAction = AppAction.launchAtLoginToggled

    init(
        store: Store<AppState, AppAction>,
        telemetryService: TelemetryServiceProtocol = TelemetryService(),
        systemMonitor: SystemMonitor = SystemMonitor(),
    ) {
        self.store = store
        self.telemetryService = telemetryService
        self.systemMonitor = systemMonitor

        launchAtLoginService = LaunchAtLoginService()

        input = BatteryInput()
        output = MainState()
        currentPollingInterval = Self.fastPollingInterval

        setupActionHandling()
        setupStateSubscription()
        setupPowerStateMonitoring()
        setupSystemMonitoring()

        // startTelemetryPolling()
    }

    @MainActor
    deinit {
        pollingCancellable?.cancel()
        powerStateCancellable?.cancel()
        systemMetricsCancellable?.cancel()
        stateCancellable?.cancel()
        actionHandlingTask?.cancel()
        input.finish()
        output.reset()
        systemMonitor.stopMonitoring()
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
        Task { @MainActor [weak self] in
            guard let self else { return }
            let publisher = await store.publisher
            stateCancellable = publisher
                .receive(on: DispatchQueue.main)
                .sink { state in
                    self.output.currentTelemetry = state.telemetry
                    self.output.systemMetrics = state.systemMetrics
                    self.output.launchAtLogin = state.launchAtLogin
                }
        }
    }

    private func setupSystemMonitoring() {
        systemMonitor.startMonitoring(interval: 5.0)

        systemMetricsCancellable = systemMonitor.$metrics
            .compactMap(\.self)
            .removeDuplicates()
            .sink { [weak self] metrics in
                Task {
                    await self?.store.dispatch(Self.systemMetricsUpdatedAction(metrics))
                }
            }
    }

    @inline(__always)
    private func handle(_ action: MainActions) async {
        switch action {
        case .viewAppeared:
            startTelemetryPolling()
        case .viewDisappeared:
            stopTelemetryPolling()
        case .refreshRequested:
            refreshTelemetry()
        case let .telemetryUpdated(snapshot):
            await store.dispatch(Self.telemetryUpdatedAction(snapshot))
        case let .systemMetricsUpdated(metrics):
            await store.dispatch(Self.systemMetricsUpdatedAction(metrics))
        case let .launchAtLoginToggled(enabled):
            handleLaunchAtLoginToggle(enabled)
            await store.dispatch(Self.launchAtLoginToggledAction(enabled))
        }
    }

    @MainActor
    private func handleLaunchAtLoginToggle(_ enabled: Bool) {
        if enabled {
            launchAtLoginService.enableSync()
        } else {
            launchAtLoginService.disableSync()
        }
    }

    private func startTelemetryPolling() {
        guard pollingCancellable == nil else { return }

        output.isLoading = true

        pollingCancellable = Timer.publish(every: currentPollingInterval, on: .main, in: .common)
            .autoconnect()
            .compactMap { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let snapshot = await telemetryService.fetchSnapshot()
                    adjustPollingInterval(for: snapshot)
                    input.send(.telemetryUpdated(snapshot))
                    output.isLoading = false
                    output.error = snapshot.telemetryError
                }
                return ()
            }
            .sink { _ in }

        DispatchQueue.main.asyncAfter(deadline: .now()) { [weak self] in
            guard let self else { return }
            Task {
                let snapshot = await self.telemetryService.fetchSnapshot()
                self.adjustPollingInterval(for: snapshot)
                self.input.send(.telemetryUpdated(snapshot))
                self.output.isLoading = false
                self.output.error = snapshot.telemetryError
            }
        }
    }

    @inline(__always)
    private func stopTelemetryPolling() {
        pollingCancellable?.cancel()
        pollingCancellable = nil
        output.isLoading = false
    }

    private func refreshTelemetry() {
        output.isLoading = true

        Task {
            let snapshot = await telemetryService.fetchSnapshot()
            input.send(.telemetryUpdated(snapshot))

            output.error = snapshot.telemetryError
            output.isLoading = false
        }
    }

    private func setupPowerStateMonitoring() {
        let wakePublisher = NotificationCenter.default
            .publisher(for: NSWorkspace.didWakeNotification)
            .map { _ in () }

        let powerSourcePublisher = NotificationCenter.default
            .publisher(for: NSNotification.Name(rawValue: "com.apple.powermanagement.powerSourceChanged"))
            .map { _ in () }

        powerStateCancellable = Publishers.Merge(wakePublisher, powerSourcePublisher)
            .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] in
                self?.handlePowerStateChange()
            }
    }

    private func handlePowerStateChange() {
        Task {
            refreshTelemetry()
        }
    }

    private func adjustPollingInterval(for snapshot: TelemetrySnapshot) {
        let shouldUseFastPolling = snapshot.isBatteryCharging || snapshot.batteryPercent.map { $0 <= 20 } ?? false

        let newInterval = shouldUseFastPolling ? Self.fastPollingInterval : Self.slowPollingInterval

        if newInterval != currentPollingInterval {
            currentPollingInterval = newInterval

            pollingCancellable?.cancel()
            pollingCancellable = Timer.publish(every: currentPollingInterval, on: .main, in: .common)
                .autoconnect()
                .compactMap { [weak self] _ in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        let snapshot = await telemetryService.fetchSnapshot()
                        adjustPollingInterval(for: snapshot)
                        input.send(.telemetryUpdated(snapshot))
                        output.isLoading = false
                        output.error = snapshot.telemetryError
                    }
                    return ()
                }
                .sink { _ in }
        }
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
