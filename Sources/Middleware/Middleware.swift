//


import Foundation


/// Middleware
///
/// Intercepts actions between dispatch and reduction, providing a composable
/// extension point for side effects.
///
/// Middlewares are folded in reverse declaration order so the first element in
/// the user-supplied array runs first. Each middleware receives a
/// ``MiddlewareContext`` with the read-only state, dispatched action, and
/// dispatch capability, and returns a ``MiddlewareExit`` to control the pipeline:
///
/// - `.next` — action evaluated, forward to the next middleware.
/// - `.defaultNext` — pass-through, action not relevant to this middleware.
/// - `.nextAs` — forward with a modified action.
/// - `.resolve` / `throw` — route an error to the ``Resolver`` chain.
/// - `.exit(.success)` — action handled, short-circuit to the reducer chain.
/// - `.exit(.done)` — action handled, pipeline complete (no reducer).
/// - `.exit(.failure)` — forced termination, pipeline stops.
/// - `.task` — fire-and-forget async work; pipeline continues immediately.
/// - `.deferred` — async work that determines pipeline flow via resume callback.
///
/// `.next`, `.defaultNext`, and `.nextAs` forward to the next middleware in the chain.
/// After all middlewares have been traversed, the last forward enters the reduce chain.
///
/// ## Rules
///
/// - `side-effects`: middleware is the **only** place for I/O, network calls,
///   timers, and any other work that is not a pure state assignment.
/// - `throwing`: throw to let the ``Resolver`` chain handle failures; return
///   `.resolve` for explicit error routing; never swallow errors silently.
/// - `synchronous`: `run()` executes on `@MainActor`. Use `.task` for
///   fire-and-forget operations or `.deferred` when the async result
///   determines pipeline flow.
/// - `dispatch`: use the context's ``MiddlewareContext/dispatch`` to enqueue
///   new actions. These are dispatched as new pipeline entries, not
///   processed inline.
/// - `state`: read-only state is available on the context (read-only).
public protocol Middleware: Identifiable,
                            Sendable {
  
  /// The state type visible to this middleware.
  associatedtype S: ReduxState
  
  /// The action type this middleware intercepts.
  associatedtype A: ReduxAction
  
  /// A stable identifier for logging and metrics.
  var id: String { get }
  
  /// Processes the action within the given context.
  ///
  /// - Parameter context: The current state, action, and dispatch capability.
  @MainActor
  func run(_ context: MiddlewareContext<S, A>) throws -> MiddlewareExit<S, A>
}
