//


import Foundation


/// ReduxStoreSlice
///
/// Closure-backed ``ReduxModule`` over local `LS`/`LA`, with the parent `S`/`A`
/// erased into the stored `read`/`send` closures. Built by `ReduxStore.slice(_:)`,
/// this is what a feature View consumes as `any ReduxModule<LS, LA>`. Works for both
/// `.linear` and `.scattered`: only the `read` closure differs.
@MainActor
public final class ReduxStoreSlice<LS, LA>: ReduxModule
where LS: ReduxState, LA: ReduxAction
{
  public typealias S = LS
  public typealias A = LA

  private let read: @MainActor @Sendable () -> LS.ReadOnly
  private let send: @Sendable (LA) -> Void

  public init(read: @escaping @MainActor @Sendable () -> LS.ReadOnly,
              send: @escaping @Sendable (LA) -> Void)
  {
    self.read = read
    self.send = send
  }

  public var state: LS.ReadOnly { read() }

  nonisolated public func dispatch(_ actions: LA...)
  {
    actions.forEach(send)
  }
}
