//
//  Teardown at deinit: in-flight effect tasks must be cancelled when the store dies, so a
//  cancel-aware body can unwind. The framework's ONLY responsibility here — whether the
//  body actually reacts to cancellation is the dev's (see `childTasks` + `deinit` cancel-all).
//

import Testing
import Foundation
@testable import TinyRedux


@MainActor
@Test
func deinit_cancelsInFlightChildTask() async
{
  let started = Box()
  let cancelled = Box()

  let effect = AnyReduxMiddleware<AppState, AppActions>(id: "effect")
  { context in
    if case .increment = context.action
    {
      return .task
      { _ in
        started.mark()
        do { try await Task.sleep(for: .seconds(60)) }   // suspends; cancel-aware
        catch is CancellationError { cancelled.mark() }
      }
    }
    return .next
  }

  var store: ReduxStore<AppState, AppActions>? =
    ReduxStore(initialState: AppState(), reducers: [mainReducer], middlewares: [effect])

  store?.dispatch(.increment)
  await waitUntil { started.flag }            // effect is in flight, parked in sleep
  #expect(started.flag)
  #expect(!cancelled.flag)                    // still running — nothing cancelled yet

  store = nil                                 // release store → Worker.deinit → cancel child tasks
  await waitUntil { cancelled.flag }          // the sleep threw CancellationError

  #expect(cancelled.flag)
}
