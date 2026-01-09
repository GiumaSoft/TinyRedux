//


import Foundation


/// ResolverContext
///
/// Bundles the error, originating action, read-only state, and dispatch capability for a resolver step.
@frozen @MainActor
public struct ResolverContext<S: ReduxState, A: ReduxAction> : Sendable {

  /// Read-only view of the current state.
  public let state: S.ReadOnly

  /// The action that triggered the error.
  public let action: A

  /// The error captured during middleware execution.
  public let error: SendableError

  /// Identifier of the middleware that originated the error.
  public let origin: ReduxOrigin

  /// Enqueues one or more actions for future dispatch.
  nonisolated
  public let dispatch: ReduxDispatch<A>

  /// Creates a context. Internal — only the Store pipeline builds these.
  init(
    state: S.ReadOnly,
    action: A,
    error: SendableError,
    origin: ReduxOrigin,
    dispatch: @escaping ReduxDispatch<A>
  ) {
    self.state = state
    self.action = action
    self.error = error
    self.origin = origin
    self.dispatch = dispatch
  }

  /// Destructured tuple: (state, dispatch, error, origin, action).
  public var args: ResolverArgs<S, A> {
    (state, dispatch, error, origin, action)
  }
}
