//


import Foundation


enum Singleton  {
  @MainActor
  @inline(__always)
  static func getInstance<T>(build builder: () throws -> T) rethrows -> T {
    try Container.main.getInstance(build: builder)
  }
}


private extension Singleton {
  final class Container {
    private struct Wrapped<Value> { let value: Value }
    private var instances = [ObjectIdentifier: Any]()
    
    static let main = Container()
    
    func getInstance<T>(build: () throws -> T) rethrows -> T {
      let key = ObjectIdentifier(T.self)
      
      if let wrapped = instances[key] as? Wrapped<T> {
        return wrapped.value
      }
      
      let instance = try build()
      instances[key] = Wrapped(value: instance)
      return instance
    }
  }
}
