//


import Combine
import Foundation
import SwiftUI

/// Type that stores the state of the app or module allowing feeding actions.
@dynamicMemberLookup public final class Store<S, A>: ObservableObject {
  
  @Published private(set) var state: S {
    didSet {
      statePublisher.value = state
    }
  }
  
  private nonisolated let statePublisher: CurrentValueSubject<S, Never>
  
  private let reducer: Reducer<S, A>
  private var middlewares: [AnyMiddleware<S, A>]
  
  public init(
    initialState state: S,
    reducer: Reducer<S, A>,
    middlewares: [AnyMiddleware<S, A>]
  ) {
    self.state = state
    self.reducer = reducer
    self.middlewares = middlewares
    self.statePublisher = CurrentValueSubject<S, Never>(state)
  }
  
  /// A subscript providing access to the state of the store.
  public subscript<T>(dynamicMember keyPath: KeyPath<S, T>) -> T {
    self.state[keyPath: keyPath]
  }
 
  public func dispatch(_ action: A) {
    let applyMiddleware = middlewares.reversed().reduce(
      { action in self.resolve(action) }
    ) { next, middleware in
      { action in middleware.run(RunArguments(self.getState, self.dispatch, next, action)) }
    }
    
    applyMiddleware(action)
  }
  
  private func resolve(_ action: A) {
    Task { @MainActor [weak self] in
      guard let self else { return }
      self.reducer.reduce(&self.state, action)
    }
  }
  
  private func getState() -> S {
    statePublisher.value
  }
}

extension Store {
  
  @MainActor
  public func bind<T>(_ keyPath: WritableKeyPath<S, T>) -> Binding<T> {
    Binding {
      self.state[keyPath: keyPath]
    } set: { newValue in
      self.state[keyPath: keyPath] = newValue
    }
  }
  
  @MainActor
  public func reducedBind<T>(_ keyPath: KeyPath<S, T>, _ action: @escaping (T) -> A) -> Binding<T> {
    Binding {
      self.state[keyPath: keyPath]
    } set: { [weak self] newValue in
      self?.dispatch(action(newValue))
    }
  }
}

