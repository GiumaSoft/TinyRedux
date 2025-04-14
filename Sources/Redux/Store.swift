//


import Combine
import Foundation
import Observation
import SwiftUI


/// Store
///
@MainActor
@Observable
@dynamicMemberLookup public final class Store<S, A>: Sendable where S: Sendable, A: Sendable & Equatable {
  
  private(set) var state: S
  
  @ObservationIgnored private let reducers: [Reducer<S, A>]
  @ObservationIgnored private let middlewares: [AnyMiddleware<S, A>]
  @ObservationIgnored private var actions: [A]
  @ObservationIgnored private var isRunning: Bool
  
  @ObservationIgnored private lazy var _process: @MainActor @Sendable (A) async throws -> Void = {
    self.middlewares.reduce(
      { @MainActor @Sendable action in try self.reduce(action) },
      { next, middleware in
        { action in
          try await middleware.run(
            RunArguments(self.getState, self.dispatch, next, action)
          )
        }
      }
    )
  }()
  
  public nonisolated init(
    initialState state: S,
    reducers: [Reducer<S, A>],
    middlewares: [AnyMiddleware<S, A>]
  ) {
    self._state = state
    self.reducers = reducers
    self.middlewares = middlewares
    self.actions = []
    self.isRunning = false
  }
  
  public subscript<T>(dynamicMember keyPath: KeyPath<S, T>) -> T {
    self.state[keyPath: keyPath]
  }
  
  @Sendable
  public nonisolated func dispatch(_ action: A) {
    Task { @MainActor in
      self.actions.append(action)
      await run()
    }
  }
  
  @Sendable
  public nonisolated func dispatch(_ actions: A...) {
    Task { @MainActor in
      self.actions.append(contentsOf: actions)
      await run()
    }
  }
  
  @Sendable
  private func getState() async -> S {
    self.state
  }
  
  private func reduce(_ action: A) throws {
    var newState = self.state
    for reducer in reducers {
      try reducer.reduce(&newState, action)
    }
    self.state = newState
  }
  
  private func run() async {
    guard !isRunning else { return }
    defer { isRunning = false }
    
    isRunning = true
    while let action = actions.first {
      actions.removeFirst()
      do {
        try await _process(action)
      } catch {
        debugPrint(error)
      }
    }
  }
}

extension Store {
  
  @MainActor
  public func bind<T>(_ keyPath: KeyPath<S, T>, _ action: @escaping (T) -> A) -> Binding<T> {
    Binding {
      self.state[keyPath: keyPath]
    } set: { [weak self] newValue in
      self?.dispatch(action(newValue))
    }
  }
}
