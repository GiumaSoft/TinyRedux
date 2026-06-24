//


import Foundation


/// The resolving closure stored by ``AnyReduxResolver``. Runs on the main actor; does NOT
/// throw (the resolver IS the error handler — it returns a ``ReduxResolverExit``).
public typealias ReduxResolveHandler<S: ReduxState, A: ReduxAction> =
  @MainActor (ReduxResolverContext<S, A>) -> ReduxResolverExit<A>


/// ReduxResolver
///
/// Handles errors raised in the pipeline (a middleware `throw`, `.exit(.resolve)`, or a
/// failing effect). Given the error + the originating action, it decides recovery via
/// ``ReduxResolverExit``: pass on (`defaultNext`), commit a recovery (`exit(.reduce/.reduceAs)`),
/// absorb (`exit(.done)`) or fail (`exit(.fail)`). Synchronous, main actor, non-throwing.
public protocol ReduxResolver<S, A>: Identifiable, Sendable
{
  /// The state type this resolver observes.
  associatedtype S: ReduxState
  /// The action type this resolver handles.
  associatedtype A: ReduxAction

  /// A stable identifier for logging and lift.
  var id: String { get }

  /// Resolves one error and returns a ``ReduxResolverExit``.
  @MainActor
  func run(_ context: ReduxResolverContext<S, A>) -> ReduxResolverExit<A>
}
