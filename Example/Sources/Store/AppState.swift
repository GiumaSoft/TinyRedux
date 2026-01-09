//
//  App-owned root state. Owns the counter as a plain `Int`; the external
//  CounterFeature module never sees AppState — it sees only a projected `count`.
//

import TinyRedux


@ReduxState
@Observable
@MainActor
final class AppState: ReduxState
{
  var counter: Int

  nonisolated convenience init()
  {
    self.init(counter: 0)
  }
}
