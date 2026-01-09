// swift-tools-version: 6.0


import Foundation


/// `Middleware` is a composable Redux module that intercepts actions before state mutation. It
/// represents a composable interception layer that runs before reducers, enabling side effects,
/// conditional routing, and error supervision. Each middleware is identified for logging and
/// metrics, multiple middleware can be chained deterministically. This keeps state mutation
/// isolated, predictable, and debuggable across complex action flows. Use it to centralize policies
/// and cross- cutting concerns.
///
/// Middleware receives a `MiddlewareContext`, and can inspect state, dispatch new actions, start
/// async job, and decide whether the pipeline continues. Calling `next` forwards the action to the
/// next middleware or reducers; omitting it intentionally stops the flow. Use middleware for side
/// effects, orchestration, logging, networking, and conditional control of the action pipeline.
///
/// Middleware always executes on `@MainActor`. It can launch asynchronous job on other threads via
/// (managed) `context.runTask` or (unmanaged) `Task`. Middleware context APIs (like `next`,
/// `dispatch`, and `complete`) are main-actor isolated; using them from a different actor requires
/// a hop back to the MainActor:
///
/// Action enqueue order is FIFO for dispatch start, but reducer completion order may interleave when
/// `next` is resumed asynchronously. This is intentional to keep the dispatcher non-blocking.
///
/// Middlware intercept and consume exceptions generated errors that are `thrown` by syncronous or
/// asyncronous operations (when using `context.runTask`) feeding the `Resolver` chain for a
/// `remediation` attempt before state mutation. For unmanaged `Task`, you must catch errors
/// yourself and handle or forward them via `context.resolve`.
///
/// If you defer `next` in async work, return from that branch so execution does not fall through to
/// a trailing `try next(action)`.
///
///     let (_, dispatch, next, action) = context.args
///
///     switch action {
///     case .fetch:
///       Task {
///         await fetchData()
///         await MainActor.run {
///           dispatch(0, .proceed)
///         }
///       }
///       return
///     default:
///       break
///     }
///
///     try next(action)
///
@frozen public struct Middleware<S, A>: AnyMiddleware where S : ReduxState, A : ReduxAction {
  /// The stable identity of the entity associated with this instance.
  public let id: String
  /// Stored middleware handler invoked by `run` to process the context.
  private let handler: @MainActor @Sendable (MiddlewareContext<S, A>) throws -> Void
  /// Creates a middleware with an identifier and handler closure, storing it for later execution on
  /// the MainActor when actions pass through the middleware chain during dispatch processing for
  /// each action. Constructs an identifiable Middleware with a given context handler. The handler
  /// is stored and later invoked by `run`, on the MainActor, enabling composition and separation of
  /// concerns across middleware layers. Use this initializer to supply your custom processing
  /// function, while keeping middleware construction lightweight and consistent across chain
  /// elements.
  ///
  /// - Parameters:
  ///   - id: Identifier for logging and metrics purpose.
  ///   - handler: The middleware logic handler.
  public init(id: String, handler: @escaping @MainActor @Sendable (MiddlewareContext<S, A>) throws -> Void) {
    self.id = id
    self.handler = handler
  }
  /// Wraps another middleware by capturing its identifier and delegating run calls, enabling type
  /// erasure and uniform storage within middleware arrays without changing execution semantics or
  /// ordering behavior across chains safely. Wraps any conforming middleware by capturing its
  /// identifier and run behavior, enabling type erasure into Middleware while preserving execution
  /// semantics and allowing uniform storage in middleware chains and arrays.
  ///
  /// - Parameter middleware: The custom middleware to wrap.
  public init<M>(_ middleware: M) where M : AnyMiddleware, M.S == S, M.A == A {
    self.id = middleware.id
    self.handler = { context in try middleware.run(context) }
  }
  /// Executes the stored middleware handler on the MainActor with the provided context, allowing
  /// inspection, dispatch, error handling, and optional forwarding to the next middleware or
  /// reducers for this action path. Executes the stored middleware handler on the MainActor with
  /// the provided context, allowing it to inspect state, dispatch actions, handle errors, and
  /// decide whether to continue the pipeline.
  ///
  /// - Parameter context: The middleware context.
  @MainActor
  public func run(_ context: MiddlewareContext<S, A>) throws {
    try handler(context)
  }
}
