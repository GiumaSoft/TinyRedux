//


import Foundation


/// Subscription
///
/// A registry entry for the State→Action mechanism: when `when(state)` turns true on a
/// state change, the worker dispatches `then(state)`. Registered by a middleware via
/// ``MiddlewareContext/subscribe(id:when:then:)``, removed by `id`.
///
/// NO `generation` (rejected with the flush/suspend cluster) — lifecycle is purely by id.
/// `registeredBy` records the action that registered it (tracing).
public struct Subscription<S, A>: Sendable, Identifiable
where S: ReduxState, A: ReduxAction
{
  /// Stable id (caller-provided or generated); the key for `unsubscribe`.
  public let id: String

  /// The id of the middleware that registered this subscription (tracing).
  public let origin: String

  /// The action during which this subscription was registered (tracing).
  public let registeredBy: A

  /// Fires the reaction when it turns true.
  public let when: SubscriptionPredicate<S>

  /// Produces the action to dispatch when `when` fires.
  public let then: SubscriptionHandler<S, A>

  init(id: String,
       origin: String,
       registeredBy: A,
       when: @escaping SubscriptionPredicate<S>,
       then: @escaping SubscriptionHandler<S, A>)
  {
    self.id = id
    self.origin = origin
    self.registeredBy = registeredBy
    self.when = when
    self.then = then
  }
}
