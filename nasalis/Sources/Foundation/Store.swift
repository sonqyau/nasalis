@preconcurrency import Combine
import Foundation

actor Store<State: Sendable, Action: Sendable> {
  private var state: State
  private let reducer: Reducer<State, Action>
  private var continuations: ContiguousArray<AsyncStream<State>.Continuation>
  private var continuationCount: Int
  private let subject: CurrentValueSubject<State, Never>
  private let maxContinuations: Int

  init(initialState: State, reducer: @escaping Reducer<State, Action>) {
    state = initialState
    self.reducer = reducer
    subject = CurrentValueSubject<State, Never>(initialState)
    continuations = ContiguousArray()
    continuations.reserveCapacity(16)
    continuationCount = 0
    maxContinuations = 16
  }

  @inline(__always)
  func currentState() -> State {
    state
  }

  @inline(__always)
  func dispatch(_ action: Action) async {
    reducer(&state, action)
    broadcastState()
    let currentState = state
    await MainActor.run {
      subject.send(currentState)
    }
  }

  func states() -> AsyncStream<State> {
    AsyncStream { [weak self] continuation in
      guard let self else {
        continuation.finish()
        return
      }

      Task {
        await self.addContinuation(continuation)
        await continuation.yield(self.currentState())

        continuation.onTermination = { _ in
          Task { await self.removeContinuation(continuation) }
        }
      }
    }
  }

  var publisher: AnyPublisher<State, Never> {
    get async {
      subject.eraseToAnyPublisher()
    }
  }

  @inline(__always)
  private func broadcastState() {
    let currentState = state
    let count = continuationCount
    for i in 0..<count {
      continuations[i].yield(currentState)
    }
  }

  private func addContinuation(_ continuation: AsyncStream<State>.Continuation) {
    guard continuationCount < maxContinuations else { return }
    if continuationCount < continuations.count {
      continuations[continuationCount] = continuation
    } else {
      continuations.append(continuation)
    }
    continuationCount &+= 1
  }

  private func removeContinuation(_ targetContinuation: AsyncStream<State>.Continuation) {
    var idx = -1
    for i in 0..<continuationCount
    where withUnsafePointer(
      to: continuations[i],
      { ptr1 in
        withUnsafePointer(to: targetContinuation) { ptr2 in
          ptr1 == ptr2
        }
      })
    {
      idx = i
      break
    }

    guard idx >= 0 else { return }

    continuationCount &-= 1
    if idx < continuationCount {
      continuations[idx] = continuations[continuationCount]
    }
  }
}

typealias Reducer<State, Action> = @Sendable (_ state: inout State, _ action: Action) -> Void
