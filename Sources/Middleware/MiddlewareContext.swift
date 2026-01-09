//


import Foundation


/// MiddlewareContext
///
/// Bundles the read-only state, action, and dispatch capability for a middleware step.
@frozen @MainActor
public struct MiddlewareContext<S: ReduxState, A: ReduxAction> : Sendable {

  /// Read-only view of the current state.
  public let state: S.ReadOnly

  /// Enqueues one or more actions for future dispatch.
  nonisolated
  public let dispatch: ReduxDispatch<A>

  /// The action being processed.
  public let action: A

  /// Creates a context. Internal — only the Store pipeline builds these.
  init(
    state: S.ReadOnly,
    dispatch: @escaping ReduxDispatch<A>,
    action: A
  ) {
    self.state = state
    self.dispatch = dispatch
    self.action = action
  }

  /// Destructured tuple: (state, dispatch, action).
  public var args: MiddlewareArgs<S, A> {
    (state, dispatch, action)
  }
}
