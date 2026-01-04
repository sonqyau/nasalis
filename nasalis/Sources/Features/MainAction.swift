import Combine
import Foundation

enum MainAction: Sendable, Equatable {
  case viewAppeared
  case viewDisappeared
  case telemetryUpdated(TelemetrySnapshot)
  case systemMetricsUpdated(SystemMetrics)
  case refreshRequested
  case launchAtLoginToggled(Bool)
}

@MainActor
final class MainInput: ViewModelInput {
  private let actionChannel = ActionChannel<MainAction>()
  private var cancellables = Set<AnyCancellable>()

  private static let viewAppearedAction = MainAction.viewAppeared
  private static let viewDisappearedAction = MainAction.viewDisappeared
  private static let refreshRequestedAction = MainAction.refreshRequested

  @inline(__always)
  var actions: AsyncStream<MainAction> {
    actionChannel.stream
  }

  @inline(__always)
  var publisher: AnyPublisher<MainAction, Never> {
    actionChannel.publisher
  }

  @inline(__always)
  func send(_ action: MainAction) {
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
