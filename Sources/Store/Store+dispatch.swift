//


import Foundation


extension Store {
  
  /// Publishes an action to the dispatcher for asynchronous processing.
  /// - Parameters:
  ///   - maxDispatchable: Maximum number of buffered actions with the same `id`.
  ///     `0` (default) means unlimited.
  ///   - actions: The actions to dispatch.
  nonisolated
  public func dispatch(maxDispatchable: UInt = 0, _ actions: A...) {
    worker.dispatch(maxDispatchable: maxDispatchable, actions: actions)
  }
  
  /// Publishes an action and invokes a completion handler with the updated state
  /// once the worker loop has processed it.
  /// - Parameters:
  ///   - maxDispatchable: Maximum number of buffered actions with the same `id`.
  ///     `0` (default) means unlimited.
  ///   - action: The action to dispatch.
  ///   - completion: Called with the read-only state snapshot after the pipeline runs.
  ///     Skipped silently when the action is throttled or the store is suspended.
  @discardableResult
  nonisolated
  public func dispatch(
    maxDispatchable: UInt = 0,
    _ action: A,
    completion: @escaping ActionHandler<S>
  ) -> Bool {
    worker.dispatch(maxDispatchable: maxDispatchable, action, completion: completion)
  }
  
  /// Dispatches an action and returns the updated read-only state after the worker
  /// loop has processed it.
  ///
  /// The action goes through the same FIFO queue as ``dispatch(maxDispatchable:_:)``,
  /// preserving deterministic ordering. The caller suspends until the worker loop
  /// completes the pipeline (middleware → reducer) for this action.
  ///
  /// - Parameters:
  ///   - maxDispatchable: Maximum number of buffered actions with the same `id`.
  ///     `0` (default) means unlimited. Throttled or suspended actions return the
  ///     current state without running the pipeline.
  ///   - action: The action to dispatch.
  /// - Returns: The read-only state snapshot after the reducer has run.
  @MainActor
  public func dispatchWithResult(maxDispatchable: UInt = 0, _ action: A) async -> S.ReadOnly {
    await withCheckedContinuation { continuation in
      let enqueued = worker.dispatch(
        maxDispatchable: maxDispatchable,
        action,
        completion: { readOnly in
          continuation.resume(returning: readOnly)
        }
      )
      if !enqueued {
        continuation.resume(returning: _state.readOnly)
      }
    }
  }
}
