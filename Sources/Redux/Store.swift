

import Collections
import Observation
import SwiftUI



@MainActor
public protocol ReadOnlyState: AnyObject, Sendable {
  ///
  associatedtype State: ReduxState
  ///
  init(_ state: State)
}


/// ReduxState
///
///
@MainActor
public protocol ReduxState: AnyObject, Observable, Sendable {
  /// Define protocol that conform to a read-only accessible state.
  associatedtype ReadOnly: ReadOnlyState where ReadOnly.State == Self
  /// Property that make state accessible in read-only mode.
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
  /// Action unique identifier.
  var id: Int { get }
}


@MainActor
@dynamicMemberLookup
public final class Store<S, A> where S : ReduxState, A : ReduxAction {
  ///
  internal var state: S
  ///
  private let reducers: [Reducer<S, A>]
  ///
  private let middlewares: [Middleware<S, A>]
  ///
  private let onException: (any Error) -> Void
  ///
  private let onLog: (String) -> Void
  ///
  private var actionBuffer: Deque<A>
  /// Container that stores counters for same actions currently buffered (and in-flight),
  /// used by `enqueue`.
  private var bufferedActionCount: [A: UInt]
  ///
  private var isProcessRunning: Bool
  ///
  private lazy var processCache: (A) throws -> Void = buildProcess()
  ///
  public static func sharedInstance(
    initialState state: S,
    middlewares: [Middleware<S, A>],
    reducers: [Reducer<S, A>],
    onException: @escaping (any Error) -> Void = { _ in },
    onLog: @escaping (String) -> Void = { _ in }
  ) -> Store<S, A> {
    Singleton.getInstance {
      Store<S, A>(
        initialState: state,
        middlewares: middlewares,
        reducers: reducers,
        onException: onException,
        onLog: onLog
      )
    }
  }
  
  private init(
    initialState state: S,
    middlewares: [Middleware<S, A>],
    reducers: [Reducer<S, A>],
    onException: @escaping (any Error) -> Void = { _ in },
    onLog:  @escaping (String) -> Void = { _ in }
  ) {
    self.state = state
    self.reducers = reducers
    self.middlewares = middlewares
    self.onException = onException
    self.onLog = onLog
    self.actionBuffer = Deque()
    self.bufferedActionCount = [:]
    self.isProcessRunning = false
  }
  
  public subscript<Value>(dynamicMember keyPath: KeyPath<S.ReadOnly, Value>) -> Value {
    state.readOnly[keyPath: keyPath]
  }
  
  var pendingActionsDescription: String {
    actionBuffer.map { ".\($0.description)" }.joined(separator: ",")
  }
}


extension Store {
  public func dispatch(queueLimit limit: UInt = 0, _ action: A) {
    enqueue(action, queueLimit: limit)
    if !isProcessRunning { runDispatcher() }
  }
  
  public func dispatch(queueLimit limit: UInt = 0, _ actions: A...) {
    enqueue(actions, queueLimit: limit)
    if !isProcessRunning { runDispatcher() }
  }
  
  public func dispatch(queueLimit limit: UInt = 0, _ actions: [A]) {
    enqueue(actions, queueLimit: limit)
    if !isProcessRunning { runDispatcher() }
  }
  
  private func enqueue(_ action: A, queueLimit limit: UInt) {
    onLog("ℹ️ [[ Store ]]: dispatch [.\(action)] action.")
    
    if limit > 0 {
      let count = bufferedActionCount[action, default: 0]
      guard count < limit else { return }
    }
    
    actionBuffer.append(action)
    bufferedActionCount[action, default: 0] += 1
  }
  
  private func enqueue(_ actions: [A], queueLimit limit: UInt) {
    for action in actions {
      enqueue(action, queueLimit: limit)
    }
  }
  
  private func runDispatcher() {
    if isProcessRunning { return }
    
    onLog("ℹ️ [[ Store ]]: run dispatcher.")
    
    isProcessRunning = true
    while let action = actionBuffer.popFirst() {
      onLog("ℹ️ [[ Store ]]: actions in queue: [\(pendingActionsDescription)].")
      defer { decrementCount(for: action) }
      do {
        try processCache(action)
      } catch {
        onException(error)
      }
    }
    isProcessRunning = false
    
    onLog("ℹ️ [[ Store ]]: dispatcher terminated.")
  }
  
  private func buildProcess() -> (A) throws -> Void {
    let storeDeallocationFailureReason = "Store<\(String(describing: S.self)),\(String(describing: A.self))> was deallocated while processing an action. Store is expected to exists for the entire App lifecycle."
    
    return middlewares.reversed().reduce(
      { [weak self] action in
        guard let self else { fatalError(storeDeallocationFailureReason) }
        
        let currentState = self.state
        for reducer in self.reducers {
          try reducer.reduce(
            currentState,
            ReducerContext(action: action,
              handled: {
                self.onLog("ℹ️ [[ \(reducer.id) ]] handle [\(action.debugDescription)] action.")
              }
            )
          )
        }
      },
      { [weak self] next, middleware in
        { [weak self] action in
          guard let self else {
            fatalError(storeDeallocationFailureReason)
          }
          
          try middleware.run(
            MiddlewareContext(
              state: self.state.readOnly,
              dispatch: { [weak self] (limit, actions) in
                guard let self else { fatalError(storeDeallocationFailureReason) }
                self.dispatch(queueLimit: limit, actions)
              },
              next: next,
              action: action,
              handled: {
                self.onLog("ℹ️ [[ \(middleware.id) ]] handle [\(action.debugDescription)] action.")
              }
            )
          )
        }
      }
    )
  }
  
  private func decrementCount(for action: A) {
    guard let count = bufferedActionCount[action] else { return }
    if count <= 1 {
      bufferedActionCount.removeValue(forKey: action)
    } else {
      bufferedActionCount[action] = count - 1
    }
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
  public func bind<T>(_ keyPath: KeyPath<S, T>, _ limit: UInt = 0, _ action: @escaping (T) -> A?) -> Binding<T> {
    Binding {
      self.state[keyPath: keyPath]
    } set: { newValue in
      if let action = action(newValue) {
        self.dispatch(queueLimit: limit, action)
      }
    }
  }
}

#if targetEnvironment(simulator)
extension Store {
  /// Allows previews to mutate state directly without reducers.
  @discardableResult
  public func previewState(_ update: (inout S) -> Void) -> S {
    update(&state)
    return state
  }
}
#endif
