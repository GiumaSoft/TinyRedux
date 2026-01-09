//


import Foundation


extension ReduxStore {

  /// Dispatches an action and, once the pipeline settles it, returns a JSON-encoded
  /// snapshot of the state (or a chosen projection).
  ///
  /// The action goes through the SAME FIFO queue as ``dispatch(_:)`` (always `.none` rate —
  /// a request/response is never rate-limited), preserving deterministic ordering. The
  /// caller suspends until the action reaches its pipeline terminal — end of the reducer
  /// chain, or any non-reducing exit (`.exit(.done)`, resolver failure) — at which point the
  /// continuation is resolved exactly once.
  ///
  /// - Parameters:
  ///   - action: The action to dispatch.
  ///   - snapshot: The ``ReduxStateSnapshot`` conformer whose `init(state:)` captures the
  ///     relevant slice; the Worker JSON-encodes it at the terminal with its shared encoder.
  /// - Returns: `.success(Data)` with the encoded snapshot, or `.failure(Error)` if the
  ///   pipeline failed, the action was rejected at the gate, the store was torn down, or
  ///   encoding threw.
  nonisolated
  public func dispatch<T>(_ action: A, snapshot: T.Type) async -> ReduxEncodedSnapshot
  where T: ReduxStateSnapshot<S>
  {
    await withCheckedContinuation { continuation in
      let request: SnapshotRequest<S> = (
        continuation: continuation,
        capture: { readOnly, encoder in try encoder.encode(T(state: readOnly)) }
      )
      worker.dispatch(action, snapshot: request)
    }
  }
}
