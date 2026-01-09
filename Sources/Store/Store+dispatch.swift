// Store+dispatch.swift
// TinyRedux

import Foundation

extension Store {

    /// Publishes an action to the dispatcher for asynchronous processing.
    /// - Parameters:
    ///   - maxDispatchable: Maximum number of buffered actions with the same `id`.
    ///     `0` (default) means unlimited.
    ///   - action: The action to dispatch.
    nonisolated public func dispatch(maxDispatchable: UInt = 0, _ action: Action) {
        worker.dispatch(maxDispatchable: maxDispatchable, action)
    }

    /// Publishes an action and invokes a completion handler with the updated state
    /// once the worker loop has processed it.
    /// - Parameters:
    ///   - maxDispatchable: Maximum number of buffered actions with the same `id`.
    ///     `0` (default) means unlimited.
    ///   - action: The action to dispatch.
    ///   - completion: Called with the read-only state snapshot after the pipeline runs.
    ///     Skipped silently when the action is throttled.
    @discardableResult
    nonisolated public func dispatch(
        maxDispatchable: UInt = 0,
        _ action: Action,
        completion: @escaping @Sendable (State.ReadOnly) -> Void
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
    ///     `0` (default) means unlimited. Throttled actions return the current state
    ///     without running the pipeline.
    ///   - action: The action to dispatch.
    /// - Returns: The read-only state snapshot after the reducer has run.
    @MainActor
    public func dispatchWithResult(maxDispatchable: UInt = 0, _ action: Action) async -> State.ReadOnly {
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
