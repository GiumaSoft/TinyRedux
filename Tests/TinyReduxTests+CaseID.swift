//

import Testing
@testable import TinyRedux


@ReduxAction
enum MacroTestAction: ReduxAction {
  case load
  case save(Int)
}


extension TinyReduxTests {

  /// The `@ReduxAction` macro synthesizes `id`, `description`, and `debugDescription` on enum cases.
  /// `id` returns the case name as a `String`, ignoring associated values. This is essential for the
  /// rate limiting system (`Dispatcher.tryEnqueue`) which uses the action's `id` to count in-flight
  /// dispatches per case.
  @Test
  func reduxActionMacroSynthesizesID() {
    #expect(MacroTestAction.load.id == "load")
    #expect(MacroTestAction.save(42).id == "save")
    #expect(MacroTestAction.load.description == "load")
    #expect(MacroTestAction.save(42).debugDescription == "save")
  }
}
