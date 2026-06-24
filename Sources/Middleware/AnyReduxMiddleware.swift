//


import Foundation


/// AnyReduxMiddleware
///
/// Type-erased ``ReduxMiddleware`` stored as a closure. Holds heterogeneous middlewares in
/// one array, and — via the `map:` init — lifts a module-local `LS`/`LA` middleware into
/// the central `S`/`A` space, reusing the SAME ``ReduxModuleMap`` as the reducer/slice.
public struct AnyReduxMiddleware<S, A>: ReduxMiddleware
where S: ReduxState, A: ReduxAction
{
  /// A stable identifier for logging and lift.
  public let id: String

  /// The intercepting closure.
  let handler: ReduxMiddlewareHandler<S, A>

  /// Creates a type-erased middleware from a closure.
  public init(id: String,
              run handler: @escaping ReduxMiddlewareHandler<S, A>)
  {
    self.id = id
    self.handler = handler
  }

  /// Wraps an existing ``ReduxMiddleware`` conformer via type erasure.
  public init<M>(_ middleware: M)
  where M: ReduxMiddleware, M.S == S, M.A == A
  {
    self.id = middleware.id
    self.handler = { context in try middleware.run(context) }
  }

  @MainActor
  public func run(_ context: ReduxMiddlewareContext<S, A>) throws -> ReduxMiddlewareExit<S, A>
  {
    try handler(context)
  }
}


public extension AnyReduxMiddleware
{
  /// Lifts a module-local middleware into the central space via a ``ReduxModuleMap``.
  ///
  /// `toAction` selects the local action (`nil` → `.defaultNext`); `toState` projects the
  /// live local state ONCE (retained, so a mapped `ReadOnly` can't dangle); `toRootAction`
  /// re-embeds dispatched / redirected / resumed actions. Effect bodies read the projected
  /// local `readOnly` (hopped to the main actor).
  init<M>(_ middleware: M,
           moduleMap: ReduxModuleMap<M.S, M.A, S, A>)
  where M: ReduxMiddleware
  {
    self.id = middleware.id

    // local exit/resume → global, reused by the sync switch and the deferred resume.
    let liftTarget: @Sendable (ReduxMiddlewareExitTarget<M.A>) -> ReduxMiddlewareExitTarget<A> = { target in
      switch target
      {
        case .reduce:            return .reduce
        case .reduceAs(let la):  return .reduceAs(moduleMap.toRootAction(la))
        case .resolve(let e):    return .resolve(e)
        case .done:              return .done
      }
    }
    let liftResume: @Sendable (ReduxMiddlewareResumeExit<M.A>) -> ReduxMiddlewareResumeExit<A> = { resume in
      switch resume
      {
      case .next:            return .next
      case .nextAs(let la):  return .nextAs(moduleMap.toRootAction(la))
      case .exit(let t):     return .exit(liftTarget(t))
      }
    }

    self.handler = { global in
      guard let localAction = moduleMap.toAction(global.action) else { return .defaultNext }

      let localState = moduleMap.toState(global.state)
      let local = ReduxMiddlewareContext<M.S, M.A>(
        localState,
        dispatch: { global.dispatch(moduleMap.toRootAction($0)) },
        action: localAction,
        register: { id, registeredBy, when, then in
          // predicate/handler read the captured local state, fresh on each evaluation.
          global.register( id, moduleMap.toRootAction(registeredBy),
                           { _ in when(localState.readOnly) },
                           { _ in moduleMap.toRootAction(then(localState.readOnly)) } )
        },
        unregister: global.unregister
      )

      switch try middleware.run(local)
      {
        case .next:            return .next
        case .defaultNext:     return .defaultNext
        case .nextAs(let la):  return .nextAs(moduleMap.toRootAction(la))
        case .exit(let t):     return .exit(liftTarget(t))
        case .task(let body):  return .task { _ in try await body(localState.readOnly) }
        case .deferred(let h): return .deferred { _ in liftResume(try await h(localState.readOnly)) }
      }
    }
  }
}
