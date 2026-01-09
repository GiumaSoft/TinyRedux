// swift-tools-version: 6.2


import Foundation


/// ResolverContext
/// 
/// Bundles the error, originating action, read-only state, and pipeline callbacks for a resolver step.
@frozen
public struct ResolverContext<State, Action>: Sendable where State: ReduxState, Action: ReduxAction {
  public typealias Dispatch = @Sendable (UInt, Action...) -> Void
  public typealias Next = @Sendable (SendableError, Action) -> Void
  public typealias SendableError = any Error & Sendable

  /// Read-only view of the current state.
  public let state: State.ReadOnly

  /// The action that triggered the error.
  public let action: Action

  /// The error captured during middleware execution.
  public let error: SendableError

  /// Origin of the error within the middleware chain.
  public let origin: ReduxOrigin

  /// Enqueues one or more actions for future dispatch.
  public let dispatch: Dispatch

  private let _next: @Sendable (SendableError, Action) -> Void
  private let _guard: OnceGuard
  private let _complete: @Sendable (Bool) -> Void
  private let _completeGuard: OnceGuard

  /// Creates a context. Internal — only the Store pipeline builds these.
  internal init(
    state: State.ReadOnly,
    action: Action,
    error: SendableError,
    origin: ReduxOrigin,
    dispatch: @escaping Dispatch,
    complete: @escaping @Sendable (Bool) -> Void,
    _next: @escaping @Sendable (SendableError, Action) -> Void
  ) {
    self.state = state
    self.action = action
    self.error = error
    self.origin = origin
    self.dispatch = dispatch
    self._complete = complete
    self._completeGuard = OnceGuard()
    self._next = _next
    self._guard = OnceGuard()
  }

  /// Forwards the current error and action to the next resolver.
  /// Second call is a silent no-op.
  public func next() {
    guard _guard.tryConsume() else { return }
    _next(error, action)
  }

  /// Forwards a different error and action to the next resolver.
  /// Second call is a silent no-op.
  public func next(_ error: SendableError, _ action: Action) {
    guard _guard.tryConsume() else { return }
    _next(error, action)
  }

  /// Marks the error as handled and emits timing logs when enabled.
  /// Second call is a silent no-op.
  public func complete(_ succeeded: Bool = true) {
    guard _completeGuard.tryConsume() else { return }
    _complete(succeeded)
  }

  /// Destructured tuple (without next).
  public var args: (State.ReadOnly, Dispatch, Next, ReduxOrigin, SendableError, Action) {
    (state, dispatch, next, origin, error, action)
  }
}
