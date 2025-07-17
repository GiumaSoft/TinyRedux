//


import SwiftUI




/// SubStore
///
///
@MainActor
@Observable
@dynamicMemberLookup
public final class SubStore<LS, LA, GS, GA>: @unchecked Sendable where LS : ReduxS, GS : ReduxS, LA : ReduxA, GA : ReduxA {
  
  private let store: Store<GS, GA>
  @ObservationIgnored private let toLocalState: WritableKeyPath<GS, LS> & Sendable
  @ObservationIgnored private let toGlobalAction: @Sendable (LA) -> GA

  public init(
    initialStore store: Store<GS, GA>,
    toLocalState: WritableKeyPath<GS, LS> & Sendable,
    toGlobalAction: @escaping @Sendable (LA) -> GA
  ) {
    self.store = store
    self.toLocalState = toLocalState
    self.toGlobalAction = toGlobalAction
  }
  
  public subscript<Value>(dynamicMember keyPath: KeyPath<LS.ReadOnly, Value>) -> Value {
    state.readOnly[keyPath: keyPath]
  }
  
  var state: LS {
    get { store.state[keyPath: toLocalState] }
    set { store.state[keyPath: toLocalState] = newValue }
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
      self.state[keyPath: keyPath]
    } set: { newValue in
      self.state[keyPath: keyPath] = newValue
    }
  }
  /// Bind
  ///
  ///
  public func bind<T>(_ keyPath: KeyPath<LS.ReadOnly, T>, queueLimit limit: Int = 0, _ action: @escaping (T) -> LA) -> Binding<T> {
    Binding {
      self.state.readOnly[keyPath: keyPath]
    } set: { newValue in
      self.dispatch(action(newValue), queueLimit: limit)
    }
  }
}
