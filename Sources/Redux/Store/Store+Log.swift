//


import Foundation


extension Store {
  public enum Log {
    /// (middleware.id, error, action, elaspedTime, succeded)
    case middleware(String, (any Error)?, A, UInt64, Bool)
    /// (resolver.id, middleware.id, error, action, elaspedTime, succeded)
    case resolver(String, String, any Error, A, UInt64, Bool)
    /// (reducer.id, action, elaspedTime, succeded)
    case reducer(String, A, UInt64, Bool)
    /// (message)
    case store(String)
  }
}
