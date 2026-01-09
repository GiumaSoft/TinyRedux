//


import Foundation


public extension ReduxStore {
  /// Vends a scoped ``ReduxModule`` from a ``ReduxModuleMap`` (linear or scattered).
  /// Same mapping value used to lift the module's reducer → no duplication.
  @MainActor
  func slice<LS, LA>(_ mapping: ReduxModuleMap<LS, LA, S, A>) -> ReduxStoreSlice<LS, LA>
  {
    slice(state: mapping.toState, action: mapping.toRootAction)
  }

  /// Vends a scoped module from an explicit `(S) -> LS` projection + `toRootAction`.
  ///
  /// The local state is projected ONCE and retained by the slice: a mapped state's
  /// `ReadOnly` references it `unowned`, so a per-read rebuild would dangle. Reads
  /// still observe the live root, since the projection forwards to the root leaves
  /// (linear: the live sub-object; scattered: the `ReduxBinding` targets).
  @MainActor
  func slice<LS, LA>(state toState: @MainActor @Sendable (S) -> LS,
                     action toRootAction: @escaping @Sendable (LA) -> A) -> ReduxStoreSlice<LS, LA>
  {
    let local = toState(_state)
    return ReduxStoreSlice(
      read: { local.readOnly },
      send: { la in self.dispatch(toRootAction(la)) })
  }

  /// `.linear` convenience: a key path to a contiguous sub-object.
  @MainActor
  func slice<LS, LA>(state keyPath: KeyPath<S, LS>,
                     action toRootAction: @escaping @Sendable (LA) -> A) -> ReduxStoreSlice<LS, LA>
  {
    slice(state: { $0[keyPath: keyPath] }, action: toRootAction)
  }
}
