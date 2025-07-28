//


import Foundation
import Observation
import SwiftUI


/// Redux State
///
///
@MainActor
public protocol ReduxState: Observable, Sendable {
  /// Define protocol that conform to a read-only accessible state.
  associatedtype ReadOnly: Sendable
  /// Property that make state accessible in read-only mode.
  var readOnly: ReadOnly { get }
}


/// Redux Action
///
///
public protocol ReduxAction: CustomStringConvertible,
                             Equatable,
                             Identifiable,
                             Hashable,
                             Sendable {
  /// Action unique identifier.
  var id: Int { get }
}


/// Store
///
///
@MainActor
@Observable
@dynamicMemberLookup
public final class Store<S, A> where S : ReduxState, A : ReduxAction {
  ///
  var state: S
  ///
  @ObservationIgnored private let reducers: [Reducer<S, A>]
  @ObservationIgnored private let middlewares: [Middleware<S, A>]
  @ObservationIgnored private var actions: [A]
  @ObservationIgnored private var isRunning: Bool
  @ObservationIgnored private var processCache: ((A) throws -> Void)?
  
  public init(
    initialState state: S,
    middlewares: [Middleware<S, A>],
    reducers: [Reducer<S, A>]
  ) {
    self.state = state
    self.middlewares = middlewares
    self.reducers = reducers
    self.actions = []
    self.isRunning = false
  }
  
  /// Subscript make state accessible using read-only keypath.
  public subscript<Value>(dynamicMember keyPath: KeyPath<S.ReadOnly, Value>) -> Value {
    self.state.readOnly[keyPath: keyPath]
  }
  
  @ObservationIgnored private var process: (A) throws -> Void {
    /// Return cached process or compute a new one if cache not exists.
    if let processCache { return processCache }
    
    processCache = self.middlewares.reduce(
      { [unowned self] action in
        try self.reduce(action)
      },
      { next, middleware in
        { [unowned self] action in
          
          try middleware.run(
            MiddlewareContext(
              state: self.state.readOnly,
              dispatch: self.dispatch,
              next: next,
              action: action
            )
          )
        }
      }
    )
    
    return processCache!
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
    
    print("Dispatcher is running.")
    
    Task { @MainActor in
      defer {
        print("Dispatcher execution terminated.")
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

