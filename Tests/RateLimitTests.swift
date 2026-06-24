//
//  ReduxDispatchRateLimit: opt-in per-dispatch gating at the dispatcher. `.none` admits all;
//  `.limit(N)` caps pending per id; `.throttle(T)` admits one per window (leading edge).
//

import Testing
import Foundation
@testable import TinyRedux


@MainActor
@Test
func rate_none_admitsAll() async
{
  let store = ReduxStore(initialState: AppState(), reducers: [mainReducer])

  for _ in 0..<5 { store.dispatch(.increment) }
  await waitUntil { store.counter == 5 }

  #expect(store.counter == 5)                // default: nothing dropped
}


@MainActor
@Test
func rate_throttle_dropsWithinWindow() async
{
  let store = ReduxStore(initialState: AppState(), reducers: [mainReducer])

  for _ in 0..<5 { store.dispatch(.increment, rate: .throttle(.seconds(10))) }
  for _ in 0..<200 { await Task.yield() }

  #expect(store.counter == 1)                // leading edge: only the first admitted
}


@MainActor
@Test
func rate_limit_capsPending() async
{
  let store = ReduxStore(initialState: AppState(), reducers: [mainReducer])

  // Synchronous burst: the reduce loop can't drain between dispatches, so `.limit(1)`
  // keeps `counts[id]` at 1 → only the first of the 5 is admitted.
  for _ in 0..<5 { store.dispatch(.increment, rate: .limit(1)) }
  for _ in 0..<200 { await Task.yield() }

  #expect(store.counter == 1)
}
