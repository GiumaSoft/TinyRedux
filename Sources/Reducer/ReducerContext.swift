// ReducerContext.swift
// TinyRedux

import Foundation

/// ReducerContext
///
/// Bundles the mutable state and action for a reduction step.
@MainActor
@frozen
public struct ReducerContext<S: ReduxState, A: ReduxAction> {

  /// The mutable state to update.
  public let state: S

  /// The action being reduced.
  public let action: A

  private let _complete: (Bool) -> Void
  private let _completeGuard: OnceGuard

  /// Creates a context. Internal — only the Store pipeline builds these.
  init(state: S, action: A, complete: @escaping (Bool) -> Void) {
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
  public var args: (S, A) {
    (state, action)
  }
}
