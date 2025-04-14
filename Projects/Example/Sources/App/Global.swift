//


import SwiftUI

@propertyWrapper
public struct Global<Value>: DynamicProperty & Sendable {
  
  internal let keyPath: KeyPath<GlobalValues, Value> & Sendable
  /// The current value of the dependency value property.
  public var wrappedValue: Value {
    GlobalValues()[keyPath]
  }
  /// Creates a dependency property to read the specified key path.
  public init(_ keyPath: KeyPath<GlobalValues, Value> & Sendable) {
    self.keyPath = keyPath
  }
}

public struct GlobalValues: Sendable {
  /// Accesses the dependency  value associated with a custom key.
  public subscript<T>(_ keyPath: KeyPath<GlobalValues, T>) -> T {
    self[keyPath: keyPath]
  }
}
