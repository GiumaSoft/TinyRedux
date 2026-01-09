// swift-tools-version: 6.0


import Foundation


/// A resolver that carries a coordinator used for local state and async orchestration. The
/// coordinator is intended to encapsulate complex framework interactions, async state, and helper
/// functions so the resolver logic stays small and focused. Use this type when a resolver needs
/// shared, long-lived resources such as networking clients, caches, or external SDK coordinators.
/// The coordinator is created once and injected into each run, ensuring deterministic behavior and
/// avoiding repeated initialization. This keeps remediation steps testable, centralized, and
/// consistent across errors. It also supports async workflows without bloating resolver code.
@frozen public struct StatedResolver<S, A>: AnyResolver where S : ReduxState, A : ReduxAction {
  /// The stable identity of the entity associated with this instance.
  public let id: String
  /// Stored handler invoked by `run` to process a resolver context.
  private let handler: @MainActor @Sendable (ResolverContext<S, A>) -> Void
  /// Creates a resolver bound to a coordinator instance, storing a handler that receives
  /// coordinator and context on the MainActor to keep stateful remediation logic isolated and
  /// reusable across errors safely. Creates a resolver with a coordinator instance.
  ///
  /// - Parameters:
  ///   - id: Identifier for logging and metrics.
  ///   - coordinator: A coordinator object used for local state and async orchestration.
  ///   - handler: The resolver handler.
  public init<C: Sendable>(
    id: String,
    coordinator: C,
    handler: @escaping @MainActor @Sendable (C, ResolverContext<S, A>) -> Void
  ) {
    self.id = id
    self.handler = { context in
      handler(coordinator, context)
    }
  }
  /// Runs the stored handler on the MainActor with the resolver context, enabling coordinated
  /// remediation workflows that may dispatch new actions or short-circuit reduction for this action
  /// path when needed only. Runs the resolver for the given context.
  @MainActor
  public func run(_ context: ResolverContext<S, A>) {
    handler(context)
  }
}
