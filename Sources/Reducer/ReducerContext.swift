// swift-tools-version: 6.2


import Foundation

/// ReducerContext
/// 
/// Bundles the mutable state and action for a reduction step.
@frozen
public struct ReducerContext<State, Action>: Sendable where State : ReduxState, Action : ReduxAction {
  /// The mutable state to update.
  public let state: State

  /// The action being reduced.
  public let action: Action

  private let _complete: @Sendable (Bool) -> Void
  private let _completeGuard: OnceGuard

  /// Creates a context. Internal — only the Store pipeline builds these.
  internal init(
    state: State,
    action: Action,
    complete: @escaping @Sendable (Bool) -> Void
  ) {
    self.state = state
    self.action = action
    self._complete = complete
    self._completeGuard = OnceGuard()
  }

  /// Marks the reduction as handled and emits timing logs when enabled.
  /// Second call is a silent no-op.
  public func complete(_ succeeded: Bool = true) {
    guard _completeGuard.tryConsume() else { return }
    _complete(succeeded)
  }

  /// Destructured pair of `(state, action)`.
  public var args: (State, Action) {
    (state, action)
  }
}
