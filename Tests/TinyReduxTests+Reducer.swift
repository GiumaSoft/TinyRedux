//

import Testing
@testable import TinyRedux


extension TinyReduxTests {

  /// Reducers are applied in the exact order they appear in the user-supplied array. This guarantees
  /// deterministic state mutation sequences — critical for predictable behavior when multiple reducers
  /// contribute incremental changes to the same state properties within a single dispatch cycle.
  @Test
  func reducersRunInProvidedOrder() async {
    let state = TestState()
    let r1 = AnyReducer<TestState, TestAction>(id: "r1") { context in
      context.state.log.append("r1")
      return .next
    }
    let r2 = AnyReducer<TestState, TestAction>(id: "r2") { context in
      context.state.log.append("r2")
      return .next
    }
    let store = Store(
      initialState: state,
      middlewares: [],
      resolvers: [],
      reducers: [r1, r2]
    )

    let _ = await store.dispatch(.run, snapshot: TestSnapshot.self)

    #expect(state.log == ["r1", "r2"])
  }

  /// Every reducer in the chain runs regardless of previous reducers' results — there is no short-circuit
  /// on first match. This ensures composite state mutations work correctly when different reducers own
  /// different slices of state, each contributing its part to the final result of a single dispatch.
  @Test
  func multipleReducersAllMutateState() async {
    let state = TestState()
    let r1 = AnyReducer<TestState, TestAction>(id: "r1") { context in
      context.state.value += 10
      return .next
    }
    let r2 = AnyReducer<TestState, TestAction>(id: "r2") { context in
      context.state.value += 5
      return .next
    }
    let store = Store(
      initialState: state,
      middlewares: [],
      resolvers: [],
      reducers: [r1, r2]
    )

    let result = await store.dispatchAndDecode(.inc)

    #expect(result.value == 15)
  }

  /// ReducerContext exposes an `.args` computed property returning a (state, action) tuple. This enables
  /// ergonomic destructuring at the call site via `let (state, action) = context.args`, allowing reducers
  /// to work with named bindings rather than accessing context properties individually through dot syntax.
  @Test
  func reducerContextArgsDestructure() async {
    let state = TestState()
    var capturedAction: TestAction?

    let reducer = AnyReducer<TestState, TestAction>(id: "r") { context in
      let (_, action) = context.args
      capturedAction = action
      return .next
    }
    let store = Store(
      initialState: state,
      middlewares: [],
      resolvers: [],
      reducers: [reducer]
    )

    let _ = await store.dispatch(.run, snapshot: TestSnapshot.self)

    #expect(capturedAction == .run)
  }

  /// Returning `.next` from a reducer signals that state was mutated. This test verifies that the
  /// return value acts purely as metadata for the logging/diagnostics system and does not interfere with
  /// the actual state mutation — the value set inside the closure must persist after the pipeline completes.
  @Test
  func reducerExitNext() async {
    let state = TestState()
    let reducer = AnyReducer<TestState, TestAction>(id: "r") { context in
      context.state.value = 1
      return .next
    }
    let store = Store(
      initialState: state,
      middlewares: [],
      resolvers: [],
      reducers: [reducer]
    )

    let _ = await store.dispatch(.run, snapshot: TestSnapshot.self)

    #expect(state.value == 1)
  }

  /// Returning `.defaultNext` from a reducer signals that no state change occurred for this action. This test
  /// confirms the pipeline still completes normally and state remains at its initial value, verifying that
  /// `.defaultNext` is a passive pass-through for the logging system rather than an active pipeline control mechanism.
  @Test
  func reducerExitDefaultNext() async {
    let state = TestState()
    let reducer = AnyReducer<TestState, TestAction>(id: "r") { _ in
      return .defaultNext
    }
    let store = Store(
      initialState: state,
      middlewares: [],
      resolvers: [],
      reducers: [reducer]
    )

    let _ = await store.dispatch(.run, snapshot: TestSnapshot.self)

    #expect(state.value == 0)
  }
}
