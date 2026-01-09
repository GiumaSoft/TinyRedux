// swift-tools-version: 6.0


import SwiftUI


extension Store {
  /// Creates a SwiftUI binding that reads state via key path and dispatches an optional action on
  /// changes, honoring the per-action limit for consistent updates and logging in UI contexts
  /// safely. Creates a binding that dispatches an action when the value changes.
  /// - Parameters:
  ///   - keyPath: Key path into the state.
  ///   - limit: Maximum buffered instances of the same action; 0 means unlimited.
  ///   - action: Maps the new value into an optional action to dispatch.
  public func bind<T>(_ keyPath: KeyPath<S, T>, maxDispatchable limit: UInt = 0, _ action: @escaping (T) -> A?) -> Binding<T> {
    Binding {
      self.state[keyPath: keyPath]
    } set: { newValue in
      if let action = action(newValue) {
        self.dispatch(maxDispatchable: limit, action)
      }
    }
  }
  
#if targetEnvironment(simulator)
  /// Creates a writable binding for simulator previews only, writing directly to state without
  /// dispatching, useful for SwiftUI prototypes while avoiding reducer execution and production
  /// side effects during design iterations safely. Creates a direct writable binding for previews.
  /// 
  /// - Important:
  /// This bypasses reducers and is intended for simulator-only previews.
  public func bind<T>(_ keyPath: WritableKeyPath<S, T>) -> Binding<T> {
    Binding {
      self.state[keyPath: keyPath]
    } set: { newValue in
      self.state[keyPath: keyPath] = newValue
    }
  }
  #endif
}
