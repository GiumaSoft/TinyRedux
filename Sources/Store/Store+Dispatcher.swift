// Store+Dispatcher.swift
// TinyRedux

import Foundation
import Synchronization

extension Store.DispatchWorker {

  /// Dispatcher
  ///
  /// Serializes action dispatch through a single AsyncStream with built-in rate limiting.
  /// Nonisolated write side (`tryEnqueue`) → MainActor read side (`actions`).
  /// Thread-safety guaranteed by `AsyncStream.Continuation` (Sendable) and `Mutex` for counters.
  final class Dispatcher: Sendable {
    typealias Event = (action: A, completion: (@Sendable (S.ReadOnly) -> Void)?)

    private let stream: AsyncStream<Event>
    private let continuation: AsyncStream<Event>.Continuation
    private let counts: Mutex<[String: UInt]>

    init(bufferingPolicy: AsyncStream<Event>.Continuation.BufferingPolicy = .bufferingOldest(256)) {
      var c: AsyncStream<Event>.Continuation!
      self.stream = AsyncStream(bufferingPolicy: bufferingPolicy) { c = $0 }
      self.continuation = c
      self.counts = Mutex([:])
    }

    /// The action stream. Single-consumption by the Worker loop.
    var actions: AsyncStream<Event> { stream }

    /// Checks rate limit, increments counter, and enqueues element atomically.
    /// - Parameters:
    ///   - id: Action identifier for grouping.
    ///   - limit: Maximum buffered actions with same id. `0` means unlimited.
    ///   - element: The element to enqueue.
    /// - Returns: `true` if enqueued, `false` if at capacity.
    @discardableResult
    func tryEnqueue(id: String, limit: UInt, _ element: Event) -> Bool {
      let allowed = counts.withLock { dict -> Bool in
        guard limit > 0 else { return true }
        let current = dict[id, default: 0]
        guard current < limit else { return false }
        dict[id] = current + 1
        return true
      }
      if allowed {
        continuation.yield(element)
      }
      return allowed
    }

    /// Decrements the counter for the given action id.
    /// Removes the key when reaching zero.
    func decrease(id: String) {
      counts.withLock { dict in
        guard let current = dict[id] else { return }
        if current <= 1 {
          dict.removeValue(forKey: id)
        } else {
          dict[id] = current - 1
        }
      }
    }

    /// Terminates the stream. Idempotent.
    func finish() {
      continuation.finish()
    }
  }
}
