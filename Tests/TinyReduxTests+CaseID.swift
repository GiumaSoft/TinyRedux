//

import Testing
@testable import TinyRedux


extension TinyReduxTests {

  /// The `@CaseID` macro synthesizes an `id` property on enum cases that returns the case name as a `String`,
  /// ignoring associated values. This is essential for the rate limiting system (`Dispatcher.tryEnqueue`) which
  /// uses the action's `id` to count in-flight dispatches per case. The test verifies both a bare case and a
  /// case with an associated value produce the expected string identifier, confirming the macro strips payloads.
  @Test
  func caseIDMacroSynthesizesID() {
    @CaseID
    enum Action: Equatable, Sendable {
      case load
      case save(Int)
    }

    #expect(Action.load.id == "load")
    #expect(Action.save(42).id == "save")
  }
}
