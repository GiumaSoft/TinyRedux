//


import Foundation


@ReduxState
@Observable
@MainActor
final class AuthModuleState: ReduxState
{
  var isAuthenticated: Bool

  nonisolated convenience init()
  {
    self.init(isAuthenticated: false)
  }
}


@ReduxState
@Observable
@MainActor
final class AppState: ReduxState
{
  var counter: Int
  var auth: AuthModuleState

  nonisolated convenience init()
  {
    self.init(counter: 0, auth: AuthModuleState())
  }
}


@ReduxAction
enum AuthModuleActions: ReduxAction
{
  case setAuth(Bool)
}


@ReduxAction
enum AppActions: ReduxAction
{
  case increment
  case decrement
  case authModule(AuthModuleActions)
}

extension AppActions {

  var authModule: AuthModuleActions? {
    guard case let .authModule(authModule) = self else { return nil }
    return authModule
  }
}


let authReducer: AnyReduxReducer<AuthModuleState, AuthModuleActions> = .init(id: "authReducer")
{ context in
  let (state, action) = context.args

  switch action {
  default:
    return .defaultNext
  }

  //return .defaultNext
}


let mainReducer: AnyReduxReducer<AppState, AppActions> = .init(id: "mainReducer")
{ context in
  let (state, action) = context.args

  switch action {
  case .increment:
    state.counter += 1
    return .next
  case .decrement:
    state.counter -= 1
    return .next
  default:
    return .defaultNext
  }
}


extension ReduxStore where S == AppState, A == AppActions {
  static let main = ReduxStore(
    initialState: AppState(),
    reducers: [
      mainReducer,
      AnyReduxReducer(authReducer, toState: { $0.auth }, toAction: \.authModule)
    ]
  )
}
