//


import Foundation


/// ScopedStore
///
/// The ``SubStore`` adapter produced by ``Store/scoped(state:action:)``. It owns
/// NO state of its own: it holds the parent ``Store``, a `KeyPath` that projects
/// the state slice, and an `embed` closure that lifts a scoped intent into the
/// parent action space. Every member delegates straight back to the store.
///
/// A distinct `ScopedStore` value exists per scope, which is how a single store
/// can present several independent `SubStore` axes (a type can conform to a
/// protocol only once, but it can vend many adapters).
///
/// - `state`: reads the live state through `stateKeyPath` on the SAME instance
///   the store holds — a periscope, never a copy.
/// - `dispatch`: embeds the scoped action and forwards it to the store pipeline.
/// - `dispatch(_:snapshot:)`: pass-through to the store's snapshot entry point.
public struct ScopedStore<S: ReduxState, A: ReduxAction, SubState, SubAction>: SubStore {

  /// The parent store's state type (witnesses the `SubStore.ParentState`
  /// requirement; the snapshot constraint alone does not drive its inference).
  public typealias ParentState = S

  /// The parent store every member delegates to.
  let store: Store<S, A>

  /// Projects the parent state onto the scoped slice (periscope, zero copy).
  let stateKeyPath: KeyPath<S, SubState>

  /// Lifts a scoped intent into the parent action space.
  let embed: @Sendable (SubAction) -> A

  /// Creates a scope over `store`. Internal — use ``Store/scoped(state:action:)``.
  init(
    store: Store<S, A>,
    stateKeyPath: KeyPath<S, SubState>,
    embed: @escaping @Sendable (SubAction) -> A
  ) {
    self.store = store
    self.stateKeyPath = stateKeyPath
    self.embed = embed
  }

  /// The live state slice, projected from the store's instance via `stateKeyPath`.
  public var state: SubState {
    store._state[keyPath: stateKeyPath]
  }

  /// Embeds the scoped intent and dispatches it on the parent store.
  public func dispatch(_ action: SubAction) {
    store.dispatch(embed(action))
  }

  /// Embeds the scoped intent and forwards to the store's snapshot dispatch.
  public func dispatch<T: ReduxStateSnapshot<S>>(
    _ action: SubAction,
    snapshot: T.Type
  ) async -> ReduxEncodedSnapshot {
    await store.dispatch(embed(action), snapshot: snapshot)
  }
}

/// `ScopedStore` is safely `Sendable`: it is an immutable value whose stored
/// properties are a `Store` reference (a `@MainActor` class, implicitly
/// `Sendable`), an immutable `KeyPath`, and a `@Sendable` embedding closure.
/// `@unchecked` only because `KeyPath` lacks an unconditional `Sendable`
/// conformance in the stdlib.
extension ScopedStore: @unchecked Sendable {}
