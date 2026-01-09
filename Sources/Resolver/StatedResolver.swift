//


import Foundation


/// AnyResolver
///
/// Type-erased wrapper around a ``Resolver``, stored as a closure.
@frozen
public struct StatedResolver<S: ReduxState, A: ReduxAction>: Resolver {

  /// A stable identifier for logging and metrics.
  public let id: String

  private let handler: ResolveHandler<S, A>

  /// Creates a type-erased resolver from a closure.
  ///
  /// - Parameters:
  ///   - id: Identifier for logging and metrics.
  ///   - handler: The resolver logic.
  public init<C: AnyObject & Sendable>(
    id: String,
    coordinator: C,
    handler: @escaping @MainActor (C, ResolverContext<S, A>) -> ResolverExit<A>
  ) {
    self.id = id
    self.handler = { context in
      handler(coordinator, context)
    }
  }

  /// Executes the stored handler with the given context.
  public func run(_ context: ResolverContext<S, A>) -> ResolverExit<A> {
    handler(context)
  }
}
