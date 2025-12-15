import Foundation
import os.lock

final class ActionChannel<Action: Sendable>: @unchecked Sendable {
    private let lock = os_unfair_lock_t.allocate(capacity: 1)
    private var continuation: AsyncStream<Action>.Continuation?

    let stream: AsyncStream<Action>

    init() {
        lock.initialize(to: os_unfair_lock())

        var localContinuation: AsyncStream<Action>.Continuation?
        stream = AsyncStream { continuation in
            localContinuation = continuation
        }
        continuation = localContinuation
    }

    deinit {
        lock.deinitialize(count: 1)
        lock.deallocate()
    }

    @inline(__always)
    func send(_ action: Action) {
        os_unfair_lock_lock(lock)
        continuation?.yield(action)
        os_unfair_lock_unlock(lock)
    }

    @inline(__always)
    func finish() {
        os_unfair_lock_lock(lock)
        continuation?.finish()
        os_unfair_lock_unlock(lock)
    }
}
