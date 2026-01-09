//


import Foundation
import Synchronization


extension Store.Worker {

  /// Dispatcher
  ///
  /// Serializes action dispatch through a single AsyncStream with built-in rate limiting.
  /// Nonisolated write side (`tryEnqueue`) → MainActor read side (`events`).
  ///
  /// Each enqueued element is tagged with the current generation counter. `flush()` increments the
  /// generation and resets rate-limiting counters. The Worker checks generation on MainActor:
  /// current-generation elements run the full pipeline; stale elements invoke only their completion
  /// (so `dispatchWithResult` continuations are always resumed).
  final class Dispatcher: Sendable {
    /// Element type consumed by the Worker loop.
    struct TaggedActionEvent: Sendable {
      let action: A
      let completion: ActionHandler<S>?
      let generation: UInt64
    }

    // MARK: - Mutable State

    private struct MutableState: ~Copyable {
      var generation: UInt64 = 0
      var counts: [String: UInt] = [:]
      var isFinished: Bool = false
      var isSuspended: Bool = false
    }

    // MARK: - Properties

    private let stream: AsyncStream<TaggedActionEvent>
    private let continuation: AsyncStream<TaggedActionEvent>.Continuation
    private let mutex: Mutex<MutableState>

    // MARK: - Init

    init(bufferingPolicy: AsyncStream<TaggedActionEvent>.Continuation.BufferingPolicy = .bufferingOldest(256)) {
      var c: AsyncStream<TaggedActionEvent>.Continuation!
      self.stream = AsyncStream<TaggedActionEvent>(bufferingPolicy: bufferingPolicy) { c = $0 }
      self.continuation = c
      self.mutex = Mutex(MutableState())
    }

    /// The element stream. Single-consumption by the Worker loop.
    var events: AsyncStream<TaggedActionEvent> { stream }

    // MARK: - Enqueue / Decrease

    /// Checks rate limit, increments counter, and enqueues element tagged with current generation.
    /// - Parameters:
    ///   - id: Action identifier for grouping.
    ///   - limit: Maximum buffered actions with same id. `0` means unlimited.
    ///   - event: The element to enqueue.
    /// - Returns: `true` if enqueued, `false` if finished, suspended, or at capacity.
    /// Checks rate limit, optionally validates `generation`, increments counter,
    /// and enqueues element tagged with current generation.
    /// - Parameters:
    ///   - id: Action identifier for grouping.
    ///   - limit: Maximum buffered actions with same id. `0` means unlimited.
    ///   - generation: Optional. If provided, the enqueue is rejected unless the current
    ///     generation matches. Used to prevent ghost dispatches from subscription matches
    ///     racing with `flush()`/`suspend()`.
    ///   - event: The element to enqueue.
    /// - Returns: `true` if enqueued, `false` if finished, suspended, at capacity, or stale generation.
    @discardableResult
    func tryEnqueue(
      id: String,
      limit: UInt,
      generation: UInt64? = nil,
      _ event: ActionEvent<S, A>
    ) -> Bool {
      let (allowed, gen) = mutex.withLock { state -> (Bool, UInt64) in
        guard !state.isFinished else { return (false, 0) }
        guard !state.isSuspended else { return (false, 0) }
        if let expected = generation, state.generation != expected {
          return (false, 0)
        }
        if limit > 0 {
          let current = state.counts[id, default: 0]
          guard current < limit else { return (false, 0) }
          state.counts[id] = current + 1
        }
        return (true, state.generation)
      }
      if allowed {
        continuation.yield(TaggedActionEvent(
          action: event.action,
          completion: event.completion,
          generation: gen
        ))
      }
      return allowed
    }

    /// Decrements the counter for the given action id.
    /// Removes the key when reaching zero.
    func decrease(id: String) {
      mutex.withLock { state in
        guard let current = state.counts[id] else { return }
        if current <= 1 {
          state.counts.removeValue(forKey: id)
        } else {
          state.counts[id] = current - 1
        }
      }
    }

    // MARK: - Generation

    /// Returns `true` if the given generation matches the current one.
    func isCurrentGeneration(_ generation: UInt64) -> Bool {
      mutex.withLock { $0.generation == generation }
    }

    /// Current generation counter. Incremented on each `flush()`/`suspend()`.
    var currentGeneration: UInt64 {
      mutex.withLock { $0.generation }
    }

    // MARK: - Flush

    /// Increments the generation counter and resets rate-limiting state.
    /// Stale elements already in the stream buffer will be skipped by the worker
    /// (completion-only, no pipeline). New enqueues carry the new generation.
    func flush() {
      mutex.withLock { state in
        guard !state.isFinished else { return }
        state.generation &+= 1
        state.counts = [:]
      }
    }

    // MARK: - Suspend / Resume

    /// Flushes pending actions and suspends the dispatcher.
    /// New enqueues are rejected (`tryEnqueue` returns `false`) until ``resume()`` is called.
    ///
    /// - Warning: Intended for **testing purposes only**. Do not use in production code.
    ///   Suspending the dispatcher silently drops new actions, which can lead to inconsistent
    ///   state and hard-to-diagnose bugs in a live application.
    @discardableResult
    func suspend() -> Bool {
      mutex.withLock { state in
        guard !state.isFinished, !state.isSuspended else { return false }
        state.isSuspended = true
        state.generation &+= 1
        state.counts = [:]
        return true
      }
    }

    /// Resumes a suspended dispatcher, allowing new enqueues.
    ///
    /// - Warning: Intended for **testing purposes only**. Do not use in production code.
    @discardableResult
    func resume() -> Bool {
      mutex.withLock { state in
        guard state.isSuspended else { return false }
        state.isSuspended = false
        return true
      }
    }

    // MARK: - Finish

    /// Terminates the stream. Idempotent.
    func finish() {
      let shouldFinish = mutex.withLock { state -> Bool in
        guard !state.isFinished else { return false }
        state.isFinished = true
        return true
      }
      if shouldFinish {
        continuation.finish()
      }
    }
  }
}
