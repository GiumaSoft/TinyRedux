//


import Foundation


/// MiddlewareContext
///
/// Bundles the read-only state, action, and dispatch capability for a middleware step.
@MainActor
public struct MiddlewareContext<S: ReduxState, A: ReduxAction> : Sendable {

  /// Read-only view of the current state.
  public let state: S.ReadOnly

  /// Enqueues one or more actions for future dispatch.
  nonisolated
  public let dispatch: ReduxDispatch<A>

  /// The action being processed.
  public let action: A

  /// Internal channel to register a subscription into the Worker registry.
  /// Captured by the Worker at fold time with the owning `middleware.id`.
  let register: @MainActor @Sendable (
    _ id: String,
    _ origin: A,
    _ when: @escaping SubscriptionPredicate<S>,
    _ then: @escaping SubscriptionHandler<S, A>
  ) -> Void

  /// Internal channel to remove a subscription from the Worker registry by `id`.
  let unregister: @MainActor @Sendable (_ id: String) -> Void

  /// Creates a context. Internal — only the Store pipeline builds these.
  init(
    state: S.ReadOnly,
    dispatch: @escaping ReduxDispatch<A>,
    action: A,
    register: @escaping @MainActor @Sendable (String, A, @escaping SubscriptionPredicate<S>, @escaping SubscriptionHandler<S, A>) -> Void,
    unregister: @escaping @MainActor @Sendable (String) -> Void
  ) {
    self.state = state
    self.dispatch = dispatch
    self.action = action
    self.register = register
    self.unregister = unregister
  }

  /// Destructured tuple: (state, dispatch, action, subscribe, unsubscribe).
  /// `subscribe` is a callable wrapper around `register` (captures origin action);
  /// `unsubscribe` forwards to `unregister`.
  public var args: MiddlewareArgs<S, A> {
    (
      state,
      dispatch,
      action,
      MiddlewareSubscribe(origin: action, register: register),
      unregister
    )
  }
}


extension MiddlewareContext {

  /// Registers a one-shot state watcher. When `when` becomes `true` at a post-reducer
  /// evaluation, the framework builds the action via `then(readOnly)` and enqueues it
  /// into the FIFO; the subscription is then removed from the registry. If an entry
  /// with the same `id` already exists, it is replaced (dedupe-replace).
  /// - Parameters:
  ///   - id: Caller-provided identifier. Defaults to a fresh `UUID().uuidString`. Use a stable id to enable dedupe/unsubscribe.
  ///   - condition: Predicate on read-only state. Evaluated post-reducer.
  ///   - action: Builder invoked at match time to produce the dispatched action.
  /// - Returns: The `id` used for registration (useful when relying on the default UUID).
  @discardableResult
  public func subscribe(
    id: String = UUID().uuidString,
    when condition: @escaping SubscriptionPredicate<S>,
    then action: @escaping SubscriptionHandler<S, A>
  ) -> String {
    register(id, self.action, condition, action)

    return id
  }

  /// Overload where `then` does not need the read-only state. Convenience for
  /// subscriptions whose dispatched action is known statically at registration time.
  /// - Parameters:
  ///   - id: Caller-provided identifier. Defaults to a fresh `UUID().uuidString`.
  ///   - condition: Predicate on read-only state. Evaluated post-reducer.
  ///   - action: Builder invoked at match time. Does not receive state.
  /// - Returns: The `id` used for registration.
  @discardableResult
  public func subscribe(
    id: String = UUID().uuidString,
    when condition: @escaping SubscriptionPredicate<S>,
    then action: @escaping @MainActor @Sendable () -> A
  ) -> String {
    register(id, self.action, condition) { _ in action() }

    return id
  }

  /// Removes the subscription with the given `id` from the registry immediately.
  /// No-op (silent) if `id` is not present.
  public func unsubscribe(id: String) {
    unregister(id)
  }
}
