//


import Foundation


/// ReduxModuleMap
///
/// Single composition-time descriptor that plugs a module's local `LS`/`LA` into a
/// central store's `S`/`A`. It bundles the three functions the whole module needs —
/// and BOTH the reducer lift and the store slice derive from the same value, so the
/// projection/embed are written once:
/// - ``toState``: projects the global state onto the local state (read + reduce).
///   A key path for `.linear`; a `ReduxBinding` builder for `.scattered`.
/// - ``toAction``: extracts the local action from a global one (`nil` = not mine).
/// - ``toRootAction``: lifts a local action into the global space (the dispatch path).
public struct ReduxModuleMap<LS, LA, S, A>: Sendable
where LS: ReduxState, LA: ReduxAction, S: ReduxState, A: ReduxAction
{
  /// Global state → live local state.
  let toState: @MainActor @Sendable (S) -> LS

  /// Global action → local action (`nil` skips this module).
  let toAction: @Sendable (A) -> LA?

  /// Local action → global (root) action (the module's dispatch path).
  let toRootAction: @Sendable (LA) -> A

  init(toState: @escaping @MainActor @Sendable (S) -> LS,
       toAction: @escaping @Sendable (A) -> LA?,
       toRootAction: @escaping @Sendable (LA) -> A)
  {
    self.toState = toState
    self.toAction = toAction
    self.toRootAction = toRootAction
  }
}


public extension ReduxModuleMap {
  /// Linear mapping: `LS` is a contiguous sub-object of `S` and `LA` a single case
  /// of `A`.
  @MainActor
  static func linear(state stateKeyPath: KeyPath<S, LS>,
                     action actionKeyPath: KeyPath<A, LA?> & Sendable,
                     toRootAction: @escaping @Sendable (LA) -> A) -> Self
  {
    Self(toState: { $0[keyPath: stateKeyPath] },
         toAction: { $0[keyPath: actionKeyPath] },
         toRootAction: toRootAction)
  }

  /// Scattered mapping: `LS` is a mapped state projected field-by-field onto split
  /// sub-states of `S` (the `state` closure builds it from per-field `ReduxBinding`s).
  @MainActor
  static func scattered(state toState: @escaping @MainActor @Sendable (S) -> LS,
                        action actionKeyPath: KeyPath<A, LA?> & Sendable,
                        toRootAction: @escaping @Sendable (LA) -> A) -> Self
  {
    Self(toState: toState,
         toAction: { $0[keyPath: actionKeyPath] },
         toRootAction: toRootAction)
  }
}
