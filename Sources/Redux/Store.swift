//


import Foundation
import Observation
import SwiftUI


/// Redux State
///
///
@MainActor
public protocol ReduxS: Observable, Sendable {
  associatedtype ReadOnly: Sendable
  
  var readOnly: ReadOnly { get }
}
/// Redux Action
///
///
public protocol ReduxA: Identifiable, Equatable, Hashable, CustomStringConvertible, Sendable { }
/// Store
///
///
@MainActor
@Observable
@dynamicMemberLookup
public final class Store<S, A>: @unchecked Sendable where S : ReduxS, A : ReduxA {

  var state: S
  @ObservationIgnored private var actions: [A]
  @ObservationIgnored private var reducers: [Reducer<S, A>]
  @ObservationIgnored private var middlewares: [Middleware<S, A>]
  @ObservationIgnored private var isRunning: Bool

  public init(
    initialState state: S,
    reducers: [Reducer<S, A>],
    middlewares: [Middleware<S, A>]
  ) {
    self.state = state
    self.actions = []
    self.reducers = reducers
    self.middlewares = middlewares
    self.isRunning = false
  }
  
  public subscript<Value>(dynamicMember keyPath: KeyPath<S.ReadOnly, Value>) -> Value {
    self.state.readOnly[keyPath: keyPath]
  }
  
  @ObservationIgnored private lazy var process: (A) throws -> Void = {
    self.middlewares.reduce(
      { action in
        try self.reduce(action)
      },
      { next, middleware in
        { action in
          try middleware.run(
            RunArguments<S, A>(self.state.readOnly, self.dispatch, next, action)
          )
        }
      }
    )
  }()
  
  public func dispatch(_ actions: A...) {
    self.actions.append(contentsOf: actions.reversed())
    if !isRunning { run() }
  }

  public func dispatch(_ actions: [A]) {
    self.actions.append(contentsOf: actions.reversed())
    if !isRunning { run() }
  }
  
  public func dispatch(_ action: A) {
    self.actions.append(action)
    if !isRunning { run() }
  }

  public func dispatch(_ action: A, queueLimit limit: Int) {
    if limit == 0 || limit > NSCountedSet(array: actions).count(for: action) {
      self.actions.append(action)
      if !isRunning { run() }
    }
  }

  private func run() {
    if isRunning { return } else { isRunning = true }

    print("Dispatcher run is starting.")
    
    Task { @MainActor in
      defer {
        print("Dispatcher run is terminated.")
        isRunning = false
      }

      while let action = self.actions.first {
        print("ℹ️ [[ Store ]]: \(actions.count) actions in queue: [\(actions.map { $0.description }.joined(separator: ", "))]")
        self.actions.removeFirst()

        do {
          try process(action)
        } catch {
          print(error)
        }
      }
    }
  }

  private func reduce(_ action: A) throws {
    var newState = self.state
    for reducer in self.reducers {
      try reducer.reduce(&newState, action)
    }
    self.state = newState
  }
}


extension Store {
/// Bind
///
///
  public func bind<T>(_ keyPath: WritableKeyPath<S, T>) -> Binding<T> {
    Binding {
      self.state[keyPath: keyPath]
    } set: { newValue in
      self.state[keyPath: keyPath] = newValue
    }
  }
/// Bind
///
///
  public func bind<T>(_ keyPath: KeyPath<S, T>, queueLimit limit: Int = 0, _ action: @escaping (T) -> A) -> Binding<T> {
    Binding {
      self.state[keyPath: keyPath]
    } set: { newValue in
      self.dispatch(action(newValue), queueLimit: limit)
    }
  }
}
