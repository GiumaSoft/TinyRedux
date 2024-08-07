//


import Combine
import Foundation
import SwiftUI

/// Type that stores the state of the app or module allowing feeding actions.
@dynamicMemberLookup public final class Store<S, A>: ObservableObject where A: Equatable {
  
  @Published private(set) var state: S {
    didSet {
      statePublisher.value = state
    }
  }
  
  private nonisolated let statePublisher: CurrentValueSubject<S, Never>
  
  private let reducer: Reducer<S, A>
  private var actions: Array<A> = []
  private var isProcessing: Bool = false
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
    self.actions.append(action)
    if !isProcessing {
      serialDispatcher()
    }
  }
  
  public func dispatch(_ actions: A...) {
    self.dispatch(Array(actions))
  }
  
  public func dispatch(_ actions: Array<A>) {
    self.actions.append(contentsOf: actions)
    if !isProcessing {
      serialDispatcher()
    }
  }
  
  private func serialDispatcher() {
    isProcessing = true
    let action = actions.removeFirst()
    applyMiddlewares(action) {
      self.reduce($0)
      
      if self.actions.isEmpty {
        self.isProcessing = false
      } else {
        self.serialDispatcher()
      }
    }
  }
  
  private func applyMiddlewares(_ action: A, reduce: @escaping (A) -> Void) {
    let resolveMiddlewares = middlewares.reversed().reduce(
      { action in reduce(action) }
    ) { next, middleware in
      { action in middleware.run(RunArguments(self.getState, self.dispatch, next, action)) }
    }
    resolveMiddlewares(action)
  }
  
  private func reduce(_ action: A) {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      reducer.reduce(&state, action)
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

