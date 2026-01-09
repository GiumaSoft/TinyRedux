// swift-tools-version: 6.0


import Foundation


/// AnyResolver
/// 
/// Type-erased wrapper around a ``Resolver``, stored as a closure.
@frozen
public struct AnyResolver<State, Action>: Resolver where State: ReduxState, Action: ReduxAction {
  /// A stable identifier for logging and metrics.
  public let id: String

  /// The handler closure invoked by ``run(_:)``.
  private let handler: @Sendable (ResolverContext<State, Action>) -> Void

  /// Creates a type-erased resolver from a closure.
  ///
  /// - Parameters:
  ///   - id: Identifier for logging and metrics.
  ///   - handler: The resolver logic.
  public init(id: String, handler: @Sendable @escaping (ResolverContext<State, Action>) -> Void) {
    self.id = id
    self.handler = handler
  }

  /// Wraps an existing ``Resolver`` conformer via type erasure.
  ///
  /// - Parameter resolver: The resolver to wrap.
  public init<R>(_ resolver: R) where R: Resolver, R.State == State, R.Action == Action {
    self.id = resolver.id
    self.handler = { context in resolver.run(context) }
  }

  /// Executes the stored handler with the given context.
  public func run(_ context: ResolverContext<State, Action>) {
    handler(context)
  }
}
