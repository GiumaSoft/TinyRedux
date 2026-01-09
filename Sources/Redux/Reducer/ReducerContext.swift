// swift-tools-version: 6.0


import Foundation


/// Context passed to a reducer invocation. It exposes mutable state, the current action, and a
/// completion hook used for logging. The context is sendable and main-actor safe, so reducers can
/// work deterministically with UI-bound state. Use the state reference to apply in-place mutations
/// appropriate for the action, and call complete when you want timing logs to record the reducer
/// execution. The args helper provides convenient destructuring for terse reducer bodies. Reducers
/// are synchronous by design and should keep work small, delegating side effects to middleware for
/// predictable updates and testing purposes.
@frozen
public struct ReducerContext<S, A>: Sendable where S : ReduxState, A : ReduxAction {
  /// Mutable state to update for the action.
  public let state: S
  /// The action currently being reduced.
  public let action: A
  /// Marks the current action as handled for logging and timing. Marks the action as handled and
  /// emits timing logs when enabled. Call it explicitly (it is not invoked automatically) so you
  /// can skip logging for default/unhandled actions. `complete` runs on `@MainActor`; hop back if
  /// you're in a background task.
  ///
  ///     Task {
  ///       await MainActor.run { context.complete() }
  ///     }
  ///
  private let onComplete: @MainActor @Sendable (Bool) -> Void
  ///
  public typealias Args = (S, A)
  /// Returns a tuple of `(state, action)` for quick destructuring.
  public var args: Args {
    (state, action)
  }

  /// Marks the current action as handled for logging and timing. Pass `false` to record an
  /// explicit unhandled completion in logs. Default is `true`.
  @MainActor
  public func complete(_ succeded: Bool = true) {
    onComplete(succeded)
  }

  init(
    state: S,
    action: A,
    complete: @escaping @MainActor @Sendable (Bool) -> Void
  ) {
    self.state = state
    self.action = action
    self.onComplete = complete
  }
}
