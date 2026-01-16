// swift-tools-version: 6.0


import Foundation


/// A middleware that carries a coordinator used for local state and async orchestration. The
/// coordinator is intended to encapsulate complex framework interactions, async state, and helper
/// functions so the middleware logic stays small and focused. Use this type when middleware needs
/// shared resources such as network clients, service adapters, or long-lived async tasks. The
/// coordinator is created once and injected into each run, keeping initialization cost low and
/// behavior deterministic. This design improves testability by letting you stub the coordinator
/// separately, and avoids leaking framework complexity into middleware closures. It also supports
/// asynchronous orchestration without scattering state across unrelated components.
@frozen public struct StatedMiddleware<S, A>: AnyMiddleware where S : ReduxState, A : ReduxAction {
  /// The stable identity of the entity associated with this instance.
  public let id: String
  /// Stored handler invoked by `run` to process a middleware context.
  private let handler: @MainActor (MiddlewareContext<S, A>) throws -> Void
  /// Creates a middleware bound to a coordinator instance, storing a handler that receives
  /// coordinator and context on the MainActor to isolate stateful async orchestration across runs
  /// safely for each action. Creates a middleware with a coordinator instance.
  ///
  /// - Parameters:
  ///   - id: Identifier for logging and metrics.
  ///   - coordinator: A coordinator object used for local state and async orchestration.
  ///   - handler: The middleware handler.
  public init<C: Sendable>(
    id: String,
    coordinator: C,
    handler: @escaping @MainActor (C, MiddlewareContext<S, A>) throws -> Void
  ) {
    self.id = id
    self.handler = { context in
      try handler(coordinator, context)
    }
  }
  /// Runs the stored handler on the MainActor with the middleware context, enabling coordinator-
  /// driven side effects, dispatching, and control of whether the pipeline continues for this
  /// action path only when needed. Runs the middleware for the given context.
  @MainActor
  public func run(_ context: MiddlewareContext<S, A>) throws {
    try handler(context)
  }
}
