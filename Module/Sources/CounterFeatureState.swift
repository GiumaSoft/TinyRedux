//
//  CounterFeature — an EXTERNAL module: it imports only TinyRedux and knows nothing
//  about the host app. Its state is a mapped (`.scattered`) state that "sees" a single
//  `count: Int` projected by the app onto whatever the app owns.
//

import TinyRedux


@ReduxMappedState
@MainActor
public final class CounterFeatureState: ReduxMappedState
{
  public var count: Int
}
