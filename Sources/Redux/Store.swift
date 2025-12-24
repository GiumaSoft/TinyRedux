

import Collections
import Foundation
import Observation
import SwiftUI


@MainActor
/// A read-only projection of a mutable `ReduxState`.
public protocol ReadOnlyState: AnyObject, Sendable {
  /// The state type wrapped by this projection.
  associatedtype State: ReduxState
  /// Creates a read-only view for the given state instance.
  init(_ state: State)
}

/// ReduxState
///
///
@MainActor
/// A mutable state object observed by the UI.
/// Conformers must provide a read-only projection via `readOnly`.
public protocol ReduxState: AnyObject, Observable, Sendable {
  /// The read-only projection type for this state.
  associatedtype ReadOnly: ReadOnlyState where ReadOnly.State == Self
  /// A read-only view of the current state.
  var readOnly: ReadOnly { get }
}

/// ReduxAction
///
///
public protocol ReduxAction: CustomDebugStringConvertible,
                             CustomStringConvertible,
                             Equatable,
                             Identifiable,
                             Hashable,
                             Sendable {
  /// A stable identifier for the action.
  var id: Int { get }
}


/// A main-actor store that queues actions and applies middleware and reducers sequentially.
@MainActor
@dynamicMemberLookup
public final class Store<S: ReduxState, A: ReduxAction> {
  internal var state: S
  
  private let middlewares: [Middleware<S, A>]
  private let reducers: [Reducer<S, A>]
  private let onException: ((any Error) -> Void)?
  private let onLog: ((String) -> Void)?
  private var actionBuffer: Deque<A>
  private var bufferedActionCount: [A: UInt]
  private var isDispatcherRunning: Bool
  
  private lazy var dispatchProcess: @MainActor (A) throws -> Void = buildDispatchProcess()
  
  /// Creates a store with the given state, middleware chain, and reducers.
  /// - Parameters:
  ///   - initialState: The initial mutable state instance.
  ///   - middlewares: Middleware applied in the provided order.
  ///   - reducers: Reducers applied in the provided order.
  ///   - onLog: Optional hook called after each reducer with timing info.
  public init(
    initialState: S,
    middlewares: [Middleware<S, A>],
    reducers: [Reducer<S, A>],
    onException: ((any Error) -> Void)? = nil,
    onLog: ((String) -> Void)? = nil
  ) {
    self.state = initialState
    self.middlewares = middlewares.reversed()
    self.reducers = reducers
    self.onException = onException
    self.onLog = onLog
    self.actionBuffer = Deque()
    self.bufferedActionCount = [:]
    self.isDispatcherRunning = false
  }
  
  public subscript<Value>(dynamicMember keyPath: KeyPath<S.ReadOnly, Value>) -> Value {
    state.readOnly[keyPath: keyPath]
  }
  
  /// Enqueues a single action for processing.
  /// - Parameter action: The action to dispatch.
  public func dispatch(maxDispatchable limit: UInt = 0, _ action: A) {
    enqueue(action, limit: limit)
    runDispatcher()
  }
  
  /// Enqueues multiple actions for processing.
  /// - Parameter actions: The actions to dispatch.
  public func dispatch(maxDispatchable limit: UInt = 0, _ actions: A...) {
    enqueue(contentsOf: actions, limit: limit)
    runDispatcher()
  }
  
  /// Bind
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
  public func bind<T>(_ keyPath: KeyPath<S, T>, _ limit: UInt = 0, _ action: @escaping (T) -> A?) -> Binding<T> {
    Binding {
      self.state[keyPath: keyPath]
    } set: { newValue in
      if let action = action(newValue) {
        self.dispatch(maxDispatchable: limit, action)
      }
    }
  }
  
  #if targetEnvironment(simulator)
  /// Allows previews to mutate state directly without reducers.
  @discardableResult
  public func previewState(_ update: (S) -> Void) -> S {
    update(state)
    return state
  }
  #endif
}

private extension Store {
  var currentTime: UInt64 { DispatchTime.now().uptimeNanoseconds }
  
  var remainingActions: String {
    actionBuffer
      .map { ".\($0)" }
      .joined(separator: ",")
  }
}

private extension Store {
  func enqueue(_ action: A, limit: UInt) {
    onLog?("ℹ️ [[ Store ]] dispatch .\(action)")
    
    if limit > 0 {
      let count = bufferedActionCount[action, default: 0]
      guard count < limit else { return }
    }
    
    actionBuffer.append(action)
    bufferedActionCount[action, default: 0] += 1
  }
  
  func enqueue(contentsOf actions: [A], limit: UInt) {
    for action in actions {
      enqueue(action, limit: limit)
    }
  }
  
  func runDispatcher() {
    if isDispatcherRunning { return }
    
    defer {
      onLog?("ℹ️ [[ Store ]] dispatcher terminated.")
      isDispatcherRunning = false
    }
    
    isDispatcherRunning = true
    onLog?("ℹ️ [[ Store ]] run dispatcher.")
    while let action = actionBuffer.popFirst()  {
      onLog?("ℹ️ [[ Store ]] actions in queue [\(remainingActions)].")
      defer { decreaseCount(for: action) }
      do {
        try dispatchProcess(action)
      } catch {
        onException?(error)
      }
    }
  }
  
  func buildDispatchProcess() -> @MainActor (A) throws -> Void {
    let base: @MainActor (A) throws -> Void = { [weak self] action in
      guard let self else { throw ReduxError<S, A>.storeDeallocated }
      
      self.reduce(action)
    }
    
    let process: @MainActor (A) throws -> Void = { action in
      try  self.middlewares.reduce(base) { next, middleware in
        { [weak self] action in
          guard let self else { throw ReduxError<S, A>.storeDeallocated }
          
          let runProcess: @MainActor @Sendable (A, @escaping () -> Void) throws -> Void = { action, complete in
            try middleware.run(
              ( self.state.readOnly,
                self.dispatch,
                next,
                action,
                complete )
            )
          }
          
          if let onLog {
            try measureMiddleware { runTime in
              try runProcess(action) {
                onLog("ℹ️ [[ Store ]] \(middleware.id) process .\(action) in \(runTime())ms")
              }
            }
          } else {
            try runProcess(action, { })
          }
        }
      }(action)
    }
    
    return process
  }
  
  func reduce(_ action: A) -> Void {
    let currentState = self.state
    if let onLog {
      for reducer in self.reducers {
        measurePerformance { runTime in
          reducer.reduce(
            (
              currentState,
              action,
              { onLog("ℹ️ [[ Store ]] \(reducer.id) reduce .\(action) in \(runTime())ms") }
            )
          )
        }
      }
    } else {
      for reducer in self.reducers {
        reducer.reduce((currentState, action, { }))
      }
    }
  }
  
  func decreaseCount(for action: A) {
    guard let count = bufferedActionCount[action] else { return }
    if count <= 1 {
      bufferedActionCount.removeValue(forKey: action)
    } else {
      bufferedActionCount[action] = count - 1
    }
  }
}

private extension Store {
  func measureReducer(_ block: @escaping () throws -> Void) rethrows -> UInt64 {
    let startTime = currentTime
    try block()
    return (currentTime - startTime) / 1_000_000
  }
  
  func measureMiddleware(_ block: @escaping (_ runTime: @escaping () -> UInt64) throws -> Void) rethrows {
    let startTime = currentTime
    try block {
      return (self.currentTime - startTime) / 1_000_000
    }
  }
  
  func measurePerformance(_ block: @escaping (_ runTime: @escaping () -> UInt64) throws -> Void) rethrows {
    let startTime = currentTime
    try block {
      return (self.currentTime - startTime) / 1_000_000
    }
  }
}
