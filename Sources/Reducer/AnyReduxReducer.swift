//


import Foundation


/// AnyReduxReducer
///
/// Type-erased wrapper around a ``ReduxReducer``, stored as a closure. Lets you
/// hold heterogeneous reducers in a single array, and lift a feature-local
/// reducer into a parent state/action space (see ``init(_:toState:toAction:)``).
public struct AnyReduxReducer<S, A>: ReduxReducer
where S: ReduxState, A: ReduxAction
{
  /// A stable identifier for logging and metrics.
  public let id: String

  /// The reduction closure that mutates state.
  public let reduce: ReduxReduceHandler<S, A>

  /// Creates a type-erased reducer from a closure.
  ///
  /// - Parameters:
  ///   - id: Identifier for logging and metrics.
  ///   - reduce: Closure that mutates state for a given context.
  public init( id: String,
               _ reduce: @escaping ReduxReduceHandler<S, A> )
  {
    self.id = id
    self.reduce = reduce
  }

  /// Wraps an existing ``ReduxReducer`` conformer via type erasure.
  ///
  /// - Parameter reducer: The reducer to wrap.
  public init<R>(_ reducer: R)
  where R: ReduxReducer, R.S == S, R.A == A
  {
    self.id = reducer.id
    self.reduce = reducer.reduce
  }

  /// Lifts a local reducer into this global state/action space.
  ///
  /// The lifted reducer runs only when `toAction` maps the global action to a
  /// local one; it then reduces the live nested state projected by `toState`.
  ///
  /// - Parameters:
  ///   - reducer: The local reducer to lift.
  ///   - toState: Projects the global state `S` onto the live nested local state.
  ///   - toAction: Maps a global action to the local one (`nil` skips this reducer).
  public init<R>( _ reducer: R,
                  toState ls: @escaping @MainActor (S) -> R.S,
                  toAction keyPath: KeyPath<A, R.A?> & Sendable )
  where R: ReduxReducer
  {
    self.id = reducer.id
    self.reduce = { context in
      guard let la = context.action[keyPath: keyPath] else { return .defaultNext }
      return reducer.reduce(ReduxReducerContext(ls(context.state), la))
    }
  }

  /// Lifts a local reducer using a ``ReduxModuleMap`` (linear or scattered).
  ///
  /// The same mapping value also vends the module's slice, so the projection and
  /// extract are declared once and shared between the lift and the facade.
  ///
  /// - Parameters:
  ///   - reducer: The local reducer to lift.
  ///   - mapping: The module mapping bundling `toState` / `toAction` / `toRootAction`.
  public init<R>( _ reducer: R,
                  moduleMap: ReduxModuleMap<R.S, R.A, S, A> )
  where R: ReduxReducer
  {
    self.id = reducer.id
    self.reduce = { context in
      guard let la = moduleMap.toAction(context.action) else { return .defaultNext }
      return reducer.reduce(ReduxReducerContext(moduleMap.toState(context.state), la))
    }
  }
}
