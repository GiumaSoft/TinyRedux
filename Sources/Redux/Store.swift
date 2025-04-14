//


import Foundation
import Observation
import SwiftUI


/// Redux State
///
///
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
public final class Store<S, A>: @unchecked Sendable where S : ReduxS, A : ReduxA {

  var _state: S
  private var actions: [A]
  private var reducers: [Reducer<S, A>]
  private var middlewares: [Middleware<S, A>]
  private var isRunning: Bool

  public nonisolated init(
    initialState state: S,
    reducers: [Reducer<S, A>],
    middlewares: [Middleware<S, A>]
  ) {
    self._state = state
    self.actions = []
    self.reducers = reducers
    self.middlewares = middlewares
    self.isRunning = false
  }

  @MainActor
  private lazy var process: (A) throws -> Void = {
    self.middlewares.reduce(
      { action in
        try self.reduce(action)
      },
      { next, middleware in
        { action in
          try middleware.run(
            RunArguments<S, A>(self._state.readOnly, self.dispatch, next, action)
          )
        }
      }
    )
  }()

  public var state: S.ReadOnly {
    self._state.readOnly
  }

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

  private func reduce(_ action: A) throws {
    var newState = self._state
    for reducer in self.reducers {
      try reducer.reduce(&newState, action)
    }
    self._state = newState
  }
}


extension Store {
/// Bind
///
///
  public func bind<T>(_ keyPath: WritableKeyPath<S, T>) -> Binding<T> {
    Binding {
      self._state[keyPath: keyPath]
    } set: { newValue in
      self._state[keyPath: keyPath] = newValue
    }
  }
/// Bind
///
///
  public func bind<T>(_ keyPath: KeyPath<S, T>, queueLimit limit: Int = 0, _ action: @escaping (T) -> A) -> Binding<T> {
    Binding {
      self._state[keyPath: keyPath]
    } set: { newValue in
      self.dispatch(action(newValue), queueLimit: limit)
    }
  }
}
