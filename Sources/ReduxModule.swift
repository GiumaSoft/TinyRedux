//


import SwiftUI


/// ReduxModule
///
/// Existential-friendly facade a feature's UI depends on: a read-only `state`
/// projection plus `nonisolated` `dispatch`, and a derived two-way `bind`. Both
/// ``ReduxStore`` (standalone) and ``ReduxStoreSlice`` (scoped) conform, so a View
/// can take `any ReduxModule<LS, LA>` without knowing whether it talks to the root
/// store or a slice — nor whether the mapping is `.linear` or `.scattered`.
@MainActor
public protocol ReduxModule<S, A>: Sendable
{
  associatedtype S: ReduxState
  associatedtype A: ReduxAction

  /// Read-only projection of the (local) state.
  var state: S.ReadOnly { get }

  /// Publishes one or more actions for asynchronous processing.
  nonisolated func dispatch(_ actions: A...)

  /// Two-way SwiftUI binding: reads via `state`, writes via `dispatch(embed(_:))`.
  func bind<Value>(_ keyPath: KeyPath<S.ReadOnly, Value>,
                   to embed: @escaping @Sendable (Value) -> A) -> Binding<Value>
}


public extension ReduxModule {
  /// Default `bind` derived from `state` + `dispatch` — free for every module.
  func bind<Value>(_ keyPath: KeyPath<S.ReadOnly, Value>,
                   to embed: @escaping @Sendable (Value) -> A) -> Binding<Value>
  {
    Binding(get: { self.state[keyPath: keyPath] },
            set: { self.dispatch(embed($0)) })
  }
}
