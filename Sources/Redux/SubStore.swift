//


import Foundation
import SwiftUI


/// SubStore
///
///
@MainActor
@dynamicMemberLookup
public final class SubStore<LS, LA, GS, GA> where LS : ReduxState, GS : ReduxState, LA : ReduxAction, GA : ReduxAction {
  
  private let store: Store<GS, GA>
  private let toLocalState: WritableKeyPath<GS, LS> & Sendable
  private let toGlobalAction: @Sendable (LA) -> GA
  
  public nonisolated init(
    initialStore store: Store<GS, GA>,
    toLocalState: WritableKeyPath<GS, LS> & Sendable,
    toGlobalAction: @Sendable @escaping (LA) -> GA
  ) {
    self.store = store
    self.toLocalState = toLocalState
    self.toGlobalAction = toGlobalAction
  }
  
  
  public subscript<T>(dynamicMember keyPath: KeyPath<LS.ReadOnly, T>) -> T {
    self.state.readOnly[keyPath: keyPath]
  }
  
  var state: LS {
    get { self.store.state[keyPath: toLocalState] }
    set { self.store.state[keyPath: toLocalState] = newValue }
  }
  
  @Sendable
  public nonisolated func dispatch(_ actions: LA...) {
    let ga = actions.map { toGlobalAction($0) }
    self.store.dispatch(ga)
  }
  
  @Sendable
  public nonisolated func dispatch(_ actions: [LA]) {
    let ga = actions.map { toGlobalAction($0) }
    self.store.dispatch(ga)
  }
  
  @Sendable
  public nonisolated func dispatch(_ action: LA) {
    self.store.dispatch(toGlobalAction(action))
  }
}


extension SubStore {
  /// Bind
  ///
  ///
  @MainActor
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
  @MainActor
  public func bind<T>(_ keyPath: KeyPath<LS, T>, _ action: @escaping (T) -> LA) -> Binding<T> {
    Binding {
      self.state[keyPath: keyPath]
    } set: { newValue in
      self.dispatch(action(newValue))
    }
  }
}
