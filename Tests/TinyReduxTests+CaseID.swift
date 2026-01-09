//

import Testing
@testable import TinyRedux


@ReduxAction
enum MacroTestAction: ReduxAction {
  case load
  case save(Int)
}


extension TinyReduxTests {

  /// The `@ReduxAction` macro synthesizes `id` on enum cases — returns the case name as a
  /// `String`, ignoring associated values. Used by the rate limiting system
  /// (`Dispatcher.tryEnqueue`) to count in-flight dispatches per case.
  /// `description` and `debugString` default to `id` via the protocol extension; consumers
  /// can override `debugString` in a `@MainActor` extension for richer logging.
  @Test
  func reduxActionMacroSynthesizesID() {
    #expect(MacroTestAction.load.id == "load")
    #expect(MacroTestAction.save(42).id == "save")
    #expect(MacroTestAction.load.description == "load")
    #expect(MacroTestAction.load.debugString == "load")
    #expect(MacroTestAction.save(42).debugString == "save")
  }
}
