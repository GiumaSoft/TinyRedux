//
//  Subscriptions (State→Action): a middleware registers a predicate + reaction; the worker
//  fires the reaction (dispatch) after a reduce where the predicate holds. Lifecycle by id.
//

import Testing
import Foundation
@testable import TinyRedux


@MainActor
@Test
func subscription_firesStateToAction() async
{
  let once = Box()
  let setup = AnyMiddleware<AppState, AppActions>(id: "setup")
  { context in
    if case .increment = context.action, !once.flag
    {
      once.mark()
      context.subscribe(when: { $0.counter == 3 }) { _ in .decrement }
    }
    return .next
  }

  let store = ReduxStore(initialState: AppState(),
                         reducers: [mainReducer],
                         middlewares: [setup])

  store.dispatch(.increment)                 // 1 (subscription registered)
  store.dispatch(.increment)                 // 2
  store.dispatch(.increment)                 // 3 → predicate holds → dispatch .decrement → 2
  await waitUntil { store.counter == 2 }

  #expect(store.counter == 2)
}


@MainActor
@Test
func subscription_unsubscribeStopsReaction() async
{
  let setup = AnyMiddleware<AppState, AppActions>(id: "setup")
  { context in
    if case .increment = context.action
    {
      let id = context.subscribe(when: { $0.counter >= 1 }) { _ in .increment }
      context.unsubscribe(id: id)            // removed immediately → must never fire
    }
    return .next
  }

  let store = ReduxStore(initialState: AppState(),
                         reducers: [mainReducer],
                         middlewares: [setup])

  store.dispatch(.increment)
  for _ in 0..<200 { await Task.yield() }

  #expect(store.counter == 1)                // no runaway: the reaction was unregistered
}
