//


import Foundation


public struct GlobalValues: Sendable {
  ///
  static let shared = GlobalValues()
  
  /// Accesses the dependency  value associated with a custom key.
  public subscript<T>(_ keyPath: KeyPath<GlobalValues, T>) -> T {
    self[keyPath: keyPath]
  }
}
