//


import Foundation


/// The resolving closure stored by ``AnyResolver``. Runs on the main actor; does NOT
/// throw (the resolver IS the error handler — it returns a ``ResolverExit``).
public typealias ResolveHandler<S: ReduxState, A: ReduxAction> =
  @MainActor (ResolverContext<S, A>) -> ResolverExit<A>


/// Resolver
///
/// Handles errors raised in the pipeline (a middleware `throw`, `.exit(.resolve)`, or a
/// failing effect). Given the error + the originating action, it decides recovery via
/// ``ResolverExit``: pass on (`defaultNext`), commit a recovery (`exit(.reduce/.reduceAs)`),
/// absorb (`exit(.done)`) or fail (`exit(.fail)`). Synchronous, main actor, non-throwing.
public protocol Resolver<S, A>: Identifiable, Sendable
{
  /// The state type this resolver observes.
  associatedtype S: ReduxState
  /// The action type this resolver handles.
  associatedtype A: ReduxAction

  /// A stable identifier for logging and lift.
  var id: String { get }

  /// Resolves one error and returns a ``ResolverExit``.
  @MainActor
  func run(_ context: ResolverContext<S, A>) -> ResolverExit<A>
}
