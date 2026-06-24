//


import Foundation


/// ReduxReducerContext
///
/// Bundles the mutable state and action for a reduction step.
public struct ReduxReducerContext<S, A> : Sendable
where S: ReduxState, A: ReduxAction
{
  /// The mutable state to update.
  public let state: S

  /// The action being reduced.
  public let action: A

  /// Creates a context. Internal — only the ``Worker`` builds these.
  init(_ state: S, _ action: A)
  {
    self.state = state
    self.action = action
  }

  /// Destructured members: `(state, action)`.
  public var args: ReduxReducerArgs<S, A>
  {
    (state, action)
  }
}
