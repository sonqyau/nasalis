import Foundation

final class ActionChannel<Action: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: AsyncStream<Action>.Continuation?

    let stream: AsyncStream<Action>

    init() {
        var localContinuation: AsyncStream<Action>.Continuation?
        stream = AsyncStream { continuation in
            localContinuation = continuation
        }
        continuation = localContinuation
    }

    func send(_ action: Action) {
        lock.lock()
        defer { lock.unlock() }
        continuation?.yield(action)
    }

    func finish() {
        lock.lock()
        defer { lock.unlock() }
        continuation?.finish()
    }
}
