// swift-tools-version: 6.2


extension Store {
  public enum Log: Sendable {
    case middleware(String, Action, Duration, Result<Bool, Error>)
    case reducer(String, Action, Duration, Bool)
    case resolver(String, Action, Duration, Bool, Error)
    case store(String)
  }
}
