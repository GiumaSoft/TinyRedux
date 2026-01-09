//

import Foundation
import Observation
import Synchronization
import SwiftUI
import Testing
@testable import TinyRedux


// MARK: - Fixtures


/// Read-only slice protocol used to prove periscope projection and observation
/// through a `SubState` existential (a feature module would own a type like this).
@MainActor
protocol CounterReadable {
  var count: Int { get }
}

@MainActor
@Observable
final class ScopedFixtureState: ReduxState, CounterReadable, @unchecked Sendable {
  typealias ReadOnly = ScopedFixtureReadOnly

  var count: Int = 0
  var label: String = ""
  var seen: [String] = []

  var readOnly: ScopedFixtureReadOnly { ScopedFixtureReadOnly(self) }

  /// Periscope onto `self` typed as the read-only slice (same instance, no copy).
  var counterSlice: any CounterReadable { self }
}

@MainActor
@Observable
final class ScopedFixtureReadOnly: ReduxReadOnlyState, @unchecked Sendable {
  typealias State = ScopedFixtureState

  let state: ScopedFixtureState

  init(_ state: ScopedFixtureState) {
    self.state = state
  }

  var count: Int { state.count }
  var label: String { state.label }
}

struct ScopedFixtureSnapshot: ReduxStateSnapshot {
  typealias S = ScopedFixtureState
  let count: Int
  let label: String

  @MainActor
  init(state: ScopedFixtureReadOnly) {
    self.count = state.count
    self.label = state.label
  }
}

/// Minimal intent vocabularies (the two axes scoped over one store).
enum CounterIntent: Sendable {
  case increment
  case decrement
}

enum LabelIntent: Sendable {
  case set(String)
}

/// Parent action space; the scopes embed their intents into these cases.
enum ScopedFixtureAction: ReduxAction {
  case counter(CounterIntent)
  case label(LabelIntent)

  var id: String {
    switch self {
    case .counter: "counter"
    case .label: "label"
    }
  }
}

@MainActor
func makeScopedFixtureStore(
  _ state: ScopedFixtureState
) -> Store<ScopedFixtureState, ScopedFixtureAction> {
  let reducer = AnyReducer<ScopedFixtureState, ScopedFixtureAction>(id: "scoped-fixture") { context in
    let (state, action) = context.args
    state.seen.append(action.id)
    switch action {
    ///
    case .counter(let intent):
      switch intent {
      case .increment: state.count += 1
      case .decrement: state.count -= 1
      }
    ///
    case .label(let intent):
      switch intent {
      case .set(let value): state.label = value
      }
    }
    return .next
  }

  return Store(
    initialState: state,
    middlewares: [],
    resolvers: [],
    reducers: [reducer]
  )
}


// MARK: - Existential no-op (test 7 — the @Entry default scenario)


struct NoOpCounter: CounterReadable {
  nonisolated var count: Int { 0 }
}

/// A `SubStore` that owns no store: a `nonisolated init` and a computed `state`
/// make it constructible in a `nonisolated` context — exactly what an `@Entry`
/// SwiftUI environment default requires.
@MainActor
struct NoOpSubStore: SubStore {
  typealias SubState = any CounterReadable
  typealias SubAction = CounterIntent
  typealias ParentState = ScopedFixtureState

  nonisolated init() {}

  nonisolated var state: any CounterReadable { NoOpCounter() }

  nonisolated func dispatch(_ action: CounterIntent) {}

  func dispatch<T: ReduxStateSnapshot<ScopedFixtureState>>(
    _ action: CounterIntent,
    snapshot: T.Type
  ) async -> ReduxEncodedSnapshot {
    .failure(CancellationError())
  }
}

/// Built in a `nonisolated` (global) function: compiling this proves the no-op
/// existential is constructible off the main actor.
func makeNonisolatedSubStoreDefault() -> any SubStore<any CounterReadable, CounterIntent> {
  NoOpSubStore()
}

extension EnvironmentValues {
  /// Demonstrates the no-op as a real `@Entry` environment default.
  @Entry var demoSubStore: any SubStore<any CounterReadable, CounterIntent> = NoOpSubStore()
}


// MARK: - Tests


extension TinyReduxTests {

  /// A scoped dispatch must land in the parent pipeline as the EMBEDDED action:
  /// the reducer sees `.counter(.increment)`, not a bare sub-intent. We record
  /// every reduced action's id and confirm the embedded case reached the reducer.
  @Test
  func scopedDispatchEmbedsIntoParentAction() async {
    let state = ScopedFixtureState()
    let store = makeScopedFixtureStore(state)
    let scoped = store.scoped(
      state: \.self,
      action: { (intent: CounterIntent) in ScopedFixtureAction.counter(intent) }
    )

    scoped.dispatch(.increment)

    await Self.poll { state.seen.isEmpty }

    #expect(state.seen == ["counter"])
    #expect(state.count == 1)
  }

  /// `state` projects the SAME instance the store holds (identity, not a copy),
  /// and reducer mutations are visible through the scope.
  @Test
  func scopedStateProjectsByIdentity() async {
    let state = ScopedFixtureState()
    let store = makeScopedFixtureStore(state)
    let scoped = store.scoped(
      state: \.self,
      action: { (intent: CounterIntent) in ScopedFixtureAction.counter(intent) }
    )

    #expect(scoped.state === state)

    scoped.dispatch(.increment)
    await Self.poll { state.count < 1 }

    #expect(scoped.state.count == 1)
  }

  /// Observation through the scoped existential: `withObservationTracking` on a
  /// read via `any SubStore`/`any CounterReadable` fires on reducer mutation
  /// (replicates the session spike as a TinyRedux test).
  @Test
  func observationFiresThroughScopedExistential() async {
    let state = ScopedFixtureState()
    let store = makeScopedFixtureStore(state)
    let scoped: any SubStore<any CounterReadable, CounterIntent> = store.scoped(
      state: \.counterSlice,
      action: { (intent: CounterIntent) in ScopedFixtureAction.counter(intent) }
    )

    let fired = Mutex(false)
    withObservationTracking {
      _ = scoped.state.count
    } onChange: {
      fired.withLock { $0 = true }
    }

    store.dispatch(.counter(.increment))
    await Self.poll { !fired.withLock { $0 } }

    #expect(fired.withLock { $0 })
  }

  /// `bind`: get reads the slice; set dispatches the mapped intent; a `nil`
  /// mapping skips the dispatch.
  @Test
  func scopedBindReadsSliceAndDispatchesMappedIntent() async {
    let state = ScopedFixtureState()
    let store = makeScopedFixtureStore(state)
    let scoped = store.scoped(
      state: \.self,
      action: { (intent: CounterIntent) in ScopedFixtureAction.counter(intent) }
    )

    let binding = scoped.bind(
      { $0.count },
      { (value: Int) in value > 0 ? CounterIntent.increment : nil }
    )

    // get reads the live slice
    #expect(binding.wrappedValue == 0)

    // set with a value that maps to an intent → dispatch
    binding.wrappedValue = 5
    await Self.poll { state.count < 1 }
    #expect(state.count == 1)
    #expect(binding.wrappedValue == 1)

    // set with a value that maps to nil → no dispatch
    binding.wrappedValue = -1
    try? await Task.sleep(nanoseconds: 20_000_000)
    #expect(state.count == 1)
  }

  /// The snapshot path through the scope is identical to the direct store call:
  /// `dispatch(_:snapshot:)` round-trips to the same encoded slice.
  @Test
  func scopedSnapshotMatchesDirectStore() async {
    let scopedState = ScopedFixtureState()
    let scopedStore = makeScopedFixtureStore(scopedState)
    let scoped = scopedStore.scoped(
      state: \.self,
      action: { (intent: CounterIntent) in ScopedFixtureAction.counter(intent) }
    )

    let viaScope = await scoped.dispatch(.increment, snapshot: ScopedFixtureSnapshot.self)

    let directState = ScopedFixtureState()
    let directStore = makeScopedFixtureStore(directState)
    let viaStore = await directStore.dispatch(.counter(.increment), snapshot: ScopedFixtureSnapshot.self)

    let decodedScope = try! JSONDecoder().decode(ScopedFixtureSnapshot.self, from: viaScope.get())
    let decodedStore = try! JSONDecoder().decode(ScopedFixtureSnapshot.self, from: viaStore.get())

    #expect(decodedScope.count == 1)
    #expect(decodedScope.count == decodedStore.count)
    #expect(decodedScope.label == decodedStore.label)
  }

  /// Two scopes over ONE store on different axes (counter slice + label slice)
  /// don't interfere — the conformance-uniqueness rationale, proven: a single
  /// store vends two distinct `SubStore` values with independent state/action.
  @Test
  func twoScopesOnOneStoreDoNotInterfere() async {
    let state = ScopedFixtureState()
    let store = makeScopedFixtureStore(state)

    let counterScope = store.scoped(
      state: \.count,
      action: { (intent: CounterIntent) in ScopedFixtureAction.counter(intent) }
    )
    let labelScope = store.scoped(
      state: \.label,
      action: { (intent: LabelIntent) in ScopedFixtureAction.label(intent) }
    )

    counterScope.dispatch(.increment)
    labelScope.dispatch(.set("hi"))

    await Self.poll { state.count < 1 || state.label.isEmpty }

    #expect(state.count == 1)
    #expect(state.label == "hi")
    // each scope reads only its own axis
    #expect(counterScope.state == 1)
    #expect(labelScope.state == "hi")
  }

  /// Existential ergonomics: `any SubStore<SubState, SubAction>` with a no-op
  /// (`nonisolated init` + computed `state`) is constructible in a `nonisolated`
  /// context and usable as an `@Entry` SwiftUI environment default.
  @Test
  func existentialNoOpIsConstructibleInNonisolatedContext() {
    let fromGlobal = makeNonisolatedSubStoreDefault()
    #expect(fromGlobal.state.count == 0)

    let fromEntry = EnvironmentValues().demoSubStore
    #expect(fromEntry.state.count == 0)
  }
}
