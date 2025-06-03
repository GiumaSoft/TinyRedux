//


import SwiftUI

/// ReduxState
///
///
public protocol ReduxState: Observable, Sendable {
  associatedtype ReadOnly: Sendable
  
  var readOnly: ReadOnly { get }
}
/// ReduxAction
///
///
public protocol ReduxAction: Equatable & Sendable { }


/// Store
///
///
@MainActor
@dynamicMemberLookup
public final class Store<S, A> where S : ReduxState, A : ReduxAction {
  
  var state: S
  private var actions: [A]
  private var reducers: [Reducer<S, A>]
  private var middlewares: [Middleware<S, A>]
  private var isRunning: Bool = false
  
  private lazy var process: (A) async throws -> Void = {
    self.middlewares.reduce(
      { action in try self.reduce(action) },
      { next, middleware in
        { action in
          try await middleware.run(
            RunArguments<S, A>(self.state.readOnly, self.dispatch, next, action)
          )
        }
      }
    )
  }()
  
  public nonisolated init(
    initialState state: S,
    reducers: [Reducer<S, A>],
    middlewares: [Middleware<S, A>]
  ) {
    self.state = state
    self.actions = []
    self.reducers = reducers
    self.middlewares = middlewares
  }
  
  public subscript<T>(dynamicMember keyPath: KeyPath<S.ReadOnly, T>) -> T {
    self.state.readOnly[keyPath: keyPath]
  }
  
  @Sendable
  public nonisolated func dispatch(_ actions: [A]) {
    Task { @MainActor [weak self] in
      guard let self else { return }
      self.actions.append(contentsOf: actions.reversed())
      await self.run()
    }
  }
  
  @Sendable
  public nonisolated func dispatch(_ actions: A...) {
    Task { @MainActor [weak self] in
      guard let self else { return }
      self.actions.append(contentsOf: actions.reversed())
      await self.run()
    }
  }
  
  @Sendable
  public nonisolated func dispatch(_ action: A) {
    Task { @MainActor [weak self] in
      guard let self else { return }
      self.actions.append(action)
      await self.run()
    }
  }
  
  private func run() async {
    if !isRunning {
      defer { isRunning = false }
      
      isRunning = true
      while let action = actions.first {
        actions.removeFirst()
        do {
          try await process(action)
        } catch {
          debugPrint(error)
        }
      }
    }
  }
  
  private func reduce(_ action: A) throws {
    var newState = self.state
    for reducer in self.reducers {
      try reducer.reduce(&newState, action)
    }
    self.state = newState
  }
}

extension Store {
  /// Bind
  ///
  ///
  @MainActor
  public func bind<T>(_ keyPath: WritableKeyPath<S, T>) -> Binding<T> {
    Binding {
      self.state[keyPath: keyPath]
    } set: { newValue in
      self.state[keyPath: keyPath] = newValue
    }
  }
  /// Bind
  ///
  ///
  @MainActor
  public func bind<T>(_ keyPath: KeyPath<S, T>, _ action: @escaping (T) -> A) -> Binding<T> {
    Binding {
      self.state[keyPath: keyPath]
    } set: { newValue in
      self.dispatch(action(newValue))
    }
  }
}
