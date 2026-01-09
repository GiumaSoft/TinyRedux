//


import Foundation
import TinyRedux


extension GlobalValues {
  var sample01Store: Store<Sample01State, Sample01Action> { .main }
  var sample02Store: Store<Sample02State, Sample02Action> { .main }
  var sample03Store: Store<Sample03State, Sample03Action> { .main }
  var sample04Store: Store<Sample04State, Sample04Action> { .main }
  var sample05Store: Store<Sample05State, Sample05Action> { .main }
  var uiKitSample01Store: Store<UIKitSample01State, UIKitSample01Action> { .main }
}


extension Store where S == Sample01State, A == Sample01Action {
  static let main = Store(
    initialState: Sample01State(),
    middlewares: [],
    resolvers: [],
    reducers: [sample01Reducer],
    onLog: { logItem in
      guard let logMessage = reduxLogFormatter(logItem)
      else { return }
      
      print(logMessage)
    }
  )
}


extension Store where S == Sample02State, A == Sample02Action {
  static let main = Store(
    initialState: Sample02State(),
    middlewares: [
      AnyMiddleware(sample02Middleware)
    ],
    resolvers: [],
    reducers: [sample02Reducer],
    onLog: { logItem in
      guard let logMessage = reduxLogFormatter(logItem)
      else { return }
      
      print(logMessage)
    }
  )
}


extension Store where S == Sample03State, A == Sample03Action {
  static let main = Store(
    initialState: Sample03State(),
    middlewares: [],
    resolvers: [],
    reducers: [sample03Reducer],
    onLog: { logItem in
      guard let logMessage = reduxLogFormatter(logItem)
      else { return }
      
      print(logMessage)
    }
  )
}


extension Store where S == Sample04State, A == Sample04Action {
  static let main = Store(
    initialState: Sample04State(),
    middlewares: [sample04Middleware],
    resolvers: [sample04Resolver],
    reducers: [sample04Reducer],
    onLog: { logItem in
      guard let logMessage = reduxLogFormatter(logItem)
      else { return }
      
      print(logMessage)
    }
  )
}


extension Store where S == Sample05State, A == Sample05Action {
  static let main = Store(
    initialState: Sample05State(),
    middlewares: [],
    resolvers: [],
    reducers: [sample05Reducer],
    onLog: { logItem in
      guard let logMessage = reduxLogFormatter(logItem)
      else { return }
      
      print(logMessage)
    }
  )
}


extension Store where S == UIKitSample01State, A == UIKitSample01Action {
  static let main = Store(
    initialState: UIKitSample01State(),
    middlewares: [],
    resolvers: [],
    reducers: [uiKitSample01Reducer],
    onLog: { logItem in
      guard let logMessage = reduxLogFormatter(logItem)
      else { return }
      
      print(logMessage)
    }
  )
}
