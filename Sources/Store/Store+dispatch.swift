//


import Foundation


extension Store {

  /// Publishes one or more actions to the dispatcher for asynchronous processing.
  ///
  /// - Parameters:
  ///   - maxDispatchable: Maximum number of buffered actions with the same `id`.
  ///     `0` (default) means unlimited.
  ///   - actions: The actions to dispatch.
  nonisolated
  public func dispatch(maxDispatchable: UInt = 0, _ actions: A...) {
    worker.dispatch(maxDispatchable: maxDispatchable, actions: actions)
  }

  /// Publishes an array of actions to the dispatcher for asynchronous processing.
  ///
  /// - Parameters:
  ///   - maxDispatchable: Maximum number of buffered actions with the same `id`.
  ///     `0` (default) means unlimited.
  ///   - actions: The actions to dispatch.
  nonisolated
  public func dispatch(maxDispatchable: UInt = 0, actions: [A]) {
    worker.dispatch(maxDispatchable: maxDispatchable, actions: actions)
  }

  /// Dispatches an action and returns an encoded snapshot of the state after the
  /// pipeline completes.
  ///
  /// The action goes through the same FIFO queue as ``dispatch(maxDispatchable:_:)``,
  /// preserving deterministic ordering. The caller suspends until the worker loop
  /// completes the pipeline (middleware → reducer → resolver) for this action.
  ///
  /// - Parameters:
  ///   - action: The action to dispatch.
  ///   - snapshot: The `ReduxStateSnapshot` conformer whose `init(state:)` captures
  ///     the relevant state slice. The Worker encodes it to JSON at the pipeline terminal.
  /// - Returns: `.success(Data)` with the JSON-encoded snapshot, or `.failure(Error)` if
  ///   the pipeline failed, the action was rejected, or encoding threw.
  nonisolated
  public func dispatch<T>(
    _ action: A,
    snapshot: T.Type
  ) async -> ReduxEncodedSnapshot where T: ReduxStateSnapshot<S> {
    let snapshotClosure: @MainActor @Sendable (S.ReadOnly) throws -> Data = { readOnly in
      let encoder = JSONEncoder()
      let value = T(state: readOnly)

      return try encoder.encode(value)
    }

    return await withCheckedContinuation { continuation in
      let handler = ReadOnlySnapshot<S>(
        continuation: continuation,
        snapshot: snapshotClosure
      )
      worker.dispatch(action, onSnapshot: handler)
    }
  }
}
