//


import Combine
import Foundation
import SwiftUI


final class Dispatcher<A> where A: Equatable {
  private let queue = DispatchQueue(label: "com.dispatcher.queue")
  private var actions: [A]
  private var isRunning: Bool = false
  
  init(actions: [A]) {
    self.actions = actions
  }
  
  func dispatch(_ action: A, completion: @escaping (A) -> Void) {
    queue.sync { actions.insert(action, at: 0) }
    run(completion: completion)
  }
  
  private func run(completion: (A) -> Void) {
    guard !isRunning else { return }
    defer { isRunning = false }

    isRunning = true
    while !actions.isEmpty {
      var action: A?
      
      queue.sync { action = actions.popLast() }
      if let action {
        completion(action)
      }
    }
  }
}

extension Dispatcher {
  func dispatch(_ actions: [A], completion: @escaping (A) -> Void) {
    queue.sync { self.actions.insert(contentsOf: actions, at: 0) }
    run(completion: completion)
  }
}


/// Type that stores the state of the app or module allowing feeding actions.
@Observable @dynamicMemberLookup public final class Store<S, A> where S: Sendable, A: Equatable {
  private(set) var state: S
  
  @ObservationIgnored private let reducers: [Reducer<S, A>]
  @ObservationIgnored private let middlewares: [Middleware<S, A>]
  @ObservationIgnored private let dispatcher: Dispatcher<A>
  @ObservationIgnored private let queue = DispatchQueue(label: "com.store.queue")
  
  @ObservationIgnored private lazy var run: (A) -> Void = {
    self.middlewares.reversed().reduce(
        { action in self.reduce(action) },
        { next, middleware in
          { action in
            middleware.run(
              RunArguments(self.getState, self.dispatch, next, action)
            )
          }
        }
      )
  }()
  
  public init(
    initialState state: S,
    reducers: [Reducer<S, A>],
    middlewares: [Middleware<S, A>] = []
  ) {
    self.state = state
    self.reducers = reducers
    self.middlewares = middlewares
    self.dispatcher = Dispatcher(actions: [])
  }
  
  public subscript<T>(dynamicMember keyPath: KeyPath<S, T>) -> T {
    state[keyPath: keyPath]
  }
  
  public func dispatch(_ action: A) {
    dispatcher.dispatch(action) { action in
      self.run(action)
    }
  }
  
  private func getState() -> S {
    queue.sync { self.state }
  }
  
  private func reduce(_ action: A) {
    queue.sync {
      var newState = self.state
      for reducer in reducers {
        reducer.reduce(&newState, action)
      }
      
      DispatchQueue.main.async { [weak self] in
        self?.state = newState
      }
    }
  }
}

extension Store {
  func dispatch(_ actions: A...) {
    dispatcher.dispatch(actions) { action in
      self.run(action)
    }
  }
}

extension Store where S: Sendable, A: Equatable {
  public func bind<T>(_ keyPath: KeyPath<S, T>, _ action: @escaping (T) -> A) -> Binding<T> {
    Binding {
      self.state[keyPath: keyPath]
    } set: { newValue in
      self.dispatch(action(newValue))
    }
  }
}


