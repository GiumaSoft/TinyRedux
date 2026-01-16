// swift-tools-version: 6.0


import Foundation


/// Resolver Resolvers are MainActor-bound handlers that receive a ResolverContext when middleware
/// throws. They can inspect the error, origin, and action, dispatch new actions, or decide whether
/// to continue the chain by calling next. A resolver can perform asynchronous remediation, then
/// call next later, or stop the pipeline entirely. The type stores a handler closure and an
/// identifier for logging and metrics. Multiple resolvers can be composed, and each may adjust the
/// error before forwarding. This enables explicit supervision and deterministic recovery
/// strategies. It integrates with store logging and timing hooks.
@frozen public struct Resolver<S, A>: AnyResolver where S : ReduxState, A : ReduxAction {
  /// A stable identifier for logging and metrics.
  public let id: String
  /// Stored handler invoked by `run` to process a resolver context.
  private let handler: @MainActor @Sendable (ResolverContext<S, A>) -> Void
  /// Creates a resolver with an identifier and handler closure, storing it for MainActor execution
  /// when middleware errors occur, enabling remediation logic before reducers or further resolver
  /// chaining in the pipeline. Creates a resolver with the given handler.
  /// - Parameters:
  ///   - id: Identifier for logging and metrics.
  ///   - handler: The resolver handler.
  public init(id: String, handler: @escaping @MainActor @Sendable (ResolverContext<S, A>) -> Void) {
    self.id = id
    self.handler = handler
  }
  /// Wraps another resolver by capturing its identifier and delegating run calls, enabling type
  /// erasure and uniform storage within resolver arrays without changing execution semantics or
  /// ordering behavior across chains safely. Wraps another resolver type.
  /// - Parameter resolver: The resolver to wrap.
  public init<R>(_ resolver: R) where R : AnyResolver, R.S == S, R.A == A {
    self.id = resolver.id
    self.handler = { context in resolver.run(context) }
  }
  /// Invokes the stored handler on the MainActor with the provided resolver context, enabling
  /// remediation logic to dispatch actions, continue the chain, or stop reduction for this action
  /// path when necessary. Runs the resolver for the given context.
  /// - Parameter context: The resolver context.
  @MainActor
  public func run(_ context: ResolverContext<S, A>) {
    handler(context)
  }
}
