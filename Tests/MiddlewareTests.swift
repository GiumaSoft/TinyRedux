//
//  ReduxMiddleware layer — INTERCEPTION ONLY: the chain runs before the reducers and
//  may pass through (.next/.defaultNext), redirect (.nextAs), or short-circuit
//  (.exit). Plus the module lift via `ReduxModuleMap`.
//

import Testing
import Foundation
@testable import TinyRedux


/// Spins the main-actor reduce loop until `predicate` holds or we give up.
@MainActor
private func settle(until predicate: () -> Bool, max attempts: Int = 1_000) async
{
  var n = 0
  while !predicate(), n < attempts
  {
    await Task.yield()
    n += 1
  }
}


@MainActor
@Test
func middleware_nextForwardsToReducer() async
{
  let passthrough = AnyReduxMiddleware<AppState, AppActions>(id: "passthrough") { _ in .next }
  let store = ReduxStore(initialState: AppState(),
                         reducers: [mainReducer],
                         middlewares: [passthrough])

  store.dispatch(.increment)
  await settle(until: { store.counter == 1 })

  #expect(store.counter == 1)   // .next let the action reach the reducer
}


@MainActor
@Test
func middleware_exitShortCircuitsReducer() async
{
  let block = AnyReduxMiddleware<AppState, AppActions>(id: "block")
  { context in
    if case .increment = context.action { return .exit(.done) }
    return .next
  }
  let store = ReduxStore(initialState: AppState(),
                         reducers: [mainReducer],
                         middlewares: [block])

  store.dispatch(.increment)
  for _ in 0..<200 { await Task.yield() }   // give the loop ample time

  #expect(store.counter == 0)   // .exit stopped the action before the reducer
}


@MainActor
@Test
func middleware_nextAsRedirects() async
{
  let redirect = AnyReduxMiddleware<AppState, AppActions>(id: "redirect")
  { context in
    if case .increment = context.action { return .nextAs(.decrement) }
    return .next
  }
  let store = ReduxStore(initialState: AppState(),
                         reducers: [mainReducer],
                         middlewares: [redirect])

  store.dispatch(.increment)            // redirected to .decrement
  await settle(until: { store.counter == -1 })

  #expect(store.counter == -1)
}


@MainActor
@Test
func middleware_runInDeclarationOrder() async
{
  // m1 redirects .increment → .decrement; m2 must then SEE .decrement (proves order).
  let m1 = AnyReduxMiddleware<AppState, AppActions>(id: "m1")
  { context in
    if case .increment = context.action { return .nextAs(.decrement) }
    return .next
  }

  let box = SeenBox()
  let m2 = AnyReduxMiddleware<AppState, AppActions>(id: "m2")
  { context in
    box.record(context.action)
    return .next
  }

  let store = ReduxStore(initialState: AppState(),
                         reducers: [mainReducer],
                         middlewares: [m1, m2])

  store.dispatch(.increment)
  await settle(until: { store.counter == -1 })

  #expect(store.counter == -1)
  #expect(box.last == "decrement")   // m2 saw the action AFTER m1's redirect
}


@MainActor
@Test
func middleware_liftSeesLocalActionAndRedirects() async
{
  // A module-local middleware over Counter; redirect local .increment → .decrement.
  let local = AnyReduxMiddleware<CounterModuleState, CounterModuleActions>(id: "localCounter")
  { context in
    if case .increment = context.action { return .nextAs(.decrement) }
    return .next
  }
  let lifted = AnyReduxMiddleware(local, moduleMap: DemoModule.counter)

  let store = ReduxStore(initialState: DemoAppState(),
                         reducers: [AnyReduxReducer(counterReducer, moduleMap: DemoModule.counter)],
                         middlewares: [lifted])

  store.dispatch(.counter(.increment))   // lifted: extracted, redirected, re-embedded
  await settle(until: { store.state.counter.count == -1 })

  #expect(store.state.counter.count == -1)
}


@MainActor
@Test
func middleware_liftSkipsForeignAction() async
{
  // Lifted Counter middleware that would .exit on its local action — but a foreign
  // (user) action must pass straight through (.defaultNext), reaching the reducer.
  let local = AnyReduxMiddleware<CounterModuleState, CounterModuleActions>(id: "localCounter")
  { _ in .exit(.done) }
  let lifted = AnyReduxMiddleware(local, moduleMap: DemoModule.counter)

  let store = ReduxStore(initialState: DemoAppState(),
                         reducers: [AnyReduxReducer(userReducer, moduleMap: DemoModule.user)],
                         middlewares: [lifted])

  store.dispatch(.user(.setFirstName("Mario")))
  await settle(until: { store.state.user.firstName == "Mario" })

  #expect(store.state.user.firstName == "Mario")   // foreign action not blocked
}


// ════════════════════════════════════════════════════════════════════════════
// EXPANDED COVERAGE — added cases
// ════════════════════════════════════════════════════════════════════════════


@MainActor
@Test
func middleware_defaultNextForwardsToReducer() async
{
  // `.defaultNext` ("not mine", pass-through) must still reach the reducer, exactly
  // like `.next` — only the logging classification differs.
  let passthrough = AnyReduxMiddleware<AppState, AppActions>(id: "defaultNext") { _ in .defaultNext }
  let store = ReduxStore(initialState: AppState(),
                         reducers: [mainReducer],
                         middlewares: [passthrough])

  store.dispatch(.increment)
  await settle(until: { store.counter == 1 })

  #expect(store.counter == 1)
}


@MainActor
@Test
func middleware_emptyArrayBehavesLikeNoMiddleware() async
{
  // An empty middlewares array short-circuits to the reducer stage directly.
  let store = ReduxStore(initialState: AppState(),
                         reducers: [mainReducer],
                         middlewares: [])

  store.dispatch(.increment)
  await settle(until: { store.counter == 1 })

  #expect(store.counter == 1)
}


@MainActor
@Test
func middleware_dispatchReentersPipeline() async
{
  // A middleware that dispatches a NEW action: it re-enters the full pipeline and
  // is reduced (synchronous effect-style loop via `dispatch`, no `.task`). One-shot
  // guard keeps it from looping forever.
  let once = OneShot()
  let reenter = AnyReduxMiddleware<AppState, AppActions>(id: "reenter")
  { context in
    if case .increment = context.action, once.fireOnce()
    {
      context.dispatch(.increment)   // re-enters: second increment is reduced too
    }
    return .next
  }
  let store = ReduxStore(initialState: AppState(),
                         reducers: [mainReducer],
                         middlewares: [reenter])

  store.dispatch(.increment)
  await settle(until: { store.counter == 2 })

  #expect(store.counter == 2)   // original + re-dispatched, both reduced
}


@MainActor
@Test
func middleware_earlyExitSkipsLaterMiddlewareAndReducers() async
{
  // m1 exits on .increment → m2 must never see the action AND the reducer is skipped.
  let m1 = AnyReduxMiddleware<AppState, AppActions>(id: "m1exit")
  { context in
    if case .increment = context.action { return .exit(.done) }
    return .next
  }

  let box = SeenBox()
  let m2 = AnyReduxMiddleware<AppState, AppActions>(id: "m2spy")
  { context in
    box.record(context.action)
    return .next
  }

  let store = ReduxStore(initialState: AppState(),
                         reducers: [mainReducer],
                         middlewares: [m1, m2])

  store.dispatch(.increment)
  for _ in 0..<200 { await Task.yield() }

  #expect(store.counter == 0)    // reducer skipped
  #expect(box.last == nil)       // m2 never reached
}


@MainActor
@Test
func middleware_nextAsChainsAcrossTwoMiddlewares() async
{
  // m1: .increment → .nextAs(.decrement); m2 SEES .decrement and itself
  // .nextAs(.increment) → the reducer sees the final .increment. Both transforms
  // compound across the chain.
  let m1 = AnyReduxMiddleware<AppState, AppActions>(id: "m1redirect")
  { context in
    if case .increment = context.action { return .nextAs(.decrement) }
    return .next
  }

  let box = SeenBox()
  let m2 = AnyReduxMiddleware<AppState, AppActions>(id: "m2redirect")
  { context in
    box.record(context.action)
    if case .decrement = context.action { return .nextAs(.increment) }
    return .next
  }

  let store = ReduxStore(initialState: AppState(),
                         reducers: [mainReducer],
                         middlewares: [m1, m2])

  store.dispatch(.increment)
  await settle(until: { store.counter == 1 })

  #expect(store.counter == 1)        // m2's .nextAs(.increment) reached the reducer
  #expect(box.last == "decrement")   // m2 saw m1's redirect, not the original
}


@MainActor
@Test
func middleware_readsStateForDecision() async
{
  // A middleware reading `context.state` (read-only) to branch its control flow.
  let gate = AnyReduxMiddleware<AppState, AppActions>(id: "gate")
  { context in
    if context.state.counter >= 5 { return .exit(.done) }   // refuse once the ceiling is hit
    return .next
  }
  let store = ReduxStore(initialState: AppState(counter: 5, auth: AuthModuleState()),
                         reducers: [mainReducer],
                         middlewares: [gate])

  store.dispatch(.increment)
  for _ in 0..<200 { await Task.yield() }

  #expect(store.counter == 5)   // state-driven .exit blocked the increment
}


@MainActor
@Test
func middleware_liftDispatchReembedsLocalAction() async
{
  // The lifted local middleware dispatches a LOCAL action; the lift must re-embed it
  // to the root (toRootAction on the DISPATCH path) so it is reduced. One-shot guard.
  let once = OneShot()
  let local = AnyReduxMiddleware<CounterModuleState, CounterModuleActions>(id: "localReenter")
  { context in
    if case .increment = context.action, once.fireOnce()
    {
      context.dispatch(.increment)   // local → re-embedded to .counter(.increment)
    }
    return .next
  }
  let lifted = AnyReduxMiddleware(local, moduleMap: DemoModule.counter)

  let store = ReduxStore(initialState: DemoAppState(),
                         reducers: [AnyReduxReducer(counterReducer, moduleMap: DemoModule.counter)],
                         middlewares: [lifted])

  store.dispatch(.counter(.increment))
  await settle(until: { store.state.counter.count == 2 })

  #expect(store.state.counter.count == 2)   // dispatched local action re-embedded + reduced
}


@MainActor
@Test
func middleware_liftExitBlocksOnlyOwnModule() async
{
  // A lifted Counter middleware that .exit on its own action must block ONLY the
  // counter reducer — a foreign (user) action still flows through and is reduced.
  let local = AnyReduxMiddleware<CounterModuleState, CounterModuleActions>(id: "blockCounter")
  { _ in .exit(.done) }
  let lifted = AnyReduxMiddleware(local, moduleMap: DemoModule.counter)

  let store = ReduxStore(initialState: DemoAppState(),
                         reducers: [AnyReduxReducer(counterReducer, moduleMap: DemoModule.counter),
                                    AnyReduxReducer(userReducer, moduleMap: DemoModule.user)],
                         middlewares: [lifted])

  store.dispatch(.counter(.increment))               // own module → blocked
  store.dispatch(.user(.setFirstName("Mario")))      // foreign → passes
  await settle(until: { store.state.user.firstName == "Mario" })

  #expect(store.state.counter.count == 0)            // own action blocked
  #expect(store.state.user.firstName == "Mario")     // foreign action reduced
}


/// Fires `true` exactly once — guards re-dispatching middlewares from looping.
private final class OneShot: @unchecked Sendable
{
  private let lock = NSLock()
  private var fired = false

  func fireOnce() -> Bool { lock.withLock { if fired { return false }; fired = true; return true } }
}


/// Thread-safe recorder for the order test.
private final class SeenBox: @unchecked Sendable
{
  private let lock = NSLock()
  private var actions: [String] = []

  func record(_ action: AppActions) { lock.withLock { actions.append(action.id) } }
  var last: String? { lock.withLock { actions.last } }
}
