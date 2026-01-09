//


import Foundation
import Synchronization


extension Store.Worker {

  /// Dispatcher
  ///
  /// Serializes action dispatch through a single AsyncStream with explicit capacity
  /// accounting. The stream is used as a transport mechanism only (`bufferingPolicy: .unbounded`);
  /// admission control is enforced by the dispatcher via `pendingCount` and the configured
  /// `dispatcherCapacity`. Nonisolated write side (`tryEnqueue`) → MainActor read side (`events`).
  ///
  /// `pendingCount` represents queued + in-flight actions: a slot is freed only after the
  /// worker has fully processed an event (reducer + synchronous middleware step). This
  /// is enforced by the worker via `consume(id:)` invoked in a `defer` for every event read
  /// from the stream, regardless of generation staleness.
  ///
  /// Each enqueued element is tagged with the current generation counter. `flush()` increments
  /// the generation and resets rate-limiting counters. The Worker checks generation on MainActor:
  /// current-generation elements run the full pipeline; stale elements resume the snapshot
  /// continuation with `.failure(.staleGeneration)`.
  final class Dispatcher: Sendable {
    /// Element type consumed by the Worker loop.
    struct TaggedActionEvent: Sendable {
      let action: A
      let onSnapshot: ReadOnlySnapshot<S>?
      let generation: UInt64
    }

    // MARK: - Mutable State

    private struct MutableState: ~Copyable {
      var generation: UInt64 = 0
      var counts: [String: UInt] = [:]
      var pendingCount: Int = 0
      var isTerminated: Bool = false
      var isSuspended: Bool = false
    }

    // MARK: - Properties

    private let stream: AsyncStream<TaggedActionEvent>
    private let continuation: AsyncStream<TaggedActionEvent>.Continuation
    private let mutex: Mutex<MutableState>
    private let capacity: Int

    // MARK: - Init

    init(capacity: Int) {
      var c: AsyncStream<TaggedActionEvent>.Continuation!
      self.stream = AsyncStream<TaggedActionEvent>(bufferingPolicy: .unbounded) { c = $0 }
      self.continuation = c
      self.mutex = Mutex(MutableState())
      self.capacity = capacity
    }

    /// The element stream. Single-consumption by the Worker loop.
    var events: AsyncStream<TaggedActionEvent> { stream }

    /// Current pending count (queued + in-flight). Exposed for tests via `@testable`.
    var pendingCount: Int {
      mutex.withLock { $0.pendingCount }
    }

    // MARK: - Enqueue / Consume

    /// Validates lifecycle, generation, capacity, and per-action limit; on success increments
    /// `pendingCount` and (when `limit > 0`) `counts[id]`, then yields the event to the stream.
    /// - Parameters:
    ///   - id: Action identifier for grouping.
    ///   - limit: Maximum buffered actions with same id. `0` means unlimited.
    ///   - generation: Optional. If provided, the enqueue is rejected with
    ///     `.staleGeneration` unless the current generation matches. Used to prevent ghost
    ///     dispatches from subscription matches racing with `flush()` / `suspend()`.
    ///   - event: The element to enqueue.
    /// - Returns: `.success(())` if enqueued, otherwise `.failure(EnqueueFailure)` describing why.
    @discardableResult
    func tryEnqueue(
      id: String,
      limit: UInt,
      generation: UInt64? = nil,
      _ event: ActionEvent<S, A>
    ) -> Result<Void, EnqueueFailure> {
      let outcome = mutex.withLock { state -> (Result<Void, EnqueueFailure>, UInt64) in
        guard !state.isTerminated else { return (.failure(.terminated), 0) }
        guard !state.isSuspended else { return (.failure(.suspended), 0) }
        if let expected = generation, state.generation != expected {

          return (.failure(.staleGeneration), 0)
        }
        guard state.pendingCount < capacity else { return (.failure(.bufferLimitReached), 0) }
        if limit > 0 {
          let current = state.counts[id, default: 0]
          guard current < limit else { return (.failure(.maxDispatchableReached), 0) }
          state.counts[id] = current + 1
        }
        state.pendingCount += 1

        return (.success(()), state.generation)
      }

      let (result, gen) = outcome
      if case .success = result {
        continuation.yield(TaggedActionEvent(
          action: event.action,
          onSnapshot: event.onSnapshot,
          generation: gen
        ))
      }

      return result
    }

    /// Releases an enqueue slot after the worker has fully processed an event.
    /// Decrements `pendingCount` (floored at zero) and `counts[id]` when the id is present.
    /// Safe across `flush()` / `suspend()` resets that clear `counts`.
    func consume(id: String) {
      mutex.withLock { state in
        if state.pendingCount > 0 {
          state.pendingCount -= 1
        }
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
    /// (snapshot continuation resumed with `.failure(.staleGeneration)`, no pipeline).
    /// New enqueues carry the new generation.
    /// Note: `pendingCount` is not reset — stale events still occupy a slot until the
    /// worker drains them and calls `consume(id:)`.
    func flush() {
      mutex.withLock { state in
        guard !state.isTerminated else { return }
        state.generation &+= 1
        state.counts = [:]
      }
    }

    // MARK: - Suspend / Resume

    /// Flushes pending actions and suspends the dispatcher.
    /// New enqueues are rejected with `.suspended` until ``resume()`` is called.
    ///
    /// - Warning: Intended for **testing purposes only**. Do not use in production code.
    ///   Suspending the dispatcher silently drops new actions, which can lead to inconsistent
    ///   state and hard-to-diagnose bugs in a live application.
    @discardableResult
    func suspend() -> Bool {
      mutex.withLock { state in
        guard !state.isTerminated, !state.isSuspended else { return false }
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
        guard !state.isTerminated else { return false }
        state.isTerminated = true

        return true
      }
      if shouldFinish {
        continuation.finish()
      }
    }
  }
}
