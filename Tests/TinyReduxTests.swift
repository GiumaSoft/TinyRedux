//


import Foundation
import SwiftUI
import Testing
@testable
import TinyRedux


// MARK: - Test Types

@MainActor
@Observable
final class AppState: ReduxState {
  @MainActor
  final class ReadOnlyAppState: ReduxReadOnlyState {
    private unowned let state: AppState
    init(_ state: AppState) {
      self.state = state
    }

    var counter: Int { state.counter }
  }

  var counter: Int

  @ObservationIgnored
  lazy var readOnly = ReadOnlyAppState(self)

  init(counter: Int) {
    self.counter = counter
  }

  convenience init() {
    self.init(counter: 0)
  }
}

@CaseID
enum AppActions: ReduxAction {
  case inc(Int)
  case dec(Int)

  var description: String {
    switch self {
    case .inc: ".inc"
    case .dec: ".dec"
    }
  }

  var debugDescription: String {
    switch self {
    case .inc(let value): ".inc by \(value) step."
    default: description
    }
  }
}

/// Thread-safe test helper for tracking values across @Sendable closures.
final class TestLog<T: Sendable>: @unchecked Sendable {
  private let lock = NSLock()
  private var entries: [T] = []

  func append(_ entry: T) {
    lock.withLock { entries.append(entry) }
  }

  var values: [T] {
    lock.withLock { entries }
  }

  var count: Int {
    lock.withLock { entries.count }
  }
}


// MARK: - Helpers

@MainActor
private func makeStore(
  middlewares: [AnyMiddleware<AppState, AppActions>] = [],
  resolvers: [AnyResolver<AppState, AppActions>] = [],
  reducers: [AnyReducer<AppState, AppActions>] = [],
  counter: Int = 0,
  onLog: (@Sendable (Store<AppState, AppActions>.Log) -> Void)? = nil
) -> Store<AppState, AppActions> {
  Store(
    initialState: AppState(counter: counter),
    middlewares: middlewares,
    resolvers: resolvers,
    reducers: reducers,
    onLog: onLog
  )
}

@MainActor
private func awaitState(
  _ store: Store<AppState, AppActions>,
  counter expected: Int
) async {
  while store.state.counter != expected {
    await withCheckedContinuation { continuation in
      withObservationTracking {
        _ = store.state.counter
      } onChange: {
        continuation.resume()
      }
    }
  }
}

private let counterReducer = AnyReducer<AppState, AppActions>(id: "counter") { context in
  let (state, action) = context.args

  switch action {
  case .inc(let value): state.counter += value
  case .dec(let value): state.counter -= value
  }
}


// MARK: - CaseID Macro

struct CaseIDMacroTests {

  @Test("@CaseID generates id from case name")
  func caseIDGeneratesID() {
    #expect(AppActions.inc(1).id == "inc")
    #expect(AppActions.dec(1).id == "dec")
  }

  @Test("@CaseID id is stable regardless of associated value")
  func caseIDIgnoresAssociatedValue() {
    #expect(AppActions.inc(1).id == AppActions.inc(999).id)
    #expect(AppActions.dec(0).id == AppActions.dec(42).id)
  }

  @Test("@CaseID id is unique per case")
  func caseIDIsUnique() {
    #expect(AppActions.inc(0).id != AppActions.dec(0).id)
  }
}


// MARK: - Reducer

struct ReducerTests {

  @Test("reducer increments counter")
  @MainActor
  func increment() async {
    let store = makeStore(reducers: [counterReducer])
    store.dispatch(.inc(5))
    await awaitState(store, counter: 5)
    #expect(store.state.counter == 5)
  }

  @Test("reducer decrements counter")
  @MainActor
  func decrement() async {
    let store = makeStore(reducers: [counterReducer], counter: 10)
    store.dispatch(.dec(3))
    await awaitState(store, counter: 7)
    #expect(store.state.counter == 7)
  }

  @Test("multiple actions process in order")
  @MainActor
  func multipleActions() async {
    let store = makeStore(reducers: [counterReducer])
    store.dispatch(.inc(10))
    store.dispatch(.dec(3))
    store.dispatch(.inc(1))
    await awaitState(store, counter: 8)
    #expect(store.state.counter == 8)
  }
}


// MARK: - Middleware

struct MiddlewareTests {

  @Test("middleware forwards action via next")
  @MainActor
  func middlewareForwards() async {
    let middleware = AnyMiddleware<AppState, AppActions>(id: "passthrough") { context in
      let (_, _, _, next, action) = context.args

      try next(action)
    }
    let store = makeStore(middlewares: [middleware], reducers: [counterReducer])
    store.dispatch(.inc(1))
    await awaitState(store, counter: 1)
    #expect(store.state.counter == 1)
  }

  @Test("middleware blocks action when next is not called")
  @MainActor
  func middlewareBlocks() async {
    let middleware = AnyMiddleware<AppState, AppActions>(id: "blocker") { context in
      let (_, _, _, next, action) = context.args

      switch action {
      case .dec: try next(action)
      case .inc: break
      }
    }
    let store = makeStore(middlewares: [middleware], reducers: [counterReducer])
    store.dispatch(.inc(1))   // blocked — never reaches reducer
    store.dispatch(.dec(10))  // forwarded — counter = -10, not -9
    await awaitState(store, counter: -10)
    #expect(store.state.counter == -10)
  }

  @Test("middleware transforms action via next")
  @MainActor
  func middlewareTransforms() async {
    let middleware = AnyMiddleware<AppState, AppActions>(id: "doubler") { context in
      let (_, _, _, next, action) = context.args

      switch action {
      case .inc(let value): try next(.inc(value * 2))
      case .dec: try next(action)
      }
    }
    let store = makeStore(middlewares: [middleware], reducers: [counterReducer])
    store.dispatch(.inc(5))
    await awaitState(store, counter: 10)
    #expect(store.state.counter == 10)
  }

  @Test("middleware dispatches additional action")
  @MainActor
  func middlewareDispatches() async {
    let middleware = AnyMiddleware<AppState, AppActions>(id: "bonus") { context in
      let (dispatch, _, _, next, action) = context.args

      switch action {
      case .inc: dispatch(0, .dec(1))
      case .dec: break
      }

      try next(action)
    }
    let store = makeStore(middlewares: [middleware], reducers: [counterReducer])
    store.dispatch(.inc(5))
    // inc(5) → counter = 5, then bonus dec(1) → counter = 4
    await awaitState(store, counter: 4)
    #expect(store.state.counter == 4)
  }

  @Test("middleware chain executes in order")
  @MainActor
  func middlewareOrder() async {
    // first: doubles the value, second: adds 1
    // if order is [first, second]: inc(3) → inc(6) → inc(7) → counter = 7
    // if order were reversed:      inc(3) → inc(4) → inc(8) → counter = 8
    let double = AnyMiddleware<AppState, AppActions>(id: "double") { context in
      let (_, _, _, next, action) = context.args

      switch action {
      case .inc(let v): try next(.inc(v * 2))
      case .dec: try next(action)
      }
    }
    let plusOne = AnyMiddleware<AppState, AppActions>(id: "plusOne") { context in
      let (_, _, _, next, action) = context.args

      switch action {
      case .inc(let v): try next(.inc(v + 1))
      case .dec: try next(action)
      }
    }

    let setReducer = AnyReducer<AppState, AppActions>(id: "set") { context in
      let (state, action) = context.args

      switch action {
      case .inc(let value): state.counter = value
      case .dec(let value): state.counter = -value
      }
    }

    let store = makeStore(middlewares: [double, plusOne], reducers: [setReducer])
    store.dispatch(.inc(3))
    await awaitState(store, counter: 7)
    #expect(store.state.counter == 7)
  }

  @Test("middleware task launches async work")
  @MainActor
  func middlewareTask() async {
    let middleware = AnyMiddleware<AppState, AppActions>(id: "async") { context in
      let (dispatch, _, task, next, action) = context.args

      switch action {
      case .dec:
        task { _ in
          dispatch(0, .inc(100))
        }
      case .inc: break
      }

      try next(action)
    }
    let store = makeStore(middlewares: [middleware], reducers: [counterReducer])
    // dec(1) → counter = -1, task dispatches inc(100) → counter = 99
    store.dispatch(.dec(1))
    await awaitState(store, counter: 99)
    #expect(store.state.counter == 99)
  }

  @Test("stated middleware accesses coordinator across dispatches")
  @MainActor
  func statedMiddleware() async {
    let coordinator = TestLog<Bool>()
    let middleware = AnyMiddleware<AppState, AppActions>(
      StatedMiddleware(id: "stated", coordinator: coordinator) { coordinator, context in
        let (_, _, _, next, action) = context.args

        coordinator.append(true)
        try next(action)
      }
    )
    let store = makeStore(middlewares: [middleware], reducers: [counterReducer])
    store.dispatch(.inc(1))
    store.dispatch(.inc(1))
    await awaitState(store, counter: 2)
    #expect(store.state.counter == 2)
    #expect(coordinator.count == 2)
  }
}


// MARK: - Resolver

struct ResolverTests {

  @Test("resolver handles sync error with recovery")
  @MainActor
  func resolverHandlesError() async {
    enum TestError: Error, Sendable { case fail }

    let middleware = AnyMiddleware<AppState, AppActions>(id: "failOnDec") { context in
      let (_, _, _, next, action) = context.args

      switch action {
      case .dec: throw TestError.fail
      case .inc: break
      }

      try next(action)
    }
    let resolver = AnyResolver<AppState, AppActions>(id: "recovery") { context in
      let (_, dispatch, _, _, error, _) = context.args

      if error is TestError { dispatch(0, .inc(99)) }
    }
    let store = makeStore(middlewares: [middleware], resolvers: [resolver], reducers: [counterReducer])
    // dec(1) → throws → resolver dispatches inc(99) → counter = 99
    store.dispatch(.dec(1))
    await awaitState(store, counter: 99)
    #expect(store.state.counter == 99)
  }

  @Test("resolver handles async task error with recovery")
  @MainActor
  func resolverHandlesTaskError() async {
    enum TestError: Error, Sendable { case asyncFail }

    let middleware = AnyMiddleware<AppState, AppActions>(id: "asyncThrower") { context in
      let (_, _, task, next, action) = context.args

      switch action {
      case .dec: task { _ in throw TestError.asyncFail }
      case .inc: break
      }

      try next(action)
    }
    let resolver = AnyResolver<AppState, AppActions>(id: "recovery") { context in
      let (_, dispatch, _, _, _, _) = context.args

      dispatch(0, .inc(50))
    }
    let store = makeStore(middlewares: [middleware], resolvers: [resolver], reducers: [counterReducer])
    // dec(1) → reducer: counter = -1, task throws → resolver dispatches inc(50) → counter = 49
    store.dispatch(.dec(1))
    await awaitState(store, counter: 49)
    #expect(store.state.counter == 49)
  }
}


// MARK: - Pipeline

struct PipelineTests {

  @Test("full pipeline: middleware → reducer → state")
  @MainActor
  func fullPipeline() async {
    let middleware = AnyMiddleware<AppState, AppActions>(id: "passthrough") { context in
      let (_, _, _, next, action) = context.args

      try next(action)
    }
    let store = makeStore(middlewares: [middleware], reducers: [counterReducer])
    store.dispatch(.inc(3))
    store.dispatch(.dec(1))
    await awaitState(store, counter: 2)
    #expect(store.state.counter == 2)
  }

  @Test("read-only state reflects mutations")
  @MainActor
  func readOnlyState() async {
    let store = makeStore(reducers: [counterReducer])
    store.dispatch(.inc(42))
    await awaitState(store, counter: 42)
    #expect(store.counter == 42)
  }

  @Test("bind dispatches action on write")
  @MainActor
  func bindUnidirectional() async {
    let store = makeStore(reducers: [counterReducer])
    let binding = store.bind(\.counter) { newValue in
      .inc(newValue)
    }
    binding.wrappedValue = 7
    await awaitState(store, counter: 7)
    #expect(store.state.counter == 7)
  }

  @Test("complete triggers onLog")
  @MainActor
  func completeTriggersOnLog() async {
    let logs = TestLog<Store<AppState, AppActions>.Log>()
    let middleware = AnyMiddleware<AppState, AppActions>(id: "logger") { context in
      context.complete()
      try context.next()
    }
    let store = makeStore(
      middlewares: [middleware],
      reducers: [counterReducer],
      onLog: { logs.append($0) }
    )
    store.dispatch(.inc(1))
    await awaitState(store, counter: 1)
    let middlewareLogs = logs.values.filter { if case .middleware = $0 { true } else { false } }
    #expect(middlewareLogs.count == 1)
    guard case let .middleware(id, action, elapsed, result) = middlewareLogs[0] else {
      Issue.record("expected .middleware log")
      return
    }
    #expect(id == "logger")
    #expect(action == .inc(1))
    #expect(elapsed > .zero)
    guard case .success(true) = result else {
      Issue.record("expected .success(true)")
      return
    }
  }

  @Test("complete fires once")
  @MainActor
  func completeFiresOnce() async {
    let logs = TestLog<Store<AppState, AppActions>.Log>()
    let middleware = AnyMiddleware<AppState, AppActions>(id: "double") { context in
      context.complete()
      context.complete()  // second call — should be no-op
      try context.next()
    }
    let store = makeStore(
      middlewares: [middleware],
      reducers: [counterReducer],
      onLog: { logs.append($0) }
    )
    store.dispatch(.inc(1))
    await awaitState(store, counter: 1)
    let middlewareLogs = logs.values.filter { if case .middleware = $0 { true } else { false } }
    #expect(middlewareLogs.count == 1)
  }

  @Test("no onLog no crash")
  @MainActor
  func noOnLogNoCrash() async {
    let middleware = AnyMiddleware<AppState, AppActions>(id: "safe") { context in
      context.complete()
      try context.next()
    }
    let store = makeStore(middlewares: [middleware], reducers: [counterReducer])
    store.dispatch(.inc(1))
    await awaitState(store, counter: 1)
    #expect(store.state.counter == 1)
  }

  @Test("middleware throw auto-logs error")
  @MainActor
  func middlewareThrowAutoLogsError() async {
    enum TestError: Error, Sendable { case boom }
    let logs = TestLog<Store<AppState, AppActions>.Log>()
    let middleware = AnyMiddleware<AppState, AppActions>(id: "thrower") { context in
      let (_, _, _, next, action) = context.args
      switch action {
      case .dec: throw TestError.boom
      case .inc: try next(action)
      }
    }
    let resolver = AnyResolver<AppState, AppActions>(id: "recovery") { context in
      let (_, dispatch, _, _, _, _) = context.args
      dispatch(0, .inc(42))
    }
    let store = makeStore(
      middlewares: [middleware],
      resolvers: [resolver],
      reducers: [counterReducer],
      onLog: { logs.append($0) }
    )
    store.dispatch(.dec(1))
    await awaitState(store, counter: 42)
    let middlewareLogs = logs.values.filter {
      if case .middleware = $0 { return true }
      return false
    }
    #expect(middlewareLogs.count == 1)
    guard case let .middleware(id, _, _, result) = middlewareLogs[0] else {
      Issue.record("expected .middleware log")
      return
    }
    #expect(id == "thrower")
    #expect { try result.get() } throws: { $0 is TestError }
  }

  @Test("reducer complete triggers onLog")
  @MainActor
  func reducerCompleteTriggersOnLog() async {
    let logs = TestLog<Store<AppState, AppActions>.Log>()
    let reducer = AnyReducer<AppState, AppActions>(id: "logged") { context in
      let (state, action) = context.args
      switch action {
      case .inc(let v): state.counter += v
      case .dec(let v): state.counter -= v
      }
      context.complete()
    }
    let store = makeStore(
      reducers: [reducer],
      onLog: { logs.append($0) }
    )
    store.dispatch(.inc(5))
    await awaitState(store, counter: 5)
    let reducerLogs = logs.values.filter { if case .reducer = $0 { true } else { false } }
    #expect(reducerLogs.count == 1)
    guard case let .reducer(id, action, elapsed, succeeded) = reducerLogs[0] else {
      Issue.record("expected .reducer log")
      return
    }
    #expect(id == "logged")
    #expect(action == .inc(5))
    #expect(elapsed > .zero)
    #expect(succeeded == true)
  }

  @Test("reducer complete fires once")
  @MainActor
  func reducerCompleteFiresOnce() async {
    let logs = TestLog<Store<AppState, AppActions>.Log>()
    let reducer = AnyReducer<AppState, AppActions>(id: "double") { context in
      let (state, action) = context.args
      switch action {
      case .inc(let v): state.counter += v
      case .dec(let v): state.counter -= v
      }
      context.complete()
      context.complete()  // second call — should be no-op
    }
    let store = makeStore(
      reducers: [reducer],
      onLog: { logs.append($0) }
    )
    store.dispatch(.inc(1))
    await awaitState(store, counter: 1)
    let reducerLogs = logs.values.filter { if case .reducer = $0 { true } else { false } }
    #expect(reducerLogs.count == 1)
  }

  @Test("reducer no onLog no crash")
  @MainActor
  func reducerNoOnLogNoCrash() async {
    let reducer = AnyReducer<AppState, AppActions>(id: "safe") { context in
      let (state, action) = context.args
      switch action {
      case .inc(let v): state.counter += v
      case .dec(let v): state.counter -= v
      }
      context.complete()
    }
    let store = makeStore(reducers: [reducer])
    store.dispatch(.inc(1))
    await awaitState(store, counter: 1)
    #expect(store.state.counter == 1)
  }

  @Test("resolver complete triggers onLog")
  @MainActor
  func resolverCompleteTriggersOnLog() async {
    enum TestError: Error, Sendable { case fail }
    let logs = TestLog<Store<AppState, AppActions>.Log>()
    let middleware = AnyMiddleware<AppState, AppActions>(id: "thrower") { context in
      let (_, _, _, next, action) = context.args
      switch action {
      case .dec: throw TestError.fail
      case .inc: try next(action)
      }
    }
    let resolver = AnyResolver<AppState, AppActions>(id: "logged") { context in
      let (_, dispatch, _, _, _, _) = context.args
      dispatch(0, .inc(10))
      context.complete()
    }
    let store = makeStore(
      middlewares: [middleware],
      resolvers: [resolver],
      reducers: [counterReducer],
      onLog: { logs.append($0) }
    )
    store.dispatch(.dec(1))
    await awaitState(store, counter: 10)
    let resolverLogs = logs.values.filter {
      if case .resolver = $0 { return true }
      return false
    }
    #expect(resolverLogs.count == 1)
    guard case let .resolver(id, action, elapsed, succeeded, error) = resolverLogs[0] else {
      Issue.record("expected .resolver log")
      return
    }
    #expect(id == "logged")
    #expect(action == .dec(1))
    #expect(elapsed > .zero)
    #expect(succeeded == true)
    #expect(error is TestError)
  }

  @Test("resolver complete fires once")
  @MainActor
  func resolverCompleteFiresOnce() async {
    enum TestError: Error, Sendable { case fail }
    let logs = TestLog<Store<AppState, AppActions>.Log>()
    let middleware = AnyMiddleware<AppState, AppActions>(id: "thrower") { context in
      let (_, _, _, next, action) = context.args
      switch action {
      case .dec: throw TestError.fail
      case .inc: try next(action)
      }
    }
    let resolver = AnyResolver<AppState, AppActions>(id: "double") { context in
      let (_, dispatch, _, _, _, _) = context.args
      dispatch(0, .inc(10))
      context.complete()
      context.complete()  // second call — should be no-op
    }
    let store = makeStore(
      middlewares: [middleware],
      resolvers: [resolver],
      reducers: [counterReducer],
      onLog: { logs.append($0) }
    )
    store.dispatch(.dec(1))
    await awaitState(store, counter: 10)
    let resolverLogs = logs.values.filter {
      if case .resolver = $0 { return true }
      return false
    }
    #expect(resolverLogs.count == 1)
  }

  @Test("resolver no onLog no crash")
  @MainActor
  func resolverNoOnLogNoCrash() async {
    enum TestError: Error, Sendable { case fail }
    let middleware = AnyMiddleware<AppState, AppActions>(id: "thrower") { context in
      let (_, _, _, next, action) = context.args
      switch action {
      case .dec: throw TestError.fail
      case .inc: try next(action)
      }
    }
    let resolver = AnyResolver<AppState, AppActions>(id: "safe") { context in
      let (_, dispatch, _, _, _, _) = context.args
      dispatch(0, .inc(10))
      context.complete()
    }
    let store = makeStore(
      middlewares: [middleware],
      resolvers: [resolver],
      reducers: [counterReducer]
    )
    store.dispatch(.dec(1))
    await awaitState(store, counter: 10)
    #expect(store.state.counter == 10)
  }
}


// MARK: - Dispatch Limit

struct DispatchLimitTests {

  @Test("limit 0 means unlimited — all actions dispatched")
  @MainActor
  func limitZeroIsUnlimited() async {
    let store = makeStore(reducers: [counterReducer])
    store.dispatch(.inc(1))
    store.dispatch(.inc(1))
    store.dispatch(.inc(1))
    await awaitState(store, counter: 3)
    #expect(store.state.counter == 3)
  }

  @Test("limit 1 drops excess actions of the same type")
  @MainActor
  func limitOneDropsDuplicates() async {
    let log = TestLog<String>()
    let middleware = AnyMiddleware<AppState, AppActions>(id: "hold") { context in
      let (_, _, task, next, action) = context.args

      // Hold the first inc in an async task so the worker is blocked
      switch action {
      case .inc(let v) where v == 1:
        task { _ in
          try await Task.sleep(for: .milliseconds(50))
        }
      default: break
      }

      log.append("process-\(action)")
      try next(action)
    }
    let store = makeStore(middlewares: [middleware], reducers: [counterReducer])

    // Rapidly fire 5 inc(1) with limit 1 — only the first should enqueue
    for _ in 0..<5 {
      store.dispatch(maxDispatchable: 1, .inc(1))
    }
    // dec uses a different id — should not be affected
    store.dispatch(.dec(100))
    await awaitState(store, counter: -99)
    #expect(store.state.counter == -99)
  }

  @Test("limit allows re-dispatch after processing")
  @MainActor
  func limitAllowsAfterProcessing() async {
    let store = makeStore(reducers: [counterReducer])

    // dispatch with limit 1, wait for it to process, then dispatch again
    store.dispatch(maxDispatchable: 1, .inc(1))
    await awaitState(store, counter: 1)

    store.dispatch(maxDispatchable: 1, .inc(1))
    await awaitState(store, counter: 2)

    store.dispatch(maxDispatchable: 1, .inc(1))
    await awaitState(store, counter: 3)
    #expect(store.state.counter == 3)
  }
}


// MARK: - MainActor Responsiveness

struct MainActorTests {

  @Test("MainActor processes actions while middleware task is active")
  @MainActor
  func responsiveDuringActiveTask() async {
    let taskStarted = TestLog<Bool>()
    let (gate, open) = AsyncStream.makeStream(of: Bool.self)

    let middleware = AnyMiddleware<AppState, AppActions>(id: "held") { context in
      let (dispatch, _, task, next, action) = context.args

      switch action {
      case .inc(1):
        task { _ in
          taskStarted.append(true)
          for await _ in gate {}       // held until open.finish()
          dispatch(0, .inc(1000))
        }
      default: break
      }

      try next(action)
    }

    let store = makeStore(middlewares: [middleware], reducers: [counterReducer])

    store.dispatch(.inc(1))              // counter → 1, task launched
    await awaitState(store, counter: 1)
    while taskStarted.count == 0 { await Task.yield() }

    // task is held open — MainActor must still process actions
    store.dispatch(.inc(10))
    await awaitState(store, counter: 11)
    #expect(store.state.counter == 11)

    store.dispatch(.dec(3))
    await awaitState(store, counter: 8)
    #expect(store.state.counter == 8)

    open.finish()                        // release the task

    await awaitState(store, counter: 1008)
    #expect(store.state.counter == 1008)
  }

  @Test("concurrent middleware tasks do not block dispatch pipeline")
  @MainActor
  func responsiveDuringConcurrentTasks() async {
    let tasksStarted = TestLog<Int>()
    let gate = TestLog<Bool>()

    let middleware = AnyMiddleware<AppState, AppActions>(id: "concurrent") { context in
      let (dispatch, _, task, next, action) = context.args

      switch action {
      case .dec(let v):
        task { _ in
          tasksStarted.append(v)
          while gate.count == 0 {
            try await Task.sleep(for: .milliseconds(1))
          }
          dispatch(0, .inc(v * 100))
        }
      case .inc: break
      }

      try next(action)
    }

    let store = makeStore(middlewares: [middleware], reducers: [counterReducer])

    // launch 3 concurrent tasks
    store.dispatch(.dec(1))              // counter = -1, task → inc(100)
    store.dispatch(.dec(2))              // counter = -3, task → inc(200)
    store.dispatch(.dec(3))              // counter = -6, task → inc(300)
    await awaitState(store, counter: -6)
    while tasksStarted.count < 3 { await Task.yield() }

    // all 3 tasks running — MainActor still responsive
    store.dispatch(.inc(1))
    await awaitState(store, counter: -5)
    #expect(store.state.counter == -5)

    // release all tasks
    gate.append(true)

    // 100 + 200 + 300 = 600; -5 + 600 = 595
    await awaitState(store, counter: 595)
    #expect(store.state.counter == 595)
  }

  @Test("MainActor processes actions during CPU-intensive middleware task")
  @MainActor
  func responsiveDuringIntensiveTask() async {
    let log = TestLog<String>()

    let middleware = AnyMiddleware<AppState, AppActions>(id: "cpu") { context in
      let (dispatch, _, task, next, action) = context.args

      switch action {
      case .dec:
        task { _ in
          log.append("cpu-start")
          var acc: UInt64 = 0
          for i: UInt64 in 0..<20_000_000 {
            acc &+= i
          }
          _ = acc
          log.append("cpu-end")
          dispatch(0, .inc(500))
        }
      case .inc: break
      }

      try next(action)
    }

    let loggingReducer = AnyReducer<AppState, AppActions>(id: "log") { context in
      let (state, action) = context.args

      log.append("reduce-\(action.id)")
      switch action {
      case .inc(let value): state.counter += value
      case .dec(let value): state.counter -= value
      }
    }

    let store = makeStore(middlewares: [middleware], reducers: [loggingReducer])

    store.dispatch(.dec(1))              // counter = -1, launches CPU task
    store.dispatch(.inc(10))             // counter = 9, must process while CPU runs

    // -1 + 10 + 500 = 509
    await awaitState(store, counter: 509)
    #expect(store.state.counter == 509)

    // inc(10) (id=10) was reduced before CPU work finished
    let values = log.values
    let reduceIncIndex = values.firstIndex(of: "reduce-inc")!
    let cpuEndIndex = values.firstIndex(of: "cpu-end")!
    #expect(reduceIncIndex < cpuEndIndex)
  }
}
