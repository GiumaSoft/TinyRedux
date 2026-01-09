//

import Foundation


public extension ReduxStore {
  /// ⛔️ DO NOT USE IN PRODUCTION CODE.
  ///
  /// Mutates the store's live state **directly**, bypassing the dispatch/middleware/
  /// reducer pipeline — for SwiftUI previews only, to seed a scenario without wiring
  /// up reducers or paying the async dispatch hop. Returns the store (`@discardableResult`)
  /// so it can be chained straight into a preview's view.
  @MainActor
  @discardableResult
  func previewState(_ update: (S) -> Void) -> Self
  {
    update(_state)
    return self
  }
}
