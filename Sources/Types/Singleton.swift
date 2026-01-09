//


import Foundation


/// Type-keyed singleton container for ``Store`` lifecycle management.
@frozen @MainActor
public enum Singleton {
  private static var storage = [ObjectIdentifier: Any]()
  
  /// Returns the cached instance for `T`, or creates and stores a new one via ``createInstance(build:)``.
  public static func getInstance<T>(build: () throws -> T) rethrows -> T {
    try (
      storage[ObjectIdentifier(T.self)] as? T
    ) ?? createInstance(build: build)
  }

  /// Builds a new instance of `T` and stores it, replacing any existing one.
  @discardableResult
  public static func createInstance<T>(build: () throws -> T) rethrows -> T {
    let instance = try build()
    storage[ObjectIdentifier(T.self)] = instance
    return instance
  }

  /// Removes and returns the cached instance for the given type, or `nil` if none was stored.
  @discardableResult
  public static func remove<T>(_ valueType: T.Type) -> T? {
    storage.removeValue(forKey: ObjectIdentifier(T.self)) as? T
  }

  /// Removes all cached instances.
  public static func removeAll(keepingCapacity: Bool = false) {
    storage.removeAll(keepingCapacity: keepingCapacity)
  }
}

