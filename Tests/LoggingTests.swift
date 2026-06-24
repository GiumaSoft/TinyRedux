//
//  Logging layer: a `@Sendable` handler receives structured `ReduxLog` events;
//  thread-safe at the sink; nothing is emitted when no handler is attached.
//

import Testing
import Foundation
@testable import TinyRedux


/// Thread-safe sink (thread-safety lives at the sink, per the design).
final class LogCollector: @unchecked Sendable
{
  private let lock = NSLock()
  private var items: [ReduxLog<AppState, AppActions>] = []

  func receive(_ log: ReduxLog<AppState, AppActions>)
  {
    lock.withLock { items.append(log) }
  }

  var all: [ReduxLog<AppState, AppActions>]
  {
    lock.withLock { items }
  }
}


@MainActor
@Test
func logging_emitsReducerEvent() async
{
  let collector = LogCollector()
  let store = ReduxStore(
    initialState: AppState(),
    reducers: [mainReducer],
    onLog: { collector.receive($0) }
  )

  store.dispatch(.increment)

  var attempts = 0
  while store.counter == 0, attempts < 1_000
  {
    await Task.yield()
    attempts += 1
  }

  let sawReducer = collector.all.contains { log in
    if case let .reducer(id, _, duration, exit) = log,
       id == "mainReducer",
       case .next = exit,
       duration >= .zero
    {
      return true
    }
    return false
  }

  #expect(store.counter == 1)
  #expect(sawReducer)            // the reducer event was delivered to the @Sendable sink
}


@MainActor
@Test
func backpressure_warnsOnHighFrequencyAction() async
{
  let collector = LogCollector()
  let store = ReduxStore(
    initialState: AppState(),
    reducers: [mainReducer],
    options: ReduxStoreOptions(pressureWindow: .seconds(10),
                          pressureThreshold: 3,
                          pressureCooldown: .zero),
    onLog: { collector.receive($0) }
  )

  for _ in 0..<5 { store.dispatch(.increment) }   // 5 of the same id within the window

  var attempts = 0
  while store.counter < 5, attempts < 1_000
  {
    await Task.yield()
    attempts += 1
  }

  let warned = collector.all.contains { log in
    if case let .highFrequencyAction(id, count, _) = log, id == "increment", count > 3
    {
      return true
    }
    return false
  }

  #expect(store.counter == 5)
  #expect(warned)                // exceeding the threshold emitted a diagnostic (no drop)
}
