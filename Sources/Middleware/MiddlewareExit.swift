//


import Foundation


/// Exit signal returned by a middleware's `run()` method.
///
/// Controls how the dispatch pipeline proceeds after middleware execution.
public enum MiddlewareExit<S: ReduxState, A: ReduxAction>: Sendable {

  /// Forwards the current action to the next middleware/reducer.
  case next

  /// Default pass-through — the action was not handled by this middleware.
  case defaultNext

  /// Forwards a modified action to the next middleware/reducer.
  case nextAs(A)

  /// Routes an error to the resolver chain.
  case resolve(SendableError)

  /// Exits the middleware chain. `.success` short-circuits to the reducer chain; `.done` terminates the pipeline (action handled, no reducer); `.failure` terminates the pipeline (error).
  case exit(ExitResult)

  /// Launches a fire-and-forget async task with state access. Pipeline continues immediately (.next implicit).
  case task(TaskHandler<S>)

  /// Defers the pipeline decision to an async task body with read-only state access.
  /// The handler returns a ``MiddlewareResumeExit`` to continue the pipeline.
  ///
  /// - Important: while the handler is awaited, the worker advances to the next
  ///   queued action — a later action can reach the reducers before this one
  ///   resumes. FIFO ordering holds for the synchronous pipeline segments only.
  ///   If the resumed work must be ordered with respect to subsequent actions,
  ///   end the deferred body by `dispatch`ing a follow-up action (a new FIFO
  ///   entry) instead of resuming into the reduce chain.
  case deferred(DeferredTaskHandler<S, A>)

  /// Converts a ``MiddlewareResumeExit`` into a ``MiddlewareExit`` for logging.
  init(from resumeExit: MiddlewareResumeExit<A>) {
    self = switch resumeExit {
    case .next: .next
    case let .nextAs(action): .nextAs(action)
    case let .resolve(error): .resolve(error)
    case let .exit(result): .exit(result)
    }
  }
}
