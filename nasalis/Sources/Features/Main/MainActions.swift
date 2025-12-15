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

    var actions: AsyncStream<MainActions> {
        actionChannel.stream
    }

    func send(_ action: MainActions) {
        actionChannel.send(action)
    }

    func viewAppeared() {
        send(.viewAppeared)
    }

    func viewDisappeared() {
        send(.viewDisappeared)
    }

    func refreshRequested() {
        send(.refreshRequested)
    }
}
