// swift-tools-version: 6.2


import Synchronization


/// Thread-safe per-action-type counter for dispatch throttling.
/// Uses `action.id` as key — groups by case name, ignoring associated values.
final class ActionCounter: Sendable {
  private let counts = Mutex<[String: UInt]>([:])

  /// Checks whether the action can be enqueued under the given limit.
  /// - Returns: `true` if enqueued (limit == 0 means unlimited), `false` if at capacity.
  func tryEnqueue(id: String, limit: UInt) -> Bool {
    counts.withLock {
      guard limit > 0 else { return true }
      let current = $0[id, default: 0]
      guard current < limit else { return false }
      $0[id] = current + 1
      return true
    }
  }

  /// Decrements the counter for the given action id.
  /// Removes the key when reaching zero.
  func decrease(id: String) {
    counts.withLock {
      guard let current = $0[id] else { return }
      if current <= 1 {
        $0.removeValue(forKey: id)
      } else {
        $0[id] = current - 1
      }
    }
  }
}
