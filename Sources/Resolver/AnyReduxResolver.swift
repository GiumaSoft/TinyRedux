//


import Foundation


/// AnyReduxResolver
///
/// Type-erased ``ReduxResolver`` stored as a closure. Holds heterogeneous resolvers in one
/// array, and — via the `moduleMap:` init — lifts a module-local resolver into the central
/// `S`/`A` space, reusing the SAME ``ReduxModuleMap`` as the reducer/middleware.
public struct AnyReduxResolver<S, A>: ReduxResolver
where S: ReduxState, A: ReduxAction
{
  /// A stable identifier for logging and lift.
  public let id: String

  /// The resolving closure.
  let handler: ReduxResolveHandler<S, A>

  /// Creates a type-erased resolver from a closure.
  public init(id: String,
              run handler: @escaping ReduxResolveHandler<S, A>)
  {
    self.id = id
    self.handler = handler
  }

  /// Wraps an existing ``ReduxResolver`` conformer via type erasure.
  public init<R>(_ resolver: R)
  where R: ReduxResolver, R.S == S, R.A == A
  {
    self.id = resolver.id
    self.handler = { context in resolver.run(context) }
  }

  @MainActor
  public func run(_ context: ReduxResolverContext<S, A>) -> ReduxResolverExit<A>
  {
    handler(context)
  }
}


public extension AnyReduxResolver
{
  /// Lifts a module-local resolver into the central space via a ``ReduxModuleMap``.
  /// `toAction` selects the local action (`nil` → `.defaultNext`); `toState` projects the
  /// live local state; `toRootAction` re-embeds recovery actions.
  init<R>(_ resolver: R,
          moduleMap: ReduxModuleMap<R.S, R.A, S, A>)
  where R: ReduxResolver
  {
    self.id = resolver.id

    self.handler = { global in
      guard let localAction = moduleMap.toAction(global.action) else { return .defaultNext }

      let local = ReduxResolverContext<R.S, R.A>(
        moduleMap.toState(global.state),
        action: localAction,
        error: global.error,
        origin: global.origin,
        dispatch: { global.dispatch(moduleMap.toRootAction($0)) })

      switch resolver.run(local)
      {
      case .defaultNext:
        return .defaultNext
      case .exit(let target):
        switch target
        {
        case .reduce:            return .exit(.reduce)
        case .reduceAs(let la):  return .exit(.reduceAs(moduleMap.toRootAction(la)))
        case .fail(let e):       return .exit(.fail(e))
        case .done:              return .exit(.done)
        }
      }
    }
  }
}
