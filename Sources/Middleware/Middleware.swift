//


import Foundation


/// The intercepting closure stored by ``AnyMiddleware``. Runs on the main actor and
/// may `throw` → the framework routes the error to the RESOLVER.
public typealias MiddlewareHandler<S: ReduxState, A: ReduxAction> =
  @MainActor (MiddlewareContext<S, A>) throws -> MiddlewareExit<S, A>


/// Fire-and-forget async effect (`.task`). Runs on the main actor (so it can read the
/// `@MainActor` read-only state; `await` points free the main actor for I/O). Any `throw`
/// is routed to the resolver by the framework.
public typealias TaskHandler<S: ReduxState> =
  @MainActor @Sendable (S.ReadOnly) async throws -> Void


/// Suspending async effect (`.deferred`). Runs on the main actor; returns a
/// ``MiddlewareResumeExit`` to resume the chain; a `throw` is routed to the resolver.
public typealias DeferredTaskHandler<S: ReduxState, A: ReduxAction> =
  @MainActor @Sendable (S.ReadOnly) async throws -> MiddlewareResumeExit<A>


/// Middleware
///
/// Intercepts each action BEFORE the reducers (Redux `applyMiddleware`). Reads state
/// (read-only by convention), decides control flow via ``MiddlewareExit``, can launch
/// async effects (`.task`/`.deferred`) and `dispatch` new actions — but NEVER mutates
/// state (the reducer is the only writer). `run` may `throw` → resolver. Main actor.
public protocol Middleware<S, A>: Identifiable, Sendable
{
  /// The state type this middleware observes.
  associatedtype S: ReduxState
  /// The action type this middleware intercepts.
  associatedtype A: ReduxAction

  /// A stable identifier for logging and lift.
  var id: String { get }

  /// Intercepts one action and returns a ``MiddlewareExit`` (or throws → resolver).
  @MainActor
  func run(_ context: MiddlewareContext<S, A>) throws -> MiddlewareExit<S, A>
}
