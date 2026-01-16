//


import Foundation


extension Store {
  public enum Log {
    /// (middleware.id, error, action, elaspedTime)
    case middleware(String, (any Error)?, A, UInt64)
    /// (resolver.id, middleware.id, error, action, elaspedTime)
    case resolver(String, String, any Error, A, UInt64)
    /// (reducer.id, action, elaspedTime)
    case reducer(String, A, UInt64)
    /// (message)
    case store(String)
  }
}
