//


import SwiftUI


extension Store {

  /// Creates a SwiftUI `Binding` that reads from state and dispatches an action on write.
  ///
  /// - Parameters:
  ///   - keyPath: Key path to the state property to bind.
  ///   - limit: Maximum number of buffered actions with the same `id`. `0` means unlimited.
  ///   - action: Closure that maps the new value to an action; return `nil` to skip dispatch.
  /// - Returns: A `Binding<T>` suitable for SwiftUI controls.
  @MainActor
  public func bind<T>(
    _ keyPath: KeyPath<S, T>,
    maxDispatchable limit: UInt = 0,
    _ action: @escaping (T) -> A?
  ) -> Binding<T> {
    Binding(
      get: { self._state[keyPath: keyPath] },
      set: { newValue in
        if let action = action(newValue) {
          self.dispatch(maxDispatchable: limit, action)
        }
      }
    )
  }
  
  /// Creates a SwiftUI `Binding` that reads a transformed value from state and dispatches an action on write.
  ///
  /// - Parameters:
  ///   - keyPath: Key path to the source state property.
  ///   - limit: Maximum number of buffered actions with the same `id`. `0` means unlimited.
  ///   - get: Closure that transforms the source value to the binding type.
  ///   - set: Closure that maps the new transformed value to an action; return `nil` to skip dispatch.
  /// - Returns: A `Binding<U>` suitable for SwiftUI controls.
  @MainActor
  public func bind<T, U>(
    _ keyPath: KeyPath<S, T>,
    maxDispatchable limit: UInt = 0,
    get: @escaping (T) -> U,
    set: @escaping (U) -> A?
  ) -> Binding<U> {
    Binding(
      get: { get(self._state[keyPath: keyPath]) },
      set: { newValue in
        if let action = set(newValue) {
          self.dispatch(maxDispatchable: limit, action)
        }
      }
    )
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
  @MainActor
  public func bind<T>(
    _ keyPath: WritableKeyPath<S, T>
  ) -> Binding<T> {
    Binding {
      self._state[keyPath: keyPath]
    } set: { newValue in
      self._state[keyPath: keyPath] = newValue
    }
  }
  #endif
}
