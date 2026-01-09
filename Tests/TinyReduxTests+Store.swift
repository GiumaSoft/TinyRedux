//

import Testing
@testable import TinyRedux


extension TinyReduxTests {

  /// Store conforms to `@dynamicMemberLookup`, exposing read-only state properties directly on the store
  /// instance via `subscript(dynamicMember:)`. This test verifies that `store.value` resolves to the
  /// underlying state's value without requiring explicit access to the state object — the ergonomic shorthand
  /// that lets SwiftUI views bind to `store.someProperty` as if the store itself were the state model.
  @Test
  func dynamicMemberLookupReadsState() {
    let state = TestState()
    state.value = 99

    let store = Store<TestState, TestAction>(
      initialState: state,
      middlewares: [],
      resolvers: [],
      reducers: []
    )

    #expect(store.value == 99)
  }
}
