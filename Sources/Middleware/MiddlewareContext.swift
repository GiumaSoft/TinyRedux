// MiddlewareContext.swift
// TinyRedux

import Foundation

/// MiddlewareContext
///
/// Bundles the action and pipeline callbacks for a middleware step.
@frozen
public struct MiddlewareContext<S: ReduxState, A: ReduxAction> : Sendable {
  public typealias TaskBody = @Sendable (S.ReadOnly) async throws -> Void
  public typealias TaskLauncher = @Sendable (@escaping TaskBody) -> Void

  /// The action being processed.
  public let action: A

  /// Enqueues one or more actions for future dispatch.
  public let dispatch: @Sendable (UInt, A...) -> Void

  /// Sends an error to the resolver chain.
  public let resolve: @MainActor (any Error) -> Void

  /// Launches a controlled async operation with state access, dispatch, and error routing.
  public let task: TaskLauncher
  
  private let _next: @MainActor (A) throws -> Void
  private let _guard: OnceGuard
  private let _complete: @Sendable (Result<Bool, any Error>) -> Void
  private let _completeGuard: OnceGuard
  
  /// Creates a context. Internal — only the Store pipeline builds these.
  init(
    action: A,
    dispatch: @escaping @Sendable (UInt, A...) -> Void,
    resolve: @escaping @MainActor (any Error) -> Void,
    task: @escaping TaskLauncher,
    complete: @escaping @Sendable (Result<Bool, any Error>) -> Void,
    _next: @escaping @MainActor (A) throws -> Void
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
  public func next(_ action: A) throws {
    guard _guard.tryConsume() else { return }
    try _next(action)
  }
  
  /// Marks the action as handled and emits timing logs when enabled.
  /// Second call is a silent no-op.
  @Sendable
  public func complete(_ result: Result<Bool, any Error> = .success(true)) {
    guard _completeGuard.tryConsume() else { return }
    _complete(result)
  }
  
  /// Destructured tuple: (dispatch, resolve, task, next, action).
  public var args: (
    @Sendable (UInt, A...) -> Void,
    @MainActor (any Error) -> Void,
    TaskLauncher,
    @MainActor (A) throws -> Void,
    A
  ) {
    (dispatch, resolve, task, _next, action)
  }
}
