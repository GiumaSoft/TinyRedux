//


import Foundation


extension Store {

  /// Dispatches an action and returns a bounded stream of encoded snapshots,
  /// emitted whenever the spec's edge-trigger key changes at a reduce terminal.
  ///
  /// Streaming twin of the single-shot ``dispatch(_:snapshot:)``: `snapshot:
  /// Type.self` returns **one** snapshot, `snapshot: SnapshotSpec(…)` returns a
  /// **stream**. The entry is registered *before* the arming action is enqueued
  /// (same MainActor turn), so a state change caused by the arming action
  /// itself is not missed.
  ///
  /// The stream ends at the spec's required `limit`, on consumer cancellation
  /// (breaking the `for await` loop), and eagerly on ``flush()`` / ``suspend()``
  /// / `deinit`. The buffer is unbounded: a slow consumer receives every frame
  /// in order, up to the limit.
  ///
  /// - Parameters:
  ///   - action: The arming action to dispatch (e.g. a side effect enabling
  ///     notifications).
  ///   - spec: What to capture, when to emit, and how the stream is bounded.
  ///
  /// - Returns: An `AsyncStream` of `Result<Data, Error>` frames. A frame that
  ///   fails to encode is delivered as `.failure` and does not count toward a
  ///   `.count` bound.
  nonisolated
  public func dispatch(
    _ action: A,
    snapshot spec: SnapshotSpec<S>
  ) -> AsyncStream<ReduxEncodedSnapshot> {
    let id = UUID().uuidString
    let worker = self.worker

    /// Decompose the required limit into a count bound and/or a time bound.
    let countBound: UInt?
    let timeBound: Duration?

    switch spec.limit {
    case .count(let count):
      countBound = count
      timeBound = nil

    case .time(let duration):
      countBound = nil
      timeBound = duration

    case .timeOrCount(let duration, let count):
      countBound = count
      timeBound = duration
    }

    return AsyncStream(bufferingPolicy: .unbounded) { continuation in
      let entry = Worker.StreamEntry(
        id: id,
        trigger: spec.trigger,
        encode: spec.encode,
        yield: { continuation.yield($0) },
        finish: { continuation.finish() },
        remaining: countBound
      )
      let timeTask: Task<Void, Never>? = timeBound.map { duration in
        Task {
          try? await Task.sleep(for: duration)
          continuation.finish()
        }
      }

      continuation.onTermination = { _ in
        timeTask?.cancel()
        Task { @MainActor in
          worker.streams.unregister(id: id)
        }
      }

      /// Register THEN arm, in the same MainActor turn — closes the race
      /// between registration and the arming action's reduce terminal.
      /// A rejected arming action can never reduce, so the stream is failed
      /// eagerly instead of staying armed until an external termination.
      Task { @MainActor in
        worker.registerStream(entry, emitInitial: spec.emitInitial)
        if case let .failure(error) = worker.dispatchArming(action) {
          continuation.yield(.failure(error))
          continuation.finish()
        }
      }
    }
  }
}
