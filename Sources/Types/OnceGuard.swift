// OnceGuard.swift
// TinyRedux

import Foundation
import Synchronization

/// Thread-safe one-shot guard. Shared by reference across copies of a context struct.
/// The first call to ``tryConsume()`` returns `true`; all subsequent calls return `false`.
@usableFromInline
final class OnceGuard {

    private let state: Mutex<Bool>

    init() {
        self.state = Mutex(false)
    }

    func tryConsume() -> Bool {
        state.withLock { consumed in
            guard !consumed else { return false }
            consumed = true
            return true
        }
    }
}
