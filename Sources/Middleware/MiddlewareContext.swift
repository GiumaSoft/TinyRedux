// MiddlewareContext.swift
// TinyRedux

import Foundation

/// MiddlewareContext
///
/// Bundles the action and pipeline callbacks for a middleware step.
@frozen
public struct MiddlewareContext<State: ReduxState, Action: ReduxAction> {

    public typealias Dispatch = (UInt, Action...) -> Void
    public typealias Resolve = (SendableError) -> Void
    public typealias Next = @MainActor (Action) throws -> Void
    public typealias TaskContext = (State.ReadOnly) async throws -> Void
    public typealias TaskLauncher = (@escaping TaskContext) -> Void

    /// The action being processed.
    public let action: Action

    /// Enqueues one or more actions for future dispatch.
    public let dispatch: Dispatch

    /// Sends an error to the resolver chain.
    public let resolve: Resolve

    /// Launches a controlled async operation with state access, dispatch, and error routing.
    public let task: TaskLauncher

    private let _next: @MainActor (Action) throws -> Void
    private let _guard: OnceGuard
    private let _complete: (Result<Bool, any Error>) -> Void
    private let _completeGuard: OnceGuard

    /// Creates a context. Internal — only the Store pipeline builds these.
    init(
        action: Action,
        dispatch: @escaping Dispatch,
        resolve: @escaping Resolve,
        task: @escaping TaskLauncher,
        complete: @escaping (Result<Bool, any Error>) -> Void,
        _next: @escaping Next
    ) {
        self.action = action
        self.dispatch = dispatch
        self.resolve = resolve
        self.task = task
        self._complete = complete
        self._next = _next
        self._guard = OnceGuard()
        self._completeGuard = OnceGuard()
    }

    /// Forwards the current action to the next middleware/reducer.
    /// Second call is a silent no-op.
    @MainActor
    public func next() throws {
        guard _guard.tryConsume() else { return }
        try _next(action)
    }

    /// Forwards a different action to the next middleware/reducer.
    /// Second call is a silent no-op.
    @MainActor
    public func next(_ action: Action) throws {
        guard _guard.tryConsume() else { return }
        try _next(action)
    }

    /// Marks the action as handled and emits timing logs when enabled.
    /// Second call is a silent no-op.
    public func complete(_ result: Result<Bool, any Error> = .success(true)) {
        guard _completeGuard.tryConsume() else { return }
        _complete(result)
    }

    /// Destructured tuple: (dispatch, resolve, task, next, action).
    public var args: (Dispatch, Resolve, TaskLauncher, Next, Action) {
        (dispatch, resolve, task, _next, action)
    }
}
