//


import Foundation
import Synchronization


/// Thread-safe, type-keyed instance container.
///
/// At most one instance of each concrete type is stored. The default
/// container is available via ``shared``; tests can construct their own
/// for isolation. All operations are safe to call from any concurrency
/// context — internal storage is protected by `Mutex`, never by actor
/// isolation.
///
/// ## Deadlock safety
///
/// `build` closures passed to ``getInstance(build:)`` and
/// ``createInstance(build:)`` run **outside** the lock, so a builder
/// is free to call back into the same container without deadlocking.
/// If two threads race to build the same type, both invoke `build`
/// but only the first stored instance wins; the loser's instance is
/// discarded. Builders should therefore be idempotent and side-effect
/// free where possible.
public enum Singleton: Sendable {

  private static let storage: Mutex<[ObjectIdentifier: any Sendable]> = .init([:])

  /// Returns the cached instance for `T`, building and storing one
  /// if absent. The `build` closure runs outside the internal lock,
  /// making reentrant calls safe.
  public static func getInstance<T, E>( build: () throws(E) -> T ) throws(E) -> T
  where T: Sendable, E: Error
  {
    if let cached = peek(T.self) {

      return cached
    }
    let candidate = try build()

    return storage.withLock { dict in
      if let existing = dict[ObjectIdentifier(T.self)] as? T {

        return existing
      }
      dict[ObjectIdentifier(T.self)] = candidate

      return candidate
    }
  }

  /// Builds a new instance of `T` and replaces any existing one.
  ///
  /// The `build` closure runs outside the internal lock, so concurrent
  /// calls for the same `T` will each invoke `build`; the last write
  /// to the lock wins. Builders with observable side effects should
  /// account for this.
  @discardableResult
  public static func createInstance<T, E>( build: () throws(E) -> T ) throws(E) -> T
  where T: Sendable, E: Error
  {
    let instance = try build()
    storage.withLock { $0[ObjectIdentifier(T.self)] = instance }

    return instance
  }

  /// Reads the cached instance for `T` without building. Returns `nil`
  /// when no instance is currently stored.
  public static func peek<T>(_ type: T.Type) -> T? where T: Sendable {
    storage.withLock { $0[ObjectIdentifier(T.self)] as? T }
  }

  /// Returns `true` if an instance of `T` is currently cached.
  public static func contains<T>(_ type: T.Type) -> Bool where T: Sendable {
    storage.withLock { $0[ObjectIdentifier(T.self)] != nil }
  }

  /// Removes and returns the cached instance for the given type, or
  /// `nil` if none was stored.
  @discardableResult
  public static func remove<T>(_ type: T.Type) -> T? where T: Sendable {
    storage.withLock { $0.removeValue(forKey: ObjectIdentifier(T.self)) as? T }
  }

  /// Removes all cached instances.
  public static func removeAll(keepingCapacity: Bool = false) {
    storage.withLock { $0.removeAll(keepingCapacity: keepingCapacity) }
  }
}
