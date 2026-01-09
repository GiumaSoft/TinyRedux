// Store.swift
// TinyRedux

import Foundation
import Observation
import SwiftUI

/// A top-level type alias for sendable errors.
public typealias SendableError = any Error

/// Store
///
/// Central hub that holds state, reducers, middlewares, and resolvers.
@MainActor
@Observable
@dynamicMemberLookup
public final class Store<State: ReduxState, Action: ReduxAction> {

    // MARK: - Properties

    @ObservationIgnored
    var _state: State

    let onLog: ((Log) -> Void)?

    @ObservationIgnored
    nonisolated let worker: DispatchWorker

    // MARK: - Init

    public init(
        initialState: State,
        middlewares: [AnyMiddleware<State, Action>],
        resolvers: [AnyResolver<State, Action>],
        reducers: [AnyReducer<State, Action>],
        onLog: ((Log) -> Void)? = nil
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

    public var state: State.ReadOnly {
        _state.readOnly
    }

    /// Accesses read-only state via dynamic member lookup.
    public subscript<Value>(dynamicMember keyPath: KeyPath<State.ReadOnly, Value>) -> Value {
        state[keyPath: keyPath]
    }
}
