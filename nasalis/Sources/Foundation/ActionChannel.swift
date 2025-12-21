import Combine
import Foundation

final class ActionChannel<Action: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private let subject = PassthroughSubject<Action, Never>()
    private var continuation: AsyncStream<Action>.Continuation?
    private var cancellables = Set<AnyCancellable>()
    private var isStreamActive = false

    let stream: AsyncStream<Action>
    let publisher: AnyPublisher<Action, Never>

    init() {
        var localContinuation: AsyncStream<Action>.Continuation?

        let asyncStream = AsyncStream<Action> { continuation in
            localContinuation = continuation
        }

        let actionPublisher = subject.eraseToAnyPublisher()

        stream = asyncStream
        publisher = actionPublisher

        lock.lock()
        continuation = localContinuation
        isStreamActive = true
        lock.unlock()

        localContinuation?.onTermination = { [weak self] _ in
            self?.lock.lock()
            self?.isStreamActive = false
            self?.continuation = nil
            self?.lock.unlock()
        }

        subject
            .sink { [weak self] action in
                self?.forwardToStream(action)
            }
            .store(in: &cancellables)
    }

    private func forwardToStream(_ action: Action) {
        lock.lock()
        defer { lock.unlock() }

        if isStreamActive {
            continuation?.yield(action)
        }
    }

    @inline(__always)
    func send(_ action: Action) {
        subject.send(action)
    }

    @inline(__always)
    func finish() {
        lock.lock()
        defer { lock.unlock() }

        subject.send(completion: .finished)
        continuation?.finish()
        isStreamActive = false
        continuation = nil
    }
}
