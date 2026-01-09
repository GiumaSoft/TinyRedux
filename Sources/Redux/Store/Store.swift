// swift-tools-version: 6.0


import Collections
import Foundation
import Observation
import SwiftUI


/// A main-actor store that queues actions and starts middleware/reducer processing in FIFO order. It
/// owns the mutable state instance, exposes a read-only projection through dynamic member lookup,
/// and provides dispatch helpers for single or batched actions. Actions are buffered to preserve
/// enqueue order and optionally throttled by per-action limits. The store builds a pipeline that
/// runs middleware, optionally resolves errors, and finally applies reducers. Logging hooks can
/// measure execution time for each stage. The dispatcher loop does not block for async middleware or
/// resolver work; if `next` is resumed later, reducer completion order can interleave by design.
///
/// Recommended app setup is a process-lifetime store:
///
/// ```swift
/// var mainStore: Store<AppState, AppActions> { .main }
///
/// extension Store where S == AppState, A == AppActions {
///   static let main = Store(
///     initialState: AppState(),
///     middlewares: [
///       mainMiddleware
///     ],
///     resolvers: [
///       mainResolver
///     ],
///     reducers: [
///       mainReducer
///     ],
///     onLog: { log in
///       let message = logFormatter(log)
///       print(message)
///     }
///   )
/// }
/// ```
@MainActor
@dynamicMemberLookup
public final class Store<S, A> where S : ReduxState, A : ReduxAction {
  /// Mutable backing state stored by this store instance.
  internal var state: S
  /// Middleware chain executed for dispatched actions, stored in reverse order.
  internal let middlewares: [Middleware<S, A>]
  /// Resolver chain invoked when middleware throws errors.
  internal let resolvers: [Resolver<S, A>]
  /// Reducer list applied sequentially to mutate state.
  internal let reducers: [Reducer<S, A>]
  /// Optional logger callback used for diagnostics and timing.
  internal let onLog: ((Store.Log) -> Void)?
  /// Queue of pending actions awaiting processing.
  internal var actionBuffer: Deque<A>
  /// Counts buffered occurrences for each action to enforce limits.
  internal var bufferedActionCount: [A: UInt]
  /// Tracks whether the dispatcher loop is currently active.
  internal var isDispatcherRunning: Bool
  /// Lazily built action processor combining middleware, resolver, and reducer pipelines.
  internal lazy var dispatchProcess: @MainActor (A) -> Void = buildDispatchProcess()
  
  /// Creates a store with initial state and pipeline components, initializes buffers and counters,
  /// and prepares logging so dispatching can process actions sequentially on the MainActor safely
  /// for each enqueued action. Creates a store with the given state, middleware chain, and
  /// reducers.
  /// - Parameters:
  ///   - initialState: The initial state of the store.
  ///   - middlewares: Middleware applied in the provided order.
  ///   - resolvers: Resolver chain invoked on middleware errors.
  ///   - reducers: Reducers applied in the provided order.
  ///   - onLog: Used to log middleware and reducer processing action and performance.
  public init(
    initialState: S,
    middlewares: [Middleware<S, A>],
    resolvers: [Resolver<S, A>],
    reducers: [Reducer<S, A>],
    onLog: ((Store.Log) -> Void)? = nil
  ) {
    self.state = initialState
    self.middlewares = middlewares.reversed()
    self.resolvers = resolvers.reversed()
    self.reducers = reducers
    self.onLog = onLog
    self.actionBuffer = Deque()
    self.bufferedActionCount = [:]
    self.isDispatcherRunning = false
  }
  
  /// Exposes read-only state through dynamic member lookup, forwarding key paths to the read-only
  /// projection to support observation without permitting mutation from outside the store in UI
  /// contexts and tests safely. Accesses read-only state via dynamic member lookup.
  public subscript<Value>(dynamicMember keyPath: KeyPath<S.ReadOnly, Value>) -> Value {
    state.readOnly[keyPath: keyPath]
  }
}
