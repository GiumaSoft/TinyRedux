//


import Foundation


/// Exit signal returned by `resume` inside a deferred middleware task.
///
/// Same as ``MiddlewareExit`` without `.deferred` and `.task` — prevents recursive deferral.
@frozen
public enum MiddlewareResumeExit<A: ReduxAction>: Sendable {

  /// Forwards the current action to the next middleware/reducer.
  case next

  /// Forwards a modified action to the next middleware/reducer.
  case nextAs(A)

  /// Routes an error to the resolver chain.
  case resolve(SendableError)

  /// Exits the middleware chain. `.success` short-circuits to the reducer chain; `.failure` terminates the pipeline.
  case exit(Result<Void, SendableError>)
}
