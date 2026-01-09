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

    /// Subscription lifecycle event.
    case subscription(Subscription)

    /// Store-level event (reserved for future use).
    case store(String)
  }
}


extension Store.Log {

  /// Subscription lifecycle events. Naming aligned with the public API
  /// (`subscribe`/`unsubscribe`): `.subscribed`, `.executed`, `.unsubscribed`.
  ///
  /// Correlation between `.subscribed` and `.executed` for the same subscription
  /// is established via the `subId` (second `String` parameter).
  public enum Subscription: Sendable {

    /// Subscription entered the registry — registeredBy, subId, origin, elapsed.
    case subscribed(String, String, A, Duration)

    /// Subscription cycle completed — registeredBy, subId, origin, elapsed, dispatched action.
    /// The action dispatched at match time is emitted here for immediate correlation;
    /// its own pipeline produces standard `.middleware`/`.reducer` log entries.
    case executed(String, String, A, Duration, A)

    /// Subscription removed via `context.unsubscribe(id:)` — canceller, subId, elapsed.
    /// The first `String` is the id of the middleware that called `unsubscribe`,
    /// NOT the original `registeredBy`. Correlate via `subId` with the preceding `.subscribed`.
    case unsubscribed(String, String, Duration)
  }
}
