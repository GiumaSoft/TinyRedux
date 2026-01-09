//


import SwiftUI


/// SubStore
///
/// A scope-restricted view onto a ``Store``, narrowed on both axes: a state
/// slice (`SubState`) and an action sub-vocabulary (`SubAction`). It is the
/// generic primitive that lets a feature module declare ONLY its own two types
/// and consume `any SubStore<SubState, SubAction>`, without photocopying a
/// per-feature store protocol.
///
/// A concrete scope is produced by ``Store/scoped(state:action:)``, which
/// returns a ``ScopedStore`` — a zero-state adapter that DELEGATES every member
/// back to the parent store. Because a type can conform to a protocol only once,
/// the adapter (not the store itself) is what carries the per-scope associated
/// types: one store can vend many independent scopes (a UI axis and a BLE axis,
/// for example) as distinct `SubStore` values.
///
/// ## Design rules (carried from the historical caveat)
///
/// - **State axis — no duplication by construction.** `SubState` is a *periscope*
///   onto the live state via a `KeyPath`, never a materialized copy. The same
///   observable instances the store holds are projected through the scope, so
///   SwiftUI observation fires through `SubState` exactly as it does on the store.
/// - **Action axis — minimal intent vocabulary.** `SubAction` is the feature's
///   own intents and nothing more. Global intents a feature can trigger
///   (sign-out, purchase, …) are NOT re-modelled here: the app FORWARDS them in
///   one place when it builds the `embed` closure (e.g. `case .ui(.signOut):` →
///   the global `.signOut`). Case re-declaration is accepted; duplicating the
///   *handling* is not.
///
/// ## Snapshot path
///
/// ``dispatch(_:snapshot:)`` forwards to the parent store's snapshot entry point
/// unchanged, so the encoded slice is identical whether obtained through the
/// scope or directly. The snapshot type is a ``ReduxStateSnapshot`` of the
/// PARENT state (`ParentState`); that relationship is captured by a non-primary
/// associated type, which is why the method is callable on a concrete
/// ``ScopedStore`` (or a `ParentState`-constrained existential) but not on the
/// bare `any SubStore<SubState, SubAction>` existential.
@MainActor
public protocol SubStore<SubState, SubAction> {

  /// The projected state slice (a periscope onto the live store state).
  associatedtype SubState

  /// The feature's minimal action intent vocabulary.
  associatedtype SubAction

  /// The parent store's state type. Inferred from the snapshot requirement and
  /// kept out of the primary associated-type list so the common existential is
  /// `any SubStore<SubState, SubAction>`.
  associatedtype ParentState: ReduxState

  /// The current value of the scoped state slice.
  ///
  /// Returns the SAME instance(s) the store holds (no copy); reading observable
  /// properties through it registers SwiftUI observation against the live state.
  var state: SubState { get }

  /// Dispatches a scoped intent, embedded into the parent action space.
  ///
  /// - Parameter action: The feature intent; the scope embeds it into the
  ///   parent's action enum before it enters the store pipeline.
  func dispatch(_ action: SubAction)

  /// Dispatches a scoped intent and returns an encoded snapshot of the parent
  /// state after the pipeline completes.
  ///
  /// Forwards to ``Store/dispatch(_:snapshot:)`` unchanged after embedding the
  /// action, so the round-trip is identical to dispatching on the store directly.
  ///
  /// - Parameters:
  ///   - action: The feature intent to embed and dispatch.
  ///   - snapshot: The ``ReduxStateSnapshot`` conformer over the PARENT state.
  /// - Returns: `.success(Data)` with the JSON-encoded snapshot, or `.failure`.
  func dispatch<T: ReduxStateSnapshot<ParentState>>(
    _ action: SubAction,
    snapshot: T.Type
  ) async -> ReduxEncodedSnapshot
}


extension SubStore {

  /// Creates a SwiftUI `Binding` that reads a value out of the scoped slice and
  /// dispatches a mapped intent on write.
  ///
  /// - Parameters:
  ///   - get: Closure that extracts the bound value from ``state``.
  ///   - set: Closure that maps the new value to a ``SubAction``; return `nil`
  ///     to skip the dispatch (no intent for this value).
  /// - Returns: A `Binding<T>` suitable for SwiftUI controls.
  @MainActor
  public func bind<T>(
    _ get: @escaping (SubState) -> T,
    _ set: @escaping (T) -> SubAction?
  ) -> Binding<T> {
    Binding(
      get: { get(self.state) },
      set: { newValue in
        if let action = set(newValue) {
          self.dispatch(action)
        }
      }
    )
  }
}
