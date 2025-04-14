//


import Foundation

/// A Reducer is a function that receives the current state and an action and decides how to update the state if necessary. Differently from original Redux reducer it benefits of inout swift keyword that let it operate directly on the globlal state without the need of returning a newState.
///
/// Reducers main purposes are:
///
/// - They should only calculate the new state value based on the state and action arguments.
/// - They are  allowed to modify the existing state in a way that preserve that global state integrity, since they are the only function that is allowed to do that in a synchronous way you don't risk any data race even if you are dispatching actions from different threads in an asynchronous way..
/// - They must not do any asynchronous logic or cause other "side effects", they are not allowed to dispatch new actions.
public struct Reducer<S, A>: Sendable where S: Sendable, A: Sendable & Equatable {
  ///
  ///
  @usableFromInline
  let reduce: @Sendable (inout S, A) throws -> Void
  ///
  ///
  /// Creates an instance of a Reducer that update the state if necessary based on action.
  ///
  /// AppState represent the state of the app.
  ///
  ///       struct AppState {
  ///         var counter: Int
  ///       }
  ///
  /// AppActions represent the minimum operation that reducer can perform on app state.
  ///
  ///       enum AppActions {
  ///         case increaseCounter
  ///         case decreaseCounter
  ///       }
  ///
  /// appReducer is the concrete instance of a reducer the can mutate AppState based on AppActions. Reducers can be combined and are instantiated by the Store.
  ///
  ///       let appReducer = Reducer<AppState, AppActions> { state, action in
  ///         switch action {
  ///         case .increaseCounter:
  ///           state.counter += 1
  ///         case .decreaseCounter:
  ///           state.counter -= 1
  ///         }
  ///       }
  ///
  /// - Parameters:
  ///   - state: State is the current app state..
  ///   - action: Action is the minimum operation that a reducer can perform.
  public init(reduce: @Sendable @escaping (inout S, A) throws -> Void) {
    self.reduce = reduce
  }
  
  public init<LS, LA>(
    _ reducer: Reducer<LS, LA>,
    toState state: WritableKeyPath<S, LS> & Sendable,
    toAction action: WritableKeyPath<A, LA?> & Sendable
  ) {
    self.reduce = { gs, ga in
      guard let la = ga[keyPath: action] else { return }
      try reducer.reduce(&gs[keyPath: state], la)
    }
  }
}


public extension Reducer {
  @Sendable static func logger(
    _ reducer: Reducer<S, A>,
    exclude: @Sendable @escaping (A) -> Bool = { _ in false }
  ) -> Reducer<S, A> where S: Sendable, A: Sendable & Equatable {
    Reducer { state, action in
      try reducer.reduce(&state, action)

      if !exclude(action) {
        print("ℹ️ [[ Action ]]: \(action)")
        print("---")
      }
    }
  }

  @Sendable static func reduce(
    _ reducers: Reducer<S, A>...
  ) -> Reducer<S, A> {

    Reducer { s, a in
      for reducer in reducers {
        try reducer.reduce(&s, a)
      }
    }
  }
}
