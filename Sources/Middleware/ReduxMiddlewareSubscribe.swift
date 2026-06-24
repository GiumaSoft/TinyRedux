//


import Foundation


/// A subscribe handle bound to the middleware's originating action, surfaced via
/// ``ReduxMiddlewareContext/args``. Lets a caller register State→Action subscriptions
/// without re-passing the origin each time (the worker binds it for you).
public struct ReduxMiddlewareSubscribe<S, A>: Sendable
where S: ReduxState, A: ReduxAction
{
  let origin: A
  let register: ReduxRegisterSubscription<S, A>

  /// Registers a subscription: when `condition(state)` turns true, dispatch `then(state)`.
  /// Returns the id (for `unregister`).
  @MainActor
  @discardableResult
  public func callAsFunction(id: String = UUID().uuidString,
                             when condition: @escaping ReduxSubscriptionPredicate<S>,
                             then action: @escaping ReduxSubscriptionHandler<S, A>) -> String
  {
    register(id, origin, condition, action)
    return id
  }

  /// Convenience: the reaction ignores the state and yields a fixed action.
  @MainActor
  @discardableResult
  public func callAsFunction(id: String = UUID().uuidString,
                             when condition: @escaping ReduxSubscriptionPredicate<S>,
                             then action: @escaping @MainActor @Sendable () -> A) -> String
  {
    register(id, origin, condition) { _ in action() }
    return id
  }
}
