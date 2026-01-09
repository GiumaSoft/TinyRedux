//


import Foundation


/// Callable wrapper that exposes the middleware subscription registration as a
/// value that can be destructured from `MiddlewareContext.args`. Uses a method
/// (not a stored closure) so `@escaping` propagates correctly to the inner
/// registry call site.
@MainActor
public struct MiddlewareSubscribe<S: ReduxState, A: ReduxAction>: Sendable {

  /// Origin action captured at the time the context was built.
  private let origin: A

  /// Forward to the Worker registry. Stored with `@escaping` predicate/handler
  /// so calls from this struct's methods satisfy the escaping contract.
  private let register: @MainActor @Sendable (
    _ id: String,
    _ origin: A,
    _ when: @escaping SubscriptionPredicate<S>,
    _ then: @escaping SubscriptionHandler<S, A>
  ) -> Void

  init(
    origin: A,
    register: @escaping @MainActor @Sendable (
      String,
      A,
      @escaping SubscriptionPredicate<S>,
      @escaping SubscriptionHandler<S, A>
    ) -> Void
  ) {
    self.origin = origin
    self.register = register
  }

  /// Registers a one-shot subscription with a state-aware action builder.
  @discardableResult
  public func callAsFunction(
    id: String = UUID().uuidString,
    when: @escaping SubscriptionPredicate<S>,
    then: @escaping SubscriptionHandler<S, A>
  ) -> String {
    register(id, origin, when, then)

    return id
  }

  /// Registers a one-shot subscription with a state-less action builder.
  @discardableResult
  public func callAsFunction(
    id: String = UUID().uuidString,
    when: @escaping SubscriptionPredicate<S>,
    then: @escaping @MainActor @Sendable () -> A
  ) -> String {
    register(id, origin, when) { _ in then() }

    return id
  }
}
