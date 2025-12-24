

import Foundation

/// Context passed to a middleware invocation.
/// - Parameters:
///   - state: Read-only view of the current state.
///   - dispatch: Enqueues one or more actions.
///   - next: Invokes the next middleware in the chain.
///   - action: The action currently being processed.
public typealias MiddlewareContext<S, A> = (
  state: S.ReadOnly,
  dispatch: @MainActor @Sendable (UInt, A...) -> Void,
  next: @MainActor @Sendable (A) throws -> Void,
  action: A,
  complete: () -> Void
) where S: ReduxState, A: ReduxAction


/// AnyMiddleware protocol
///
///
public protocol AnyMiddleware: Identifiable, Sendable {
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
public struct Middleware<S, A>: AnyMiddleware where S: ReduxState, A: ReduxAction {
  /// A stable identifier for logging and metrics.
  public let id: String
  private let handler: @MainActor @Sendable (MiddlewareContext<S, A>) throws -> Void
  
  /// Creates a middleware with the given handler.
  /// - Parameters:
  ///   - id: Identifier for logging and metrics.
  ///   - handler: The middleware handler.
  public init(id: String, handler: @escaping @MainActor @Sendable (MiddlewareContext<S, A>) throws -> Void) {
    self.id = id
    self.handler = handler
  }
  
  public init<M>(_ middleware: M) where M : AnyMiddleware, M.S == S, M.A == A {
    self.id = middleware.id
    self.handler = { context in try middleware.run(context) }
  }
  
  /// Runs the middleware for the given context.
  /// - Parameter context: The middleware context.
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
  public let id: String
  private let handler: @MainActor @Sendable (MiddlewareContext<S, A>) throws -> Void
  
  public init<C: Sendable>(
    id: String,
    coordinator: C,
    handler: @escaping @MainActor @Sendable (C, MiddlewareContext<S, A>) throws -> Void
  ) {
    self.id = id
    self.handler = { context in
      try handler(coordinator, context)
    }
  }
  
  @MainActor
  public func run(_ context: MiddlewareContext<S, A>) throws {
    try handler(context)
  }
}

