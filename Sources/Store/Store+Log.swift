//


import Foundation


extension Store {

  /// Diagnostic entry emitted by the pipeline via `onLog`.
  ///
  /// Each component logs its identifier, the action, elapsed time, and exit signal.
  /// Deferred and task completions convert their resume exit via ``MiddlewareExit/init(from:)``.
  public enum Log: Sendable {

    /// Middleware step — id, action, elapsed, exit signal.
    case middleware(String, A, Duration, MiddlewareExit<S, A>)

    /// Reducer step — id, action, elapsed, exit signal.
    case reducer(String, A, Duration, ReducerExit)

    /// Resolver step — id, action, elapsed, exit signal, captured error.
    case resolver(String, A, Duration, ResolverExit<A>, SendableError)

    /// Store-level event (reserved for future use).
    case store(String)
  }
}
