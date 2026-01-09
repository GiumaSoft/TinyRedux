// swift-tools-version: 6.2


import Foundation

/// StatedMiddlware
///
/// A ``Middleware`` variant that captures a coordinator for stateful side effects across dispatches.
@frozen
public struct StatedMiddleware<State, Action>: Middleware where State: ReduxState, Action: ReduxAction {
  /// A stable identifier for logging and metrics.
  public let id: String

  /// The handler closure invoked by ``run(_:)``.
  private let handler: @Sendable (MiddlewareContext<State, Action>) throws -> Void

  /// Creates a stateful middleware bound to a coordinator.
  ///
  /// - Parameters:
  ///   - id: Identifier for logging and metrics.
  ///   - coordinator: Object that holds local state across dispatches.
  ///   - handler: Closure receiving the coordinator and middleware context.
  public init<C>(
    id: String,
    coordinator: C,
    handler: @Sendable @escaping (C, MiddlewareContext<State, Action>) throws -> Void
  ) where C: AnyObject & Sendable {
    self.id = id
    self.handler = { context in
      try handler(coordinator, context)
    }
  }

  /// Executes the stored handler with the given context.
  public func run(_ context: MiddlewareContext<State, Action>) throws {
    try handler(context)
  }
}
