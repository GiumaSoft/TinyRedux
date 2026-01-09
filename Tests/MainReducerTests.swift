//


import Testing
import Observation
@testable import TinyRedux


@MainActor
@Test
func incrementUpdatesCounter() async
{
  let store = ReduxStore(initialState: AppState(), reducers: [mainReducer])

  withObservationTracking {
    _ = store.counter
  } onChange: {
    print("observation triggered: counter is about to change")
  }

  store.dispatch(.increment)

  // dispatch is fire-and-forget: yield until the worker loop reduces the action.
  var attempts = 0
  while store.counter == 0, attempts < 1_000 {
    await Task.yield()
    attempts += 1
  }

  print("result: counter = \(store.counter)")
  #expect(store.counter == 1)
}
