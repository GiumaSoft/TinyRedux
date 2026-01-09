// ResolverContext.swift
// TinyRedux

import Foundation

/// ResolverContext
///
/// Bundles the error, originating action, read-only state, and pipeline callbacks for a resolver step.
@frozen
public struct ResolverContext<S: ReduxState, A: ReduxAction> {
  
  /// Read-only view of the current state.
  public let state: S.ReadOnly
  
  /// The action that triggered the error.
  public let action: A
  
  /// The error captured during middleware execution.
  public let error: any Error
  
  /// Identifier of the middleware that originated the error.
  public let origin: String
  
  /// Enqueues one or more actions for future dispatch.
  public let dispatch: @Sendable (UInt, A...) -> Void
  
  private let _next: @MainActor (any Error, A) -> Void
  private let _guard: OnceGuard
  private let _complete: @Sendable (Bool) -> Void
  private let _completeGuard: OnceGuard
  
  /// Creates a context. Internal — only the Store pipeline builds these.
  init(
    state: S.ReadOnly,
    action: A,
    error: any Error,
    origin: String,
    dispatch: @escaping @Sendable (UInt, A...) -> Void,
    complete: @escaping @Sendable (Bool) -> Void,
    _next: @escaping @MainActor (any Error, A) -> Void
  ) {
    self.state = state
    self.action = action
    self.error = error
    self.origin = origin
    self.dispatch = dispatch
    self._complete = complete
    self._next = _next
    self._guard = OnceGuard()
    self._completeGuard = OnceGuard()
  }
  
  /// Forwards the current error and action to the next resolver.
  /// Second call is a silent no-op.
  @MainActor
  public func next() {
    guard _guard.tryConsume() else { return }
    _next(error, action)
  }
  
  /// Forwards a different error and action to the next resolver.
  /// Second call is a silent no-op.
  @MainActor
  public func next(_ error: any Error, _ action: A) {
    guard _guard.tryConsume() else { return }
    _next(error, action)
  }
  
  /// Marks the error as handled and emits timing logs when enabled.
  /// Second call is a silent no-op.
  public func complete(_ succeeded: Bool = true) {
    guard _completeGuard.tryConsume() else { return }
    _complete(succeeded)
  }
  
  /// Destructured tuple: (state, dispatch, next, origin, error, action).
  public var args: (S.ReadOnly, @Sendable (UInt, A...) -> Void, @MainActor (any Error, A) -> Void, String, any Error, A) {
    (state, dispatch, _next, origin, error, action)
  }
}
