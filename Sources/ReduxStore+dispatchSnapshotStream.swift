//


import Foundation


extension ReduxStore {

  /// Dispatches an arming action and returns a bounded stream of JSON-encoded snapshots,
  /// emitted whenever the spec's edge-trigger key changes at a reduce terminal.
  ///
  /// Streaming twin of the single-shot ``dispatch(_:snapshot:)``: `snapshot: Type.self`
  /// returns ONE value, `snapshot: SnapshotSpec(…)` returns a STREAM. The entry is
  /// registered *before* the arming action is enqueued (same MainActor turn), so a state
  /// change caused by the arming action itself is not missed.
  ///
  /// The stream ends at the spec's required `limit` (count / time / both), on consumer
  /// cancellation (breaking the `for await` loop), and eagerly on store `deinit`. The buffer
  /// is unbounded: a slow consumer receives every frame in order, up to the limit. A frame
  /// that fails to encode is delivered as `.failure` and does NOT count toward a `.count`
  /// bound (one bad reading must not kill a live feed).
  ///
  /// - Parameters:
  ///   - action: The arming action to dispatch (e.g. a side effect enabling a feed).
  ///   - spec: What to capture, when to emit, and how the stream is bounded.
  /// - Returns: An `AsyncStream` of ``ReduxEncodedSnapshot`` frames.
  nonisolated
  public func dispatch(_ action: A, snapshot spec: SnapshotSpec<S>)
    -> AsyncStream<ReduxEncodedSnapshot>
  {
    let id = UUID().uuidString
    let worker = self.worker

    // Decompose the required limit into a count bound and/or a time bound.
    let countBound: UInt?
    let timeBound: Duration?
    switch spec.limit
    {
      case .count(let count):             countBound = count; timeBound = nil
      case .time(let duration):           countBound = nil;   timeBound = duration
      case .timeOrCount(let duration, let count): countBound = count; timeBound = duration
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

      // Time bound: whoever removes the entry logs the reason; if we win the race, it is a
      // limit (time) — so onTermination, finding it already gone, stays silent.
      let timeTask: Task<Void, Never>? = timeBound.map { duration in
        Task {
          try? await Task.sleep(for: duration)
          await MainActor.run {
            if worker.streams.unregister(id: id) { worker.noteStreamFinished(id: id, reason: .limitReached) }
          }
          continuation.finish()
        }
      }

      // Fires on EVERY termination (limit / store deinit / consumer cancel). It logs
      // `.consumerCancelled` ONLY when it is the one that removes the entry — limit/deinit
      // paths have already removed it, so `unregister` returns `false` and we stay silent.
      continuation.onTermination = { _ in
        timeTask?.cancel()
        Task { @MainActor in
          if worker.streams.unregister(id: id) { worker.noteStreamFinished(id: id, reason: .consumerCancelled) }
        }
      }

      // Register THEN arm, in the same MainActor turn — closes the race between registration
      // and the arming action's reduce terminal. A rejected arming action can never reduce,
      // so the stream is failed eagerly instead of staying armed forever.
      Task { @MainActor in
        worker.registerStream(entry, action: action, emitInitial: spec.emitInitial)
        if case .failure(let error) = worker.dispatch(action)
        {
          continuation.yield(.failure(error))
          if worker.streams.unregister(id: id) { worker.noteStreamFinished(id: id, reason: .armingRejected) }
          continuation.finish()
        }
      }
    }
  }
}
