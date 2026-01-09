//

import Testing
@testable import TinyRedux


extension TinyReduxTests {

  /// `Store.previewState` creates a store with empty middleware, resolver, and reducer arrays — a minimal
  /// pipeline that passes state through unchanged. This factory is designed for SwiftUI previews where you
  /// need a fully functional Store instance backed by fixture data without configuring any pipeline components.
  /// The test sets a value on state before creation and verifies it is readable through the store afterward.
  @Test
  func previewStateCreatesEmptyPipeline() {
    let state = TestState()
    state.value = 42

    let store = Store<TestState, TestAction>.previewState(state)

    #expect(store.value == 42)
  }

  /// Store conforms to `@dynamicMemberLookup`, exposing read-only state properties directly on the store
  /// instance via `subscript(dynamicMember:)`. This test verifies that `store.value` resolves to the
  /// underlying state's value without requiring explicit access to the state object — the ergonomic shorthand
  /// that lets SwiftUI views bind to `store.someProperty` as if the store itself were the state model.
  @Test
  func dynamicMemberLookupReadsState() {
    let state = TestState()
    state.value = 99

    let store = Store<TestState, TestAction>.previewState(state)

    #expect(store.value == 99)
  }
}
