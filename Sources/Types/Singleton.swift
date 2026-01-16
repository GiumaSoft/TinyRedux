//


import Foundation


@MainActor
enum Singleton {
  @inline(__always)
  /// Returns the stored singleton instance for the given type, optionally overriding by removing
  /// any existing instance before building a new one via the builder closure on the MainActor
  /// safely here.
  static func getInstance<T>(override shouldOverride: Bool = false, build builder: () throws -> T) rethrows -> T {
    try Container.main.getInstance(override: shouldOverride, build: builder)
  }

  /// Removes the stored singleton instance for the provided type, allowing subsequent getInstance
  /// calls to rebuild it, typically used in tests or controlled resets on the MainActor when needed
  /// by callers.
  static func remove<T>(_ valueType: T.Type) {
    Container.main.remove(valueType)
  }
  
  /// Clears all stored singleton instances, optionally keeping dictionary capacity, which is useful
  /// for test isolation or full resets during app bootstrap on the MainActor when global state must
  /// be recreated.
  static func removeAll(keepingCapacity: Bool = false) {
    Container.main.removeAll(keepingCapacity: keepingCapacity)
  }
}

private extension Singleton {
  @MainActor
  /// Container stores singleton instances keyed by type identifiers, providing get, remove, and
  /// reset operations for the Singleton facade. It is isolated to the MainActor to keep access
  /// serialized. Each stored value is wrapped to preserve type safety while using an untyped
  /// dictionary. The container supports optional override to rebuild instances during testing or
  /// controlled reinitialization, and exposes a shared main instance. It is private to the module
  /// and intended only for Store lifecycle management, not general dependency injection. Its simple
  /// API avoids concurrency hazards and keeps instantiation deterministic for callers.
  final class Container {
    /// Wrapped is a tiny generic container used to preserve concrete type information when storing
    /// values in an Any dictionary. By boxing the value, Container can downcast safely using the
    /// generic type parameter and avoid accidental collisions between unrelated types sharing the
    /// same identifier. The struct is intentionally minimal: it stores a single value and provides
    /// no additional behavior. Its presence keeps the singleton map type-safe without exposing
    /// generics at the dictionary level, while remaining lightweight and inlined by the compiler.
    /// It also enables clear intent and avoids repeated casting logic.
    private struct Wrapped<Value> {
      /// Stored instance value.
      let value: Value
    }
    /// Stores instances keyed by type identifiers.
    private var instances = [ObjectIdentifier: Any]()
    /// Shared container instance used by Singleton.
    static let main = Container()
    
    /// Returns a cached instance for the type, optionally overriding by removing and rebuilding it
    /// through the builder closure, and stores the result in the instances map for future retrieval
    /// requests.
    func getInstance<T>(override shouldOverride: Bool = false, build: () throws -> T) rethrows -> T {
      let key = ObjectIdentifier(T.self)
      if shouldOverride {
        instances.removeValue(forKey: key)
      } else if let wrapped = instances[key] as? Wrapped<T> {
        return wrapped.value
      }
      
      let instance = try build()
      instances[key] = Wrapped(value: instance)
      return instance
    }
    
    /// Removes the cached instance associated with the given type, leaving other instances intact
    /// and allowing a future getInstance call to recreate it as needed by the builder closure later
    /// on.
    func remove<T>(_ valueType: T.Type) {
      instances.removeValue(
        forKey: ObjectIdentifier(T.self)
      )
    }
    
    /// Removes every stored instance, optionally preserving dictionary capacity to reduce
    /// reallocations, providing a clean slate for tests or full app reinitialization workflows on
    /// demand in the MainActor context when required.
    func removeAll(keepingCapacity: Bool = false) {
      instances.removeAll(keepingCapacity: keepingCapacity)
    }
  }
}
