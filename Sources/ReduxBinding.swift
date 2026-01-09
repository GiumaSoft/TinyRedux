//


import Observation


/// ReduxBinding
///
/// A `Sendable`, UI-agnostic get/set projection over a single value. Unlike
/// SwiftUI's `Binding` it carries no graph/transaction machinery and its `set`
/// writes straight through — so it is used INTERNALLY to back a mapped state's
/// projected properties, never handed to a View (Views mutate via `dispatch`).
public struct ReduxBinding<V>: Sendable
{
  private let read: @MainActor @Sendable () -> V
  private let write: @MainActor @Sendable (V) -> Void

  public init(get: @escaping @MainActor @Sendable () -> V,
              set: @escaping @MainActor @Sendable (V) -> Void)
  {
    self.read = get
    self.write = set
  }

  @MainActor
  public var value: V {
    get { read() }
    nonmutating set { write(newValue) }
  }
}


public extension ReduxBinding {
  /// Read-only binding that ignores writes. For previews.
  static func constant(_ value: V) -> ReduxBinding<V>
  where V: Sendable
  {
    ReduxBinding(get: { value }, set: { _ in })
  }

  /// Binding backed by an internal `@Observable` storage: real write-through with
  /// no root. For tests and standalone previews.
  @MainActor
  static func projected(_ initial: V) -> ReduxBinding<V>
  {
    let storage = ReduxBindingValue(initial)
    return ReduxBinding(get: { storage.value }, set: { storage.value = $0 })
  }
}


/// ReduxBindingValue
///
/// Internal `@Observable` storage used by ``ReduxBinding/projected(_:)`` so a mapped
/// state is observable and write-through even without a root (tests/previews).
@MainActor
@Observable
public final class ReduxBindingValue<V>
{
  public var value: V

  public init(_ value: V)
  {
    self.value = value
  }
}
