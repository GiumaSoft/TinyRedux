// swift-tools-version: 6.2


import SwiftUI


extension Store {
  /// Creates a SwiftUI `Binding` that reads from state and dispatches an action on write.
  ///
  /// - Parameters:
  ///   - keyPath: Key path to the state property to bind.
  ///   - action: Closure that maps the new value to an action; return `nil` to skip dispatch.
  /// - Returns: A `Binding<T>` suitable for SwiftUI controls.
  public func bind<T>(
    _ keyPath: KeyPath<State, T>,
    maxDispatchable limit: UInt = 0,
    _ action: @escaping (T) -> Action?
  ) -> Binding<T> {
    Binding {
      self.state[keyPath: keyPath]
    } set: { newValue in
      if let action = action(newValue) {
        self.dispatch(maxDispatchable: limit, action)
      }
    }
  }
}

extension Store {
  #if targetEnvironment(simulator)
  /// Creates a SwiftUI `Binding` that reads and writes state directly, bypassing the dispatch pipeline.
  ///
  /// Simulator-only. Intended for SwiftUI previews where a full reducer setup is unnecessary.
  ///
  /// - Parameter keyPath: Writable key path to the state property to bind.
  /// - Returns: A `Binding<T>` that mutates state in place.
  public func bind<T>(
    _ keyPath: WritableKeyPath<State, T>
  ) -> Binding<T> {
    Binding {
      self.state[keyPath: keyPath]
    } set: { newValue in
      self.state[keyPath: keyPath] = newValue
    }
  }
  #endif
}
