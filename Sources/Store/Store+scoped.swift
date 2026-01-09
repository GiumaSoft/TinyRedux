//


import Foundation


extension Store {

  /// Creates a ``ScopedStore`` that narrows this store onto a state slice and an
  /// action sub-vocabulary.
  ///
  /// The result is a ``SubStore`` that delegates back to this store: it copies
  /// no state and registers no observation of its own. Call it once per scope —
  /// the same store can vend several independent scopes (distinct axes).
  ///
  /// - Parameters:
  ///   - state: Key path projecting the parent state onto the scoped slice
  ///     (a periscope onto the live instance, not a copy).
  ///   - embed: Closure lifting a scoped intent into this store's action space.
  /// - Returns: A ``ScopedStore`` over `self`.
  @MainActor
  public func scoped<SubState, SubAction>(
    state: KeyPath<S, SubState>,
    action embed: @escaping @Sendable (SubAction) -> A
  ) -> ScopedStore<S, A, SubState, SubAction> {
    ScopedStore(store: self, stateKeyPath: state, embed: embed)
  }
}
