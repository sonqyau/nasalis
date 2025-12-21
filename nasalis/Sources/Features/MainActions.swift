import Combine
import Foundation

enum MainActions: Sendable, Equatable {
    case viewAppeared
    case viewDisappeared
    case telemetryUpdated(TelemetrySnapshot)
    case systemMetricsUpdated(SystemMetrics)
    case refreshRequested
    case launchAtLoginToggled(Bool)
}

@MainActor
final class BatteryInput: ViewModelInput {
    private let actionChannel = ActionChannel<MainActions>()
    private var cancellables = Set<AnyCancellable>()

    private static let viewAppearedAction = MainActions.viewAppeared
    private static let viewDisappearedAction = MainActions.viewDisappeared
    private static let refreshRequestedAction = MainActions.refreshRequested

    @inline(__always)
    var actions: AsyncStream<MainActions> {
        actionChannel.stream
    }

    @inline(__always)
    var publisher: AnyPublisher<MainActions, Never> {
        actionChannel.publisher
    }

    @inline(__always)
    func send(_ action: MainActions) {
        actionChannel.send(action)
    }

    @inline(__always)
    func viewAppeared() {
        actionChannel.send(Self.viewAppearedAction)
    }

    @inline(__always)
    func viewDisappeared() {
        actionChannel.send(Self.viewDisappearedAction)
    }

    @inline(__always)
    func refreshRequested() {
        actionChannel.send(Self.refreshRequestedAction)
    }

    @inline(__always)
    func launchAtLoginToggled(_ enabled: Bool) {
        actionChannel.send(.launchAtLoginToggled(enabled))
    }

    func finish() {
        actionChannel.finish()
        cancellables.removeAll()
    }
}
