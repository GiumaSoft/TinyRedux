//


import Foundation


/// Type-erased wrapper around a ``Middleware``, stored as a closure.
public struct AnyMiddleware<S: ReduxState, A: ReduxAction>: Middleware {

  /// A stable identifier for logging and metrics.
  public let id: String

  private let handler: MiddlewareHandler<S, A>

  /// Creates a type-erased middleware from a closure.
  ///
  /// - Parameters:
  ///   - id: Identifier for logging and metrics.
  ///   - handler: The middleware logic.
  public init(
    id: String,
    handler: @escaping MiddlewareHandler<S, A>
  ) {
    self.id = id
    self.handler = handler
  }

  /// Wraps an existing ``Middleware`` conformer via type erasure.
  ///
  /// - Parameter middleware: The middleware to wrap.
  public init<M: Middleware>(_ middleware: M)
  where M.S == S, M.A == A {
    self.id = middleware.id
    self.handler = { context in
      try middleware.run(context)
    }
  }

  /// Executes the stored handler with the given context.
  public func run(_ context: MiddlewareContext<S, A>) throws -> MiddlewareExit<S, A> {
    try handler(context)
  }
}
