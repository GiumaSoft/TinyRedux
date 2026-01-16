// swift-tools-version: 6.0


import Foundation


extension Store {
  /// Returns a shared Store instance for the given pipeline, optionally overriding the existing
  /// one; overriding while a dispatcher is active is unsafe and can crash by design at runtime
  /// only. Creates a store with the given state, middleware chain, and reducers.
  /// - Warning: Overriding while a dispatcher is active can crash by design.
  /// - Parameters:
  ///   - override: Only use `override: true` in controlled scenarios (e.g., tests or app
  ///     bootstrap).
  ///   - initialState: The initial state of the store.
  ///   - middlewares: Middleware applied in the provided order.
  ///   - resolvers: Resolver chain invoked on middleware errors.
  ///   - reducers: Reducers applied in the provided order.
  ///   - onLog: Used to log middleware and reducer processing action and performance.
  public static func sharedInstance(
    override shouldOverride: Bool = false,
    initialState: S,
    middlewares: [Middleware<S, A>],
    resolvers: [Resolver<S, A>],
    reducers: [Reducer<S, A>],
    onLog: ((Store.Log) -> Void)? = nil
  ) -> Store<S, A> {

    Singleton.getInstance(override: shouldOverride) {
      Self.init(
        initialState: initialState,
        middlewares: middlewares,
        resolvers: resolvers,
        reducers: reducers,
        onLog: onLog
      )
    }
  }
}
