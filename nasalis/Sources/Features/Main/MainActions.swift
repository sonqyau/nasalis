import Foundation

enum MainActions: Sendable, Equatable {
    case viewAppeared
    case viewDisappeared
    case telemetryUpdated(TelemetrySnapshot)
    case refreshRequested
}

@MainActor
final class BatteryInput: ViewModelInput {
    private let actionChannel = ActionChannel<MainActions>()

    private static let viewAppearedAction = MainActions.viewAppeared
    private static let viewDisappearedAction = MainActions.viewDisappeared
    private static let refreshRequestedAction = MainActions.refreshRequested

    @inline(__always)
    var actions: AsyncStream<MainActions> {
        actionChannel.stream
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
}
