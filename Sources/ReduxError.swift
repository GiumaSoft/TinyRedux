//


import Foundation


/// ReduxError
///
/// Central error type for the TinyRedux framework — every error the framework itself can
/// produce lives here (app/domain errors are the dev's own types, surfaced via `throw` /
/// `.resolve` / the resolver).
public enum ReduxError: Error, Sendable
{
  /// The dispatcher stream has been terminated (the store/worker is shutting down).
  case terminated

  /// A ``DispatchRateLimit`` (`.limit`/`.throttle`) dropped this action at the dispatch gate.
  case rateLimited

  /// A pending snapshot request was abandoned because the store was torn down
  /// (`Worker.deinit`) before the action could settle — distinct from ``terminated``,
  /// which is a dispatcher-stream end at enqueue time.
  case cancelled
}
