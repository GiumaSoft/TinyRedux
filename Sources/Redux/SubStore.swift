//


import SwiftUI




/// SubStore
///
///
@MainActor
public final class SubStore<LS, LA, GS, GA>: @unchecked Sendable where LS : ReduxS, GS : ReduxS, LA : ReduxA, GA : ReduxA {
  
  private let store: Store<GS, GA>
  private let toLocalState: WritableKeyPath<GS, LS> & Sendable
  private let toGlobalAction: @Sendable (LA) -> GA
  
  public nonisolated init(
    initialStore store: Store<GS, GA>,
    toLocalState: WritableKeyPath<GS, LS> & Sendable,
    toGlobalAction: @escaping @Sendable (LA) -> GA
  ) {
    self.store = store
    self.toLocalState = toLocalState
    self.toGlobalAction = toGlobalAction
  }
  
  private var _state: LS {
    get { store._state[keyPath: toLocalState] }
    set { store._state[keyPath: toLocalState] = newValue }
  }
  
  public var state: LS.ReadOnly {
    self.store._state[keyPath: toLocalState].readOnly
  }
  
  public func dispatch(_ actions: LA...) {
    let ga = actions.map { toGlobalAction($0) }
    self.store.dispatch(ga)
  }
  
  public func dispatch(_ actions: [LA]) {
    let ga = actions.map { toGlobalAction($0) }
    self.store.dispatch(ga)
  }
  
  public func dispatch(_ action: LA) {
    self.store.dispatch(toGlobalAction(action))
  }
  
  public func dispatch(_ action: LA, queueLimit limit: Int) {
    self.store.dispatch(toGlobalAction(action), queueLimit: limit)
  }
}


extension SubStore {
  /// Bind
  ///
  ///
  public func bind<T>(_ keyPath: WritableKeyPath<LS, T>) -> Binding<T> {
    Binding {
      self._state[keyPath: keyPath]
    } set: { newValue in
      self._state[keyPath: keyPath] = newValue
    }
  }
  /// Bind
  ///
  ///
  public func bind<T>(_ keyPath: KeyPath<LS, T>, queueLimit limit: Int = 0, _ action: @escaping (T) -> LA) -> Binding<T> {
    Binding {
      self._state[keyPath: keyPath]
    } set: { newValue in
      self.dispatch(action(newValue), queueLimit: limit)
    }
  }
}
