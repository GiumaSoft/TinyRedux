//


import Foundation
import Synchronization


extension ReduxStore.Worker {

  /// Element transported by the dispatcher stream: the action, whether the enqueue
  /// incremented a `.limit` counter (so the worker decrements it once processed), and an
  /// optional single-shot ``SnapshotRequest`` riding along to the pipeline terminal
  /// (`nil` on the normal, non-snapshot dispatch path).
  typealias TaggedActionEvent = (action: A, counted: Bool, onTerminal: SnapshotRequest<S>?)


  /// Dispatcher
  ///
  /// Serializes action dispatch through a single UNBOUNDED `AsyncStream`. Nonisolated write
  /// side (`tryEnqueue`) → main-actor read side (`events`), drained by the Worker loop.
  /// Optional per-`action.id` rate-control (``DispatchRateLimit``) gates admission BEFORE
  /// the yield, under a `Mutex` (dispatch is nonisolated → concurrent). `.none` is lock-free
  /// (the continuation's `yield` is already thread-safe).
  final class Dispatcher: Sendable
  {

    /// Per-`action.id` rate-control state (guarded by `mutex`).
    private struct RateState
    {
      var counts:   [String: Int] = [:]                       // .limit  (pending count)
      var lastTime: [String: ContinuousClock.Instant] = [:]   // .throttle (last admitted)
    }
    private let mutex = Mutex(RateState())

    private let stream: AsyncStream<TaggedActionEvent>
    private let continuation: AsyncStream<TaggedActionEvent>.Continuation

    init()
    {
      var continuation: AsyncStream<TaggedActionEvent>.Continuation!
      self.stream = AsyncStream<TaggedActionEvent>(bufferingPolicy: .unbounded) { continuation = $0 }
      self.continuation = continuation
    }

    /// The event stream. Consumed once by the Worker loop.
    var events: AsyncStream<TaggedActionEvent> { stream }

    /// Admits and enqueues an action, applying the rate limit. Thread-safe, any context.
    /// `onTerminal` carries a single-shot snapshot request to the pipeline terminal.
    @discardableResult
    nonisolated
    func tryEnqueue(_ action: A,
                    rate limit: DispatchRateLimit = .none,
                    onTerminal: SnapshotRequest<S>? = nil) -> Result<Void, ReduxError>
    {
      switch limit
      {
        case .none:
          return yield(action, counted: false, onTerminal: onTerminal)   // lock-free fast path

        case .limit(let max):
          let admitted = mutex.withLock { state -> Bool in
            let current = state.counts[action.id, default: 0]
            guard current < max else { return false }
            state.counts[action.id] = current + 1
            return true
          }
          guard admitted else { return .failure(.rateLimited) }
          return yield(action, counted: true, onTerminal: onTerminal)

        case .throttle(let interval):
          let admitted = mutex.withLock { state -> Bool in
            let now = ContinuousClock.now
            if let last = state.lastTime[action.id], now - last < interval { return false }
            state.lastTime[action.id] = now
            return true
          }
          guard admitted else { return .failure(.rateLimited) }
          return yield(action, counted: false, onTerminal: onTerminal)
      }
    }

    /// Releases a `.limit` slot after the worker finished processing the event's action.
    nonisolated
    func consume(id: String, counted: Bool)
    {
      guard counted else { return }
      mutex.withLock { state in
        guard let current = state.counts[id] else { return }
        if current > 1 { state.counts[id] = current - 1 } else { state.counts[id] = nil }
      }
    }

    /// Terminates the stream. Idempotent, thread-safe.
    nonisolated
    func finish()
    {
      continuation.finish()
    }

    /// Yields the tagged event; maps the `YieldResult` to a `Result`.
    private nonisolated
    func yield(_ action: A, counted: Bool, onTerminal: SnapshotRequest<S>?) -> Result<Void, ReduxError>
    {
      switch continuation.yield((action: action, counted: counted, onTerminal: onTerminal))
      {
        case .enqueued:   return .success(())
        case .terminated: return .failure(.terminated)
        default:          return .failure(.terminated)   // `.dropped` only with a bounded buffer
      }
    }
  }
}
