// swift-tools-version: 6.0


import Foundation


/// Context passed to a resolver invocation. It exposes the read-only state projection, the action
/// that triggered the error, the error itself, and an origin describing where the failure occurred.
/// Use the dispatch function to enqueue new actions as remediation, and call next to continue to
/// the next resolver or eventually to reducers. If next is not called, the current action will not
/// reach reducers. The context includes a complete hook for timing logs. Use args for quick
/// destructuring when writing small resolver functions. This keeps remediation logic explicit and
/// testable.
public struct ResolverContext<S, A>: Sendable where S : ReduxState, A : ReduxAction {
  /// Read-only view of the current state.
  public let state: S.ReadOnly
  /// Enqueues one or more actions.
  public let dispatch: @MainActor @Sendable (UInt, A...) -> Void
  /// The error captured during middleware execution.
  public let error: any Error
  /// The action currently being processed.
  public let action: A
  /// Origin of the error.
  public let origin: ReduxErrorOrigin
  /// Forwards the error and action to the next resolver in the chain. Invokes the next resolver in
  /// the chain. If you do not call `next`, the reducer will not run for the current action. You may
  /// also call `next` later (for example after async remediation).
  public let next: @MainActor @Sendable (any Error, A) -> Void
  /// Marks the current action as handled for logging and timing. Marks the action as handled and
  /// emits timing logs when enabled. Call it explicitly (it is not invoked automatically) so you
  /// can skip logging for default/unhandled actions. `complete` runs on `@MainActor`; hop back if
  /// you're in a background task.
  private let onComplete: @MainActor @Sendable (Bool) -> Void
  ///
  public typealias Args = (S.ReadOnly, @MainActor @Sendable (UInt, A...) -> Void, any Error, A, ReduxErrorOrigin, @MainActor @Sendable (any Error, A) -> Void)
  /// Tuple of common context fields for quick destructuring. Returns a tuple of the most-used
  /// fields for quick destructuring. Order: `(state, dispatch, error, action, origin, next)`.
  public var args: Args {
    (state, dispatch, error, action, origin, next)
  }
  /// Marks the current action as handled for logging and timing. Pass `false` to record an
  /// explicit unhandled completion in logs. Default is `true`.
  @MainActor
  public func complete(_ succeded: Bool = true) {
    onComplete(succeded)
  }

  init(
    state: S.ReadOnly,
    dispatch: @escaping @MainActor @Sendable (UInt, A...) -> Void,
    error: any Error,
    action: A,
    origin: ReduxErrorOrigin,
    next: @escaping @MainActor @Sendable (any Error, A) -> Void,
    complete: @escaping @MainActor @Sendable (Bool) -> Void
  ) {
    self.state = state
    self.dispatch = dispatch
    self.error = error
    self.action = action
    self.origin = origin
    self.next = next
    self.onComplete = complete
  }
}
