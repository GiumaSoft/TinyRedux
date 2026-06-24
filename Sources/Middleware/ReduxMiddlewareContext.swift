//


import Foundation


/// ReduxMiddlewareContext
///
/// What a ``ReduxMiddleware`` receives for one action: the live `state`, a `dispatch` to
/// publish NEW actions, the `action` being intercepted, and the subscription registry
/// hooks (`subscribe`/`unsubscribe`, State→Action).
///
/// Like ``ReduxReducerContext`` it carries the live `state`, but a middleware only READS
/// it (the reducer is the sole writer); it influences state only via dispatch/subscriptions.
/// The module lift projects the local state from `state` via ``ReduxModuleMap/toState``.
public struct ReduxMiddlewareContext<S, A>: Sendable
where S: ReduxState, A: ReduxAction
{
  /// The live state — read-only by convention (do NOT mutate from a middleware).
  public let state: S

  /// Publishes one or more actions for asynchronous processing. Thread-safe.
  public let dispatch: @Sendable (A) -> Void

  /// The action being intercepted.
  public let action: A

  /// Registers a subscription (id, origin, predicate, handler). Provided by the worker.
  let register: ReduxRegisterSubscription<S, A>

  /// Removes a subscription by id. Provided by the worker.
  let unregister: ReduxUnregisterSubscription

  init(_ state: S,
       dispatch: @escaping @Sendable (A) -> Void,
       action: A,
       register: @escaping ReduxRegisterSubscription<S, A>,
       unregister: @escaping ReduxUnregisterSubscription)
  {
    self.state = state
    self.dispatch = dispatch
    self.action = action
    self.register = register
    self.unregister = unregister
  }

  /// Destructured members: `(state, dispatch, action, subscribe, unsubscribe)`.
  public var args: ReduxMiddlewareArgs<S, A>
  {
    ( state,
      dispatch,
      action,
      ReduxMiddlewareSubscribe(origin: action, register: register),
      unregister )
  }
}


public extension ReduxMiddlewareContext
{
  /// Registers a State→Action subscription: when `condition(state)` turns true, the
  /// worker dispatches `action(state)` **once** and removes it (fire-once). Returns the
  /// id, usable to cancel it early via `unsubscribe` before it fires.
  @MainActor
  @discardableResult
  func subscribe(id: String = UUID().uuidString,
                 when condition: @escaping ReduxSubscriptionPredicate<S>,
                 then action: @escaping ReduxSubscriptionHandler<S, A>) -> String
  {
    register(id, self.action, condition, action)
    return id
  }

  /// Convenience: the reaction ignores the state and yields a fixed action.
  @MainActor
  @discardableResult
  func subscribe(id: String = UUID().uuidString,
                 when condition: @escaping ReduxSubscriptionPredicate<S>,
                 then action: @escaping @MainActor @Sendable () -> A) -> String
  {
    register(id, self.action, condition) { _ in action() }
    return id
  }

  /// Removes a previously-registered subscription by id.
  @MainActor
  func unsubscribe(id: String)
  {
    unregister(id)
  }
}
