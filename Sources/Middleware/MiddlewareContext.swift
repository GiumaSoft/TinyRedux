// swift-tools-version: 6.2


import Foundation

/// MiddlewareContext
///
/// Bundles the action and pipeline callbacks for a middleware step.
@frozen
public struct MiddlewareContext<State, Action>: Sendable where State: ReduxState, Action: ReduxAction {
  public typealias Dispatch = @Sendable (UInt, Action...) -> Void
  public typealias Resolve = @Sendable (SendableError) -> Void
  public typealias Next = @Sendable (Action) throws -> Void
  public typealias TaskContext = @Sendable (State.ReadOnly) async throws -> Void
  public typealias TaskLauncher = @Sendable (@escaping TaskContext) -> Void

  /// The action being processed.
  public let action: Action

  /// Enqueues one or more actions for future dispatch.
  public let dispatch: Dispatch

  /// Sends an error to the resolver chain.
  public let resolve: Resolve

  /// Launches a controlled async operation with state access, dispatch, and error routing.
  public let task: TaskLauncher

  private let _next: @Sendable (Action) throws -> Void
  private let _guard: OnceGuard
  private let _complete: @Sendable (Result<Bool, Error>) -> Void
  private let _completeGuard: OnceGuard

  /// Creates a context. Internal — only the Store pipeline builds these.
  internal init(
    action: Action,
    dispatch: @escaping Dispatch,
    resolve: @escaping Resolve,
    task: @escaping TaskLauncher,
    complete: @escaping @Sendable (Result<Bool, Error>) -> Void,
    _next: @escaping Next
  ) {
    self.action = action
    self.dispatch = dispatch
    self.resolve = resolve
    self.task = task
    self._complete = complete
    self._completeGuard = OnceGuard()
    self._next = _next
    self._guard = OnceGuard()
  }

  /// Forwards the current action to the next middleware/reducer.
  /// Second call is a silent no-op.
  public func next() throws {
    guard _guard.tryConsume() else { return }
    try _next(action)
  }

  /// Forwards a different action to the next middleware/reducer.
  /// Second call is a silent no-op.
  public func next(_ action: Action) throws {
    guard _guard.tryConsume() else { return }
    try _next(action)
  }

  /// Marks the action as handled and emits timing logs when enabled.
  /// Second call is a silent no-op.
  public func complete(_ result: Result<Bool, Error> = .success(true)) {
    guard _completeGuard.tryConsume() else { return }
    _complete(result)
  }

  /// Destructured tuple: (dispatch, resolve, task, next, action).
  public var args: (Dispatch, Resolve, TaskLauncher, Next, Action) {
    (dispatch, resolve, task, next, action)
  }
}
