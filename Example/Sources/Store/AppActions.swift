//

import CounterFeature
import TinyRedux


@ReduxAction
enum AppActions: ReduxAction
{
  case increment                              // top-level app action…
  case decrement                              // …routed to the module (scattered actions)
  case counter(CounterFeatureActions)         // the module's own actions, composed as a case
}

extension AppActions {
  // Scattered extract: the module's local action is pulled from MULTIPLE root cases —
  // the wrapping `.counter(_)` AND the top-level `.increment`/`.decrement`.
  var counter: CounterFeatureActions? {
    switch self
    {
    case .increment: .increment
    case .decrement: .decrement
    case .counter(let a): a
    }
  }
}
