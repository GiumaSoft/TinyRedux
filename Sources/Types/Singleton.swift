//


import Foundation


enum Singleton {
  
  @inline(__always)
  static func getInstance<T>(buildInstance: () throws -> T) rethrows -> T {
    try Container.main.getInstance(buildInstance: buildInstance)
  }
}

extension Singleton {
  final class Container: @unchecked Sendable {
    private struct Wrapped<Value> {
      let value: Value
    }
    
    private var instances = [ObjectIdentifier: Any]()
    private let lock = NSLock()
    
    static let main = Container()
    
    @inline(__always)
    func getInstance<T>(buildInstance: () throws -> T) rethrows -> T {
      lock.lock()
      defer { lock.unlock() }
      
      let name = ObjectIdentifier(T.self)
      if let wrappedInstance = instances[name] as? Wrapped<T> {
        return wrappedInstance.value
      }
      
      let instance = try buildInstance()
      instances[name] = Wrapped(value: instance)
      return instance
    }
  }
}
