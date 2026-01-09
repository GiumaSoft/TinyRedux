//
//  Resolver: the error branch. Reached by a middleware `throw` or `.exit(.resolve)`.
//  Recovers (`.reduce`/`.reduceAs`), absorbs (`.done`), or fails (default / `.fail`).
//

import Testing
import Foundation
@testable import TinyRedux


@MainActor
@Test
func resolver_recoversWithReduceAs() async
{
  let thrower = AnyMiddleware<AppState, AppActions>(id: "thrower")
  { context in
    if case .increment = context.action { throw TestError.boom }
    return .next
  }
  let recover = AnyResolver<AppState, AppActions>(id: "recover") { _ in .exit(.reduceAs(.decrement)) }

  let store = ReduxStore(initialState: AppState(),
                         reducers: [mainReducer],
                         middlewares: [thrower],
                         resolvers: [recover])

  store.dispatch(.increment)                 // throws → never reduced
  await waitUntil { store.counter == -1 }

  #expect(store.counter == -1)               // resolver reduced .decrement instead
}


@MainActor
@Test
func resolver_recoversWithReduceOriginalAction() async
{
  let thrower = AnyMiddleware<AppState, AppActions>(id: "thrower")
  { context in
    if case .increment = context.action { throw TestError.boom }
    return .next
  }
  let recover = AnyResolver<AppState, AppActions>(id: "recover") { _ in .exit(.reduce) }

  let store = ReduxStore(initialState: AppState(),
                         reducers: [mainReducer],
                         middlewares: [thrower],
                         resolvers: [recover])

  store.dispatch(.increment)
  await waitUntil { store.counter == 1 }

  #expect(store.counter == 1)                // resolver reduced the ORIGINAL .increment
}


@MainActor
@Test
func resolver_unhandledLeavesStateUnchanged() async
{
  let thrower = AnyMiddleware<AppState, AppActions>(id: "thrower")
  { context in
    if case .increment = context.action { throw TestError.boom }
    return .next
  }
  let passing = AnyResolver<AppState, AppActions>(id: "passing") { _ in .defaultNext }

  let store = ReduxStore(initialState: AppState(),
                         reducers: [mainReducer],
                         middlewares: [thrower],
                         resolvers: [passing])

  store.dispatch(.increment)
  for _ in 0..<200 { await Task.yield() }

  #expect(store.counter == 0)                // not recovered → default fail → no reduce
}


@MainActor
@Test
func resolver_explicitResolveExitRoutesToResolver() async
{
  let raiser = AnyMiddleware<AppState, AppActions>(id: "raiser")
  { context in
    if case .increment = context.action { return .exit(.resolve(TestError.boom)) }
    return .next
  }
  let recover = AnyResolver<AppState, AppActions>(id: "recover") { _ in .exit(.reduceAs(.decrement)) }

  let store = ReduxStore(initialState: AppState(),
                         reducers: [mainReducer],
                         middlewares: [raiser],
                         resolvers: [recover])

  store.dispatch(.increment)                 // explicit .exit(.resolve) → resolver
  await waitUntil { store.counter == -1 }

  #expect(store.counter == -1)
}
