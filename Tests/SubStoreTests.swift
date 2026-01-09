//
//  Functional tests for the SubStore layer: .linear and .scattered (mapped).
//

import Testing
import SwiftUI
@testable import TinyRedux


@MainActor
private func settle(_ condition: @MainActor () -> Bool) async
{
  var attempts = 0
  while !condition(), attempts < 1_000
  {
    await Task.yield()
    attempts += 1
  }
}


// ── .linear ──────────────────────────────────────────────────────────────────

@MainActor
@Test
func linear_sliceReadsAndDispatches() async
{
  let store = DemoModule.makeStore()
  let counter: any ReduxModule<CounterModuleState, CounterModuleActions> = store.slice(DemoModule.counter)

  #expect(counter.state.count == 0)

  counter.dispatch(.increment)
  counter.dispatch(.increment)
  await settle { counter.state.count == 2 }
  #expect(counter.state.count == 2)

  counter.dispatch(.decrement)
  await settle { counter.state.count == 1 }
  #expect(counter.state.count == 1)

  // the lift wrote the live root sub-object, not a copy
  #expect(store.state.counter.count == 1)
}


// ── .scattered (mapped) ───────────────────────────────────────────────────────

@MainActor
@Test
func scattered_mappedSliceWritesThroughToSplitRoot() async
{
  let store = DemoModule.makeStore()
  let user: any ReduxModule<UserModuleState, UserModuleActions> = store.slice(DemoModule.user)

  #expect(user.state.firstName == "")
  #expect(user.state.isAuthenticated == false)

  user.dispatch(.setFirstName("Luigi"))
  user.dispatch(.setAuthenticated(true))
  await settle { user.state.firstName == "Luigi" && user.state.isAuthenticated }

  // mapped read is live
  #expect(user.state.firstName == "Luigi")
  #expect(user.state.isAuthenticated == true)

  // NO stale copy: the writes landed on the split, app-owned root sub-states
  #expect(store.state.user.firstName == "Luigi")
  #expect(store.state.authentication.isAuthenticated == true)
}


@MainActor
@Test
func scattered_bindDispatchesThroughTheModule() async
{
  let store = DemoModule.makeStore()
  let user = store.slice(DemoModule.user)

  let firstName: Binding<String> = user.bind(\.firstName, to: UserModuleActions.setFirstName)
  firstName.wrappedValue = "Ada"

  await settle { store.state.user.firstName == "Ada" }
  #expect(store.state.user.firstName == "Ada")
  #expect(firstName.wrappedValue == "Ada")
}


// ── mapped module is testable standalone (no app, no store, no stale copies) ───

@MainActor
@Test
func mapped_isTestableStandaloneViaProjected() async
{
  let module = UserModuleMock(.mock(isAuthenticated: true))

  #expect(module.state.firstName == "Mario")
  #expect(module.state.isAuthenticated == true)

  module.dispatch(.setFirstName("Grace"))
  module.dispatch(.setAuthenticated(false))
  await settle { module.state.firstName == "Grace" && !module.state.isAuthenticated }

  #expect(module.state.firstName == "Grace")
  #expect(module.state.isAuthenticated == false)
  #expect(module.dispatched.count == 2)
}
