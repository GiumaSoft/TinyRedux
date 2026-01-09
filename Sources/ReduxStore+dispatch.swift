//


import Foundation


extension ReduxStore {
  /// Publishes one or more actions for asynchronous processing. Thread-safe, any context.
  nonisolated
  public func dispatch(_ actions: A...)
  {
    for action in actions
    {
      worker.dispatch(action)
    }
  }

  /// Publishes a single action with an opt-in ``DispatchRateLimit`` (e.g. `.throttle`,
  /// `.limit`) for high-frequency sources. Thread-safe, any context.
  nonisolated
  public func dispatch(_ action: A, rate: DispatchRateLimit)
  {
    worker.dispatch(action, rate: rate)
  }
}
