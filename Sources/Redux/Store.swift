

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
  private let onException: (any Error) -> Void
  private let onLog: ((String) -> Void)?
  private var actionBuffer: Deque<A>
  private var bufferedActionCount: [A: UInt]
  private var isDispatcherRunning: Bool
  
  private lazy var dispatchProcess: @MainActor (A) throws -> Void = buildDispatchProcess()
  
  /// Creates a store with the given state, middleware chain, and reducers.
  /// - Parameters:
  ///   - initialState: The initial state of the store.
  ///   - middlewares: Middleware applied in the provided order.
  ///   - reducers: Reducers applied in the provided order.
  ///   - onException: Used to handle exceptions when middleware or reducer processing throws.
  ///   - onLog: Used to log middleware and reducer processing action and performance.
  public init(
    initialState: S,
    middlewares: [Middleware<S, A>],
    reducers: [Reducer<S, A>],
    onException: @escaping (any Error) -> Void,
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
  
  /// Accesses read-only state via dynamic member lookup.
  public subscript<Value>(dynamicMember keyPath: KeyPath<S.ReadOnly, Value>) -> Value {
    state.readOnly[keyPath: keyPath]
  }
  
  /// Enqueues a single action for processing.
  /// - Parameters:
  ///   - limit: Maximum buffered instances of the same action; 0 means unlimited.
  ///   - action: The action to dispatch.
  public func dispatch(maxDispatchable limit: UInt = 0, _ action: A) {
    enqueue(action, limit: limit)
    runDispatcher()
  }
  
  /// Enqueues multiple actions for processing.
  /// - Parameters:
  ///   - limit: Maximum buffered instances of the same action; 0 means unlimited.
  ///   - actions: The actions to dispatch.
  public func dispatch(maxDispatchable limit: UInt = 0, _ actions: A...) {
    enqueue(contentsOf: actions, limit: limit)
    runDispatcher()
  }
  
  /// Creates a binding that dispatches an action when the value changes.
  /// - Parameters:
  ///   - keyPath: Key path into the state.
  ///   - limit: Maximum buffered instances of the same action; 0 means unlimited.
  ///   - action: Maps the new value into an optional action to dispatch.
  public func bind<T>(_ keyPath: KeyPath<S, T>, maxDispatchable limit: UInt = 0, _ action: @escaping (T) -> A?) -> Binding<T> {
    Binding {
      self.state[keyPath: keyPath]
    } set: { newValue in
      if let action = action(newValue) {
        self.dispatch(maxDispatchable: limit, action)
      }
    }
  }
  
  #if targetEnvironment(simulator)
  /// Creates a direct writable binding for previews.
  /// - Important: This bypasses reducers and is intended for simulator-only previews.
  public func bind<T>(_ keyPath: WritableKeyPath<S, T>) -> Binding<T> {
    Binding {
      self.state[keyPath: keyPath]
    } set: { newValue in
      self.state[keyPath: keyPath] = newValue
    }
  }
  
  /// Allows previews to mutate state directly without reducers.
  public func previewState(_ update: (S) -> Void) {
    update(state)
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
  /// Enqueues a single action and enforces the buffer limit.
  func enqueue(_ action: A, limit: UInt) {
    if limit > 0 {
      let count = bufferedActionCount[action, default: 0]
      guard count < limit else { return }
    }
    
    onLog?("ℹ️ [[ Store ]] dispatch .\(action)")
    
    actionBuffer.append(action)
    bufferedActionCount[action, default: 0] += 1
  }
  
  /// Enqueues a list of actions in order.
  func enqueue(contentsOf actions: [A], limit: UInt) {
    for action in actions {
      enqueue(action, limit: limit)
    }
  }
  
  /// Runs the dispatcher loop to process buffered actions.
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
        onException(error)
      }
    }
  }
  
  /// Builds the middleware chain and reducer pipeline.
  func buildDispatchProcess() -> @MainActor (A) throws -> Void {
    let base: @MainActor (A) throws -> Void = { [weak self] action in
      guard let self else { throw ReduxError.storeDeallocated(S.self, A.self) }
      
      self.reduce(action)
    }
    
    let process: @MainActor (A) throws -> Void = { [weak self] action in
      guard let self else { throw ReduxError.storeDeallocated(S.self, A.self) }
      
      try self.middlewares.reduce(base) { next, middleware in
        { [weak self] action in
          guard let self else { throw ReduxError.storeDeallocated(S.self, A.self) }
          
          let runProcess: @MainActor @Sendable (A, @escaping () -> Void) throws -> Void = { action, complete in
            try middleware.run(
              ( self.state.readOnly,
                self.dispatch,
                next,
                action,
                complete )
            )
          }
          
          if let onLog = self.onLog {
            try self.measurePerformance { runTime in
              try runProcess(action) {
                onLog("ℹ️ [[ Store ]] \(middleware.id) process .\(action.debugDescription) in \(runTime())ms")
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
  
  /// Runs all reducers for the given action.
  func reduce(_ action: A) -> Void {
    let currentState = self.state
    if let onLog {
      for reducer in self.reducers {
        measurePerformance { runTime in
          reducer.reduce(
            (
              currentState,
              action,
              { onLog("ℹ️ [[ Store ]] \(reducer.id) reduce .\(action.debugDescription) in \(runTime())ms") }
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
  
  /// Decrements the buffered count for an action after processing.
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
  /// Measures execution time in milliseconds and passes a lazy timer to the block.
  func measurePerformance(_ block: @escaping (_ runTime: @escaping () -> UInt64) throws -> Void) rethrows {
    let startTime = currentTime
    try block {
      return (self.currentTime - startTime) / 1_000_000
    }
  }
}
