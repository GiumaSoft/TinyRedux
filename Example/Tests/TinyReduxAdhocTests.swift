//

import Synchronization
import Testing
@testable import Example
@testable import TinyRedux


private struct _WaitSnapshot: ReduxStateSnapshot {
  typealias S = AppState
  @MainActor init(state: AppState.ReadOnly) {}
}


@MainActor
struct TinyReduxAdhocTests {
  @Test func sample03ReducerUpdatesHeader() async {
    let state = AppState()
    let store = Store(
      initialState: state,
      middlewares: [],
      resolvers: [AnyResolver(id: "resolver") { context in
        Issue.record("Unexpected error: \(context.error)")
        return .exit(.failure(context.error))
      }],
      reducers: [sample03Reducer]
    )
    let newHeader = "Test Header"

    _ = await store.dispatch(.setHeader(newHeader), snapshot: _WaitSnapshot.self)

    #expect(state.header == newHeader)
  }

  @Test func completeEmitsReducerLog() async {
    let state = AppState()
    let logs = Mutex<[Store<AppState, AppActions>.Log]>([])
    let store = Store(
      initialState: state,
      middlewares: [],
      resolvers: [AnyResolver(id: "resolver") { context in
        Issue.record("Unexpected error: \(context.error)")
        return .exit(.failure(context.error))
      }],
      reducers: [sample03Reducer],
      onLog: { message in
        logs.withLock { $0.append(message) }
      }
    )
    let header = "Log Header"

    _ = await store.dispatch(.setHeader(header), snapshot: _WaitSnapshot.self)

    let hasReducerLog = logs.withLock { entries in
      entries.contains { log in
        guard case let .reducer(reducerId, action, _, exit) = log else {
          return false
        }
        guard case let .setHeader(registeredHeader) = action else {
          return false
        }
        return reducerId == "sample03Reducer" && registeredHeader == header && exit == .next
      }
    }
    #expect(hasReducerLog, "Expected reducer to emit log with .next exit when onLog is enabled.")
  }
}
