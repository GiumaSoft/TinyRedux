//


import SwiftUI


@frozen @propertyWrapper
public struct Global<Value>: DynamicProperty {
  ///
  internal let keyPath: KeyPath<GlobalValues, Value>
  
  /// The current value of the dependency value property.
  public var wrappedValue: Value {
    GlobalValues.shared[keyPath]
  }
  
  /// Creates a dependency property to read the specified key path.
  public init(_ keyPath: KeyPath<GlobalValues, Value>) {
    self.keyPath = keyPath
  }
}

public struct GlobalValues: Sendable {
  ///
  static let shared = GlobalValues()
  
  /// Accesses the dependency  value associated with a custom key.
  public subscript<T>(_ keyPath: KeyPath<GlobalValues, T>) -> T {
    self[keyPath: keyPath]
  }
}
