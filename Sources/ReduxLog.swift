//

import Foundation


/// ReduxLog
///
/// Structured, typed log event emitted by the store pipeline. Delivered to an optional
/// `ReduxLogHandler` set at `ReduxStore` init. Construction is lazy: nothing is built
/// (nor is any clock read) when no handler is attached (see the Worker's `emit`/`measuring`).
public enum ReduxLog<S, A>: Sendable
where S: ReduxState, A: ReduxAction
{
  /// A reducer ran for an action: its id, the action, the elapsed time, and its exit.
  case reducer(id: String, action: A, duration: Duration, exit: ReduxReducerExit)

  /// A middleware produced a (synchronous) exit for an action.
  case middleware(id: String, action: A, duration: Duration, exit: MiddlewareExit<S, A>)

  /// A resolver handled an error for an action.
  case resolver(id: String, action: A, duration: Duration, exit: ResolverExit<A>, error: SendableError)

  /// A subscription lifecycle/firing event (State→Action).
  case subscription(SubscriptionLog<A>)

  /// A snapshot lifecycle event (single-shot resolution or stream frame/lifecycle).
  case snapshot(SnapshotLog<A>)

  /// Backpressure diagnostic: an `action.id` exceeded the configured rate — `count`
  /// occurrences within `window`. Pure warning (no drop); the stream stays unbounded.
  case highFrequencyAction(id: String, count: Int, window: Duration)

  /// A store-level event (free-form message), e.g. a discarded action.
  case store(String)
}


/// SubscriptionLog
///
/// Lifecycle/firing events for a State→Action ``Subscription`` — the worker emits these as
/// `ReduxLog.subscription(_:)`. Carries `origin` (middleware id), the subscription id,
/// `registeredBy` (the action during which it was registered), and the elapsed time
/// (plus `trigger`, the action dispatched on firing, for `executed`).
public enum SubscriptionLog<A: ReduxAction>: Sendable
{
  /// A subscription was registered.
  case subscribed(origin: String, id: String, registeredBy: A, duration: Duration)

  /// A subscription fired: its predicate held and `trigger` was dispatched.
  case executed(origin: String, id: String, registeredBy: A, duration: Duration, trigger: A)

  /// A subscription was removed.
  case unsubscribed(origin: String, id: String, duration: Duration)
}


/// SnapshotLog
///
/// Lifecycle/firing events for the snapshot dispatch paths — the worker emits these as
/// `ReduxLog.snapshot(_:)`. Covers the single-shot resolution (`resolved`/`failed`) and
/// the stream (`streamRegistered`/`streamFrame`/`streamEncodeFailed`/`streamFinished`).
public enum SnapshotLog<A: ReduxAction>: Sendable
{
  /// A single-shot snapshot settled and was encoded (`byteCount` bytes of JSON).
  case resolved(action: A, byteCount: Int, duration: Duration)

  /// A single-shot snapshot failed (pipeline error, rejection, teardown, or encode throw).
  case failed(action: A, error: SendableError)

  /// A snapshot stream was registered against an arming action.
  case streamRegistered(id: String, action: A, emitInitial: Bool)

  /// A stream emitted one frame (`byteCount` bytes of JSON).
  case streamFrame(id: String, byteCount: Int)

  /// A stream's encode threw for one frame; delivered as `.failure`, stream stays alive.
  case streamEncodeFailed(id: String, error: SendableError)

  /// A stream ended; `reason` says why.
  case streamFinished(id: String, reason: StreamFinishReason)
}


/// Why a snapshot stream ended.
public enum StreamFinishReason: Sendable
{
  /// The required `count`/`time`/`timeOrCount` bound was reached.
  case limitReached

  /// The consumer broke its `for await` loop (continuation terminated).
  case consumerCancelled

  /// The store was torn down (`Worker.deinit`).
  case storeTerminated

  /// The arming action was rejected at the dispatch gate and never reduced.
  case armingRejected
}


/// Sink for ``ReduxLog`` events. `@Sendable` (callable from any isolation); the handler
/// owns its own thread-safety (e.g. wrap `os.Logger`, which is already thread-safe).
public typealias ReduxLogHandler<S, A> = @Sendable (ReduxLog<S, A>) -> Void
where S: ReduxState, A: ReduxAction
