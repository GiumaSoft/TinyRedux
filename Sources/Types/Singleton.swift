//


import Foundation


enum Singleton {
  static private var instances = [ObjectIdentifier: Any]()
  static private let lock = NSLock()
  
  static func getInstance<T>(buildInstance: () -> T) -> T {
    lock.lock()
    defer { lock.unlock() }
    
    let name = ObjectIdentifier(T.self)
    if let wrappedInstance = instances[name] as? Wrapped<T> {
      return wrappedInstance.value
    }
    
    let instance = buildInstance()
    instances[name] = Wrapped(value: instance)
    return instance
  }
  
  private struct Wrapped<Value> {
    let value: Value
  }
}
