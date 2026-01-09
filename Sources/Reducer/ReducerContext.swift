//


import Foundation


/// ReducerContext
///
/// Bundles the mutable state and action for a reduction step.
@frozen @MainActor
public struct ReducerContext<S: ReduxState, A: ReduxAction> : Sendable {

  /// The mutable state to update.
  public let state: S

  /// The action being reduced.
  public let action: A

  /// Creates a context. Internal — only the Store pipeline builds these.
  init(_ state: S, _ action: A) {
    self.state = state
    self.action = action
  }

  /// Destructured pair of `(state, action)`.
  public var args: (S, A) {
    (state, action)
  }
}
