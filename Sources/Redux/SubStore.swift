//


import Combine
import Foundation
import SwiftUI


/// Type that stores the state of the app or module allowing feeding actions.
@dynamicMemberLookup public final class SubStore<S, A, LS, LA>: ObservableObject where S: Sendable, LS: Sendable, A: Equatable, LA: Equatable {

  @ObservedObject private var store: Store<S, A>

  private let toLocalState: WritableKeyPath<S, LS>
  private let toGlobalAction: (LA) -> A
  private var cancellable: AnyCancellable?
  
  public init(
    initialStore store: Store<S, A>,
    toLocalState: WritableKeyPath<S, LS>,
    toGlobalAction: @escaping (LA) -> A
  ) {
    self.store = store
    self.toLocalState = toLocalState
    self.toGlobalAction = toGlobalAction
    
    setPublisher()
  }
  
  /// A subscript providing access to the state of the store.
  public subscript<T>(dynamicMember keyPath: KeyPath<LS, T>) -> T {
    store.state[keyPath: toLocalState.appending(path: keyPath)]
  }
  
  public var state: LS {
    store.state[keyPath: toLocalState]
  }
  
  public func dispatch(_ actions: LA...) {
    dispatch(actions)
  }
  
  public func dispatch(_ actions: Array<LA>) {
    store.dispatch(
      actions.map { toGlobalAction($0) }
    )
  }
  
  public func dispatch(_ action: LA) {
    store.dispatch(toGlobalAction(action))
  }
  
  private func getState() -> LS {
    store.state[keyPath: toLocalState]
  }
  
  private func setPublisher() {
    cancellable = store.objectWillChange
      .sink { _ in
        self.objectWillChange.send()
      }
  }
}

extension SubStore {
  
  public func bind<T>(_ keyPath: WritableKeyPath<LS, T>) -> Binding<T> {
    store.bind(toLocalState.appending(path: keyPath))
  }
  
  public func reducedBind<T>(_ keyPath: KeyPath<LS, T>, _ action: @escaping (T) -> LA) -> Binding<T> {
    store.reducedBind(toLocalState.appending(path: keyPath)) { newValue in
      self.toGlobalAction(
        action(newValue)
      )
    }
  }
}
