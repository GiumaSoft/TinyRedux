// Store.swift
// TinyRedux

import Foundation
import Observation
import SwiftUI

/// Store
///
/// Central hub that holds state, reducers, middlewares, and resolvers.
@MainActor
@Observable
@dynamicMemberLookup
public final class Store<S: ReduxState, A: ReduxAction> {

    // MARK: - Properties

    @ObservationIgnored
    var _state: S

    let onLog: (@Sendable (Log) -> Void)?

    @ObservationIgnored
    nonisolated let worker: DispatchWorker

    // MARK: - Init

    public init(
        initialState: S,
        middlewares: [AnyMiddleware<S, A>],
        resolvers: [AnyResolver<S, A>],
        reducers: [AnyReducer<S, A>],
        onLog: (@Sendable (Log) -> Void)? = nil
    ) {
        self._state = initialState
        self.onLog = onLog
        self.worker = DispatchWorker(
            middlewares: middlewares,
            resolvers: resolvers,
            reducers: reducers,
            onLog: onLog
        )
        self.worker.store = self
    }

    deinit {
        worker.dispatcher.finish()
    }

    // MARK: - Public API

    public var state: S.ReadOnly {
        _state.readOnly
    }

    /// Accesses read-only state via dynamic member lookup.
    public subscript<Value>(dynamicMember keyPath: KeyPath<S.ReadOnly, Value>) -> Value {
        state[keyPath: keyPath]
    }
}
