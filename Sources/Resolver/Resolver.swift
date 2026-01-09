//


import Foundation


/// Resolver
///
/// Handles errors that occur during middleware execution, providing a structured
/// recovery mechanism within the dispatch pipeline.
///
/// When a ``Middleware`` throws or returns `.resolve`, the error is routed to
/// the resolver chain. Resolvers are folded in reverse declaration order so the
/// first element in the user-supplied array runs first. Each resolver inspects
/// the error and returns a ``ResolverExit`` to control the pipeline:
///
/// - `.next` — error handled, log and forward to the next resolver.
/// - `.nextAs` — error handled, log and forward modified action to next resolver.
/// - `.defaultNext` — error not handled, forward to next resolver.
/// - `.reduce` — error recovered, log and forward to reduce chain.
/// - `.reduceAs` — error recovered, log and forward modified action to reduce chain.
/// - `.exit(.success)` — error handled, log success and terminate pipeline.
/// - `.exit(.failure)` — error unrecoverable, log error and terminate pipeline.
///
/// If no resolver handles the error, the seed logs it as unhandled and calls
/// deferSnapshot with `.failure(error)`.
///
/// ## Rules
///
/// - `non-throwing`: a resolver must never throw. All error handling is
///   expressed through ``ResolverExit`` cases.
/// - `synchronous`: no async work; resolvers run on `@MainActor`.
/// - `dispatch`: use the context's ``ResolverContext/dispatch`` to enqueue
///   recovery actions. These are dispatched as new pipeline entries, not
///   processed inline.
/// - `stateless`: do not use local persistent state outside of ``ResolverContext``.
public protocol Resolver: Identifiable, Sendable {
  
  /// The state type visible to this resolver.
  associatedtype S: ReduxState
  
  /// The action type this resolver handles.
  associatedtype A: ReduxAction
  
  /// A stable identifier for logging and metrics.
  var id: String { get }
  
  /// Evaluates the error and decides how the pipeline should proceed.
  ///
  /// - Parameter context: The error, originating action, read-only state, and dispatch capability.
  /// - Returns: A ``ResolverExit`` controlling the resolve chain flow.
  @MainActor
  func run(_ context: ResolverContext<S, A>) -> ResolverExit<A>
}
