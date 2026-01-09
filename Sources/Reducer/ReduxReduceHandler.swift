//


import Foundation



/// ReduxReduceHandler
///
/// The reducing closure stored by ``AnyReduxReducer``: given a
/// ``ReduxReducerContext`` it mutates state and returns a ``ReduxReducerExit``.
/// Runs on the main actor.
public typealias ReduxReduceHandler<S: ReduxState, A: ReduxAction> = @MainActor (ReduxReducerContext<S, A>) -> ReduxReducerExit

