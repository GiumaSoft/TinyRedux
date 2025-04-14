

import Foundation


/// MiddlewareContext
///
///
@frozen
public struct MiddlewareContext<S, A> where S : ReduxState, A : ReduxAction {
  /// Current (read-only) state.
  public let state: S.ReadOnly
  /// Dispatch an action.
  public let dispatch: @MainActor (UInt, A...) -> Void
  /// Execute action on next middleware in chain.
  public let next: @MainActor (A) throws -> Void
  /// Current action
  public let action: A
  ///
  public let handled: () -> Void
  
  public init(
    state: S.ReadOnly,
    dispatch: @escaping @MainActor (UInt, A...) -> Void,
    next: @escaping @MainActor (A) throws  -> Void,
    action: A,
    handled: @escaping () -> Void = { }
  ) {
    self.state = state
    self.dispatch = dispatch
    self.next = next
    self.action = action
    self.handled = handled
  }
  
  public var args: (S.ReadOnly, @MainActor (UInt, A...) -> Void, @MainActor (A) throws -> Void, A) {
    (
      self.state,
      self.dispatch,
      self.next,
      self.action
    )
  }
}

/// AnyMiddleware protocol
///
///
public protocol AnyMiddleware: Identifiable {
  associatedtype S: ReduxState
  associatedtype A: ReduxAction
  
  var id: String { get }
  
  @MainActor
  func run(_ context: MiddlewareContext<S, A>) throws
}

/// Middleware
///
///
@frozen
public struct Middleware<S, A>: AnyMiddleware where S : ReduxState, A : ReduxAction {
  public let id: String
  private let handler: @MainActor (MiddlewareContext<S, A>) throws -> Void
  
  public init(
    id: String,
    _ handler: @escaping @MainActor (MiddlewareContext<S, A>
    ) throws -> Void) {
    self.id = id
    self.handler = handler
  }
  
  public init<M>(_ middleware: M) where M : AnyMiddleware, M.S == S, M.A == A {
    self.id = middleware.id
    self.handler = { context in try middleware.run(context) }
  }
  
  @MainActor
  public func run(_ context: MiddlewareContext<S, A>) throws {
    try handler(context)
  }
}

/// StatedMiddleware
///
///
@frozen
public struct StatedMiddleware<S: ReduxState, A: ReduxAction>: AnyMiddleware {
  struct Coordinator<C: Sendable> {
    private let coordinator: C
    private let handler: @MainActor (C, MiddlewareContext<S, A>) throws -> Void
    
    init(_ coordinator: C, _ handler: @escaping @MainActor (C, MiddlewareContext<S, A>) throws -> Void) {
      self.coordinator = coordinator
      self.handler = handler
    }
    
    @MainActor
    public func run(_ context: MiddlewareContext<S, A>) throws {
      try handler(coordinator, context)
    }
  }
  
  public let id: String
  private let handler: @MainActor (MiddlewareContext<S, A>) throws -> Void
  
  public init<C>(
    id: String,
    coordinator: C,
    handler: @escaping @MainActor (C, MiddlewareContext<S, A>) throws -> Void
  ) {
    let coordinator = Coordinator(coordinator, handler)
    self.handler = coordinator.run
    self.id = id
  }
  
  @MainActor
  public func run(_ context: MiddlewareContext<S, A>) throws {
    try handler(context)
  }
}


