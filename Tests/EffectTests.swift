//
//  Async effects: `.task` (fire-and-forget, chain continues) and `.deferred` (suspends,
//  resumes via ReduxMiddlewareResumeExit). Errors route to the resolver.
//

import Testing
import Foundation
@testable import TinyRedux


@MainActor
@Test
func task_fireAndForget_reDispatches() async
{
  let once = Box()
  let effect = AnyReduxMiddleware<AppState, AppActions>(id: "effect")
  { context in
    if case .increment = context.action, !once.flag
    {
      once.mark()
      return .task { _ in context.dispatch(.increment) }   // result re-enters as a new action
    }
    return .next
  }

  let store = ReduxStore(initialState: AppState(),
                         reducers: [mainReducer],
                         middlewares: [effect])

  store.dispatch(.increment)
  await waitUntil { store.counter == 2 }

  #expect(store.counter == 2)                // original (+1) + task re-dispatch (+1)
}


@MainActor
@Test
func task_throw_routesToResolver_originalStillReduced() async
{
  let box = Box()
  let effect = AnyReduxMiddleware<AppState, AppActions>(id: "effect")
  { context in
    if case .increment = context.action { return .task { _ in throw TestError.boom } }
    return .next
  }
  let recover = AnyReduxResolver<AppState, AppActions>(id: "recover") { _ in box.mark(); return .exit(.done) }

  let store = ReduxStore(initialState: AppState(),
                         reducers: [mainReducer],
                         middlewares: [effect],
                         resolvers: [recover])

  store.dispatch(.increment)
  await waitUntil { box.flag }

  #expect(box.flag)                          // task throw → resolver ran
  #expect(store.counter == 1)                // fire-and-forget: .increment still reduced
}


@MainActor
@Test
func deferred_suspendsThenResumesWithReduce() async
{
  let effect = AnyReduxMiddleware<AppState, AppActions>(id: "effect")
  { context in
    if case .increment = context.action { return .deferred { _ in .exit(.reduce) } }
    return .next
  }

  let store = ReduxStore(initialState: AppState(),
                         reducers: [mainReducer],
                         middlewares: [effect])

  store.dispatch(.increment)                 // chain suspended; reducer not yet run
  await waitUntil { store.counter == 1 }

  #expect(store.counter == 1)                // resumed → reduced the original action
}


@MainActor
@Test
func deferred_resumesWithNextAs() async
{
  let effect = AnyReduxMiddleware<AppState, AppActions>(id: "effect")
  { context in
    if case .increment = context.action { return .deferred { _ in .nextAs(.decrement) } }
    return .next
  }

  let store = ReduxStore(initialState: AppState(),
                         reducers: [mainReducer],
                         middlewares: [effect])

  store.dispatch(.increment)
  await waitUntil { store.counter == -1 }

  #expect(store.counter == -1)               // resumed with .decrement → reducer
}


@MainActor
@Test
func deferred_throw_routesToResolver() async
{
  let box = Box()
  let effect = AnyReduxMiddleware<AppState, AppActions>(id: "effect")
  { context in
    if case .increment = context.action { return .deferred { _ in throw TestError.boom } }
    return .next
  }
  let recover = AnyReduxResolver<AppState, AppActions>(id: "recover") { _ in box.mark(); return .exit(.done) }

  let store = ReduxStore(initialState: AppState(),
                         reducers: [mainReducer],
                         middlewares: [effect],
                         resolvers: [recover])

  store.dispatch(.increment)
  await waitUntil { box.flag }

  #expect(box.flag)                          // deferred throw → resolver ran
  #expect(store.counter == 0)                // chain was suspended → original never reduced
}
