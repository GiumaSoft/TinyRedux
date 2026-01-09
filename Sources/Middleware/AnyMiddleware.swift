// swift-tools-version: 6.2


import Foundation


/// Type-erased wrapper around a ``Middleware``, stored as a closure.
///
/// 
@frozen
public struct AnyMiddleware<State, Action>: Middleware where State: ReduxState, Action: ReduxAction {
  /// A stable identifier for logging and metrics.
  public let id: String

  /// The handler closure invoked by ``run(_:)``.
  private let handler: @Sendable (MiddlewareContext<State, Action>) throws -> Void

  /// Creates a type-erased middleware from a closure.
  ///
  /// - Parameters:
  ///   - id: Identifier for logging and metrics.
  ///   - handler: The middleware logic.
  public init(id: String, handler: @Sendable @escaping (MiddlewareContext<State, Action>) throws -> Void) {
    self.id = id
    self.handler = handler
  }

  /// Wraps an existing ``Middleware`` conformer via type erasure.
  ///
  /// - Parameter middleware: The middleware to wrap.
  public init<M>(_ middleware: M) where M: Middleware, M.State == State, M.Action == Action {
    self.id = middleware.id
    self.handler = { context in try middleware.run(context) }
  }

  /// Executes the stored handler with the given context.
  public func run(_ context: MiddlewareContext<State, Action>) throws {
    try handler(context)
  }
}
