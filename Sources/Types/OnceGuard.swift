// swift-tools-version: 6.2


import Synchronization


/// Thread-safe one-shot guard. Shared by reference across copies of a context struct.
/// The first call to ``tryConsume()`` returns `true`; all subsequent calls return `false`.
@usableFromInline
final class OnceGuard: Sendable {
  private let state = Mutex(false)

  func tryConsume() -> Bool {
    state.withLock {
      guard !$0 else { return false }
      $0 = true
      return true
    }
  }
}
