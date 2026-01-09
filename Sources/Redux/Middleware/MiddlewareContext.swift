// swift-tools-version: 6.0


import Foundation


/// Context passed to a middleware invocation. It provides read-only state, the current action,
/// dispatch and next functions, a completion hook for logging, and a resolve function to forward
/// errors to resolvers. Use next to continue the middleware chain; omit it to stop the pipeline
/// intentionally. Use dispatch to enqueue additional actions, and runTask to execute async work
/// with managed error forwarding. The args tuple supports concise destructuring in handlers. All
/// API entry points are MainActor isolated, so hop back when using them from background tasks to
/// keep UI state safe.
@frozen public struct MiddlewareContext<S, A>: Sendable where S : ReduxState, A : ReduxAction {
  /// Read-only view of the current state.
  public let state: S.ReadOnly
  /// Enqueues one or more actions.
  public let dispatch: @MainActor @Sendable (UInt, A...) -> Void
  /// Forwards the action to the next middleware in the chain. Invokes the next middleware in the
  /// chain. If you do not call `next`, the middleware/reducer pipeline is intentionally interrupted
  /// for the current action. You may also call `next` later (for example after async work) to
  /// resume the chain.
  ///
  /// - Important:
  /// If you want to mutate state only after an async task succeeds, do not call `next` until the task
  /// completes successfully; otherwise reducers may run before the async result is known. If you
  /// defer `next` asynchronously, return from that switch branch to avoid falling through to any
  /// trailing `next(action)` call. Deferred `next` keeps the dispatcher non-blocking, so reducer
  /// completion order may interleave across actions.
  public let next: @MainActor @Sendable (A) throws -> Void
  /// The action currently being processed.
  public let action: A
  /// Marks the current action as handled for logging and timing. Marks the action as handled and
  /// emits timing logs when enabled. Call it explicitly (it is not invoked automatically) so you
  /// can skip logging for default/unhandled actions. `complete` runs on `@MainActor`; hop back if
  /// you're in a background task.
  ///
  ///     let (_, dispatch, next, action) = context.args
  ///
  ///     switch action {
  ///     case .initApp:
  ///       configureApp()
  ///       context.complete()
  ///
  ///       break
  ///     default:
  ///
  ///       break
  ///     }
  ///
  private let onComplete: @MainActor @Sendable (Bool) -> Void
  /// Sends an error to the store's resolver.
  public let resolve: @MainActor @Sendable (any Error) -> Void
  ///
  public typealias Args = (S.ReadOnly, @MainActor @Sendable (UInt, A...) -> Void, @MainActor @Sendable (A) throws -> Void, A)
  /// Tuple of common context fields for quick destructuring. Returns a tuple of the most-used
  /// fields for quick destructuring. Order: `(state, dispatch, next, action)`.
  public var args: Args {
    (state, dispatch, next, action)
  }
  /// Marks the current action as handled for logging and timing. Pass `false` to record an
  /// explicit unhandled completion in logs. Default is `true`.
  @MainActor
  public func complete(_ succeded: Bool = true) {
    onComplete(succeded)
  }
  /// Runs an asynchronous operation, capturing thrown errors and forwarding them to resolve,
  /// returning a Task for optional cancellation or sequencing control when needed by middleware
  /// callers in complex flows safely. Runs an async task and forwards thrown errors to `resolve`.
  /// Use it for async work started inside middleware so errors still flow to the resolver.
  /// - Warning: The task is independent; if you need ordering or cancellation, manage the returned
  /// `Task`.
  ///
  ///     let (_, dispatch, next, action) = context.args
  ///
  ///     switch action {
  ///     case .runEffectDemo:
  ///       context.runTask { @MainActor in
  ///         try await Task.sleep(nanoseconds: 1_000_000_000)
  ///         context.dispatch(0, .setEffectMessage("Done"))
  ///         context.complete()
  ///       }
  ///
  ///       break
  ///     default:
  ///
  ///       break
  ///     }
  ///
  @discardableResult
  public func runTask(priority: TaskPriority? = nil, operation: @escaping @Sendable () async throws -> Void) -> Task<Void, Never> {
    Task(priority: priority) {
      do {
        try await operation()
      } catch {
        await MainActor.run {
          resolve(error)
        }
      }
    }
  }

  init(
    state: S.ReadOnly,
    dispatch: @escaping @MainActor @Sendable (UInt, A...) -> Void,
    next: @escaping @MainActor @Sendable (A) throws -> Void,
    action: A,
    complete: @escaping @MainActor @Sendable (Bool) -> Void,
    resolve: @escaping @MainActor @Sendable (any Error) -> Void
  ) {
    self.state = state
    self.dispatch = dispatch
    self.next = next
    self.action = action
    self.onComplete = complete
    self.resolve = resolve
  }
}
