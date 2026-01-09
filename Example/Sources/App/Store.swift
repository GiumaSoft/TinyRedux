//


import Foundation
import TinyRedux


var sample01Store: Store<Sample01State, Sample01Action> { .main }
var sample02Store: Store<Sample02State, Sample02Action> { .main }
var sample03Store: Store<Sample03State, Sample03Action> { .main }
var sample04Store: Store<Sample04State, Sample04Action> { .main }
var sample05Store: Store<Sample05State, Sample05Action> { .main }
var sample06Store: Store<Sample06State, Sample06Action> { .main }
var sample07Store: Store<Sample07State, Sample07Action> { .main }
var sample08Store: Store<Sample08State, Sample08Action> { .main }
var sample09Store: Store<Sample09State, Sample09Action> { .main }
var sample10Store: Store<Sample10State, Sample10Action> { .main }
var sample11Store: Store<Sample11State, Sample11Action> { .main }
var sample12Store: Store<Sample12State, Sample12Action> { .main }
var sample13Store: Store<Sample13State, Sample13Action> { .main }
var sample14Store: Store<Sample14State, Sample14Action> { .main }
var sample15Store: Store<Sample15State, Sample15Action> { .main }
var sample16Store: Store<Sample16State, Sample16Action> { .main }
var sample17Store: Store<Sample17State, Sample17Action> { .main }
var sample18Store: Store<Sample18State, Sample18Action> { .main }
var sample19Store: Store<Sample19State, Sample19Action> { .main }
var sample20Store: Store<Sample20State, Sample20Action> { .main }
var sample21Store: Store<Sample21State, Sample21Action> { .main }
var uiKitSample01Store: Store<UIKitSample01State, UIKitSample01Action> { .main }


extension Store where S == Sample01State, A == Sample01Action {
  static let main = Store(
    initialState: Sample01State(items: [], total: 0),
    middlewares: [sample01Middleware],
    resolvers: [],
    reducers: [sample01Reducer],
    onLog: { logItem in
      logRedux(logItem)
    }
  )
}


extension Store where S == Sample02State, A == Sample02Action {
  static let main = Store(
    initialState: Sample02State(),
    middlewares: [],
    resolvers: [],
    reducers: [sample02Reducer],
    onLog: { logItem in
      logRedux(logItem)
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
      logRedux(logItem)
    }
  )
}


extension Store where S == Sample04State, A == Sample04Action {
  static let main = Store(
    initialState: Sample04State(),
    middlewares: [],
    resolvers: [],
    reducers: [sample04Reducer],
    onLog: { logItem in
      logRedux(logItem)
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
      logRedux(logItem)
    }
  )
}


extension Store where S == Sample06State, A == Sample06Action {
  static let main = Store(
    initialState: Sample06State(),
    middlewares: [],
    resolvers: [],
    reducers: [sample06Reducer],
    onLog: { logItem in
      logRedux(logItem)
    }
  )
}


extension Store where S == Sample07State, A == Sample07Action {
  static let main = Store(
    initialState: Sample07State(),
    middlewares: [],
    resolvers: [],
    reducers: [sample07Reducer],
    onLog: { logItem in
      logRedux(logItem)
    }
  )
}


extension Store where S == Sample08State, A == Sample08Action {
  static let main = Store(
    initialState: Sample08State(),
    middlewares: [],
    resolvers: [],
    reducers: [sample08Reducer],
    onLog: { logItem in
      logRedux(logItem)
    }
  )
}


extension Store where S == Sample09State, A == Sample09Action {
  static let main = Store(
    initialState: Sample09State(),
    middlewares: [],
    resolvers: [],
    reducers: [sample09Reducer],
    onLog: { logItem in
      logRedux(logItem)
    }
  )
}


extension Store where S == Sample10State, A == Sample10Action {
  static let main = Store(
    initialState: Sample10State(),
    middlewares: [],
    resolvers: [],
    reducers: [sample10Reducer],
    onLog: { logItem in
      logRedux(logItem)
    }
  )
}


extension Store where S == Sample11State, A == Sample11Action {
  static let main = Store(
    initialState: Sample11State(),
    middlewares: [],
    resolvers: [],
    reducers: [sample11Reducer],
    onLog: { logItem in
      logRedux(logItem)
    }
  )
}


extension Store where S == Sample12State, A == Sample12Action {
  static let main = Store(
    initialState: Sample12State(),
    middlewares: [],
    resolvers: [],
    reducers: [sample12Reducer],
    onLog: { logItem in
      logRedux(logItem)
    }
  )
}


extension Store where S == Sample13State, A == Sample13Action {
  static let main = Store(
    initialState: Sample13State(),
    middlewares: [],
    resolvers: [],
    reducers: [sample13Reducer],
    onLog: { logItem in
      logRedux(logItem)
    }
  )
}


extension Store where S == Sample14State, A == Sample14Action {
  static let main = Store(
    initialState: Sample14State(),
    middlewares: [],
    resolvers: [],
    reducers: [sample14Reducer],
    onLog: { logItem in
      logRedux(logItem)
    }
  )
}


extension Store where S == Sample15State, A == Sample15Action {
  static let main = Store(
    initialState: Sample15State(),
    middlewares: [],
    resolvers: [],
    reducers: [sample15Reducer],
    onLog: { logItem in
      logRedux(logItem)
    }
  )
}


extension Store where S == Sample16State, A == Sample16Action {
  static let main = Store(
    initialState: Sample16State(),
    middlewares: [],
    resolvers: [],
    reducers: [sample16Reducer],
    onLog: { logItem in
      logRedux(logItem)
    }
  )
}


extension Store where S == Sample17State, A == Sample17Action {
  static let main = Store(
    initialState: Sample17State(),
    middlewares: [],
    resolvers: [],
    reducers: [sample17Reducer],
    onLog: { logItem in
      logRedux(logItem)
    }
  )
}


extension Store where S == Sample18State, A == Sample18Action {
  static let main = Store(
    initialState: Sample18State(),
    middlewares: [],
    resolvers: [],
    reducers: [sample18Reducer],
    onLog: { logItem in
      logRedux(logItem)
    }
  )
}


extension Store where S == Sample19State, A == Sample19Action {
  static let main = Store(
    initialState: Sample19State(),
    middlewares: [],
    resolvers: [],
    reducers: [sample19Reducer],
    onLog: { logItem in
      logRedux(logItem)
    }
  )
}


extension Store where S == Sample20State, A == Sample20Action {
  static let main = Store(
    initialState: Sample20State(),
    middlewares: [],
    resolvers: [],
    reducers: [sample20Reducer],
    onLog: { logItem in
      logRedux(logItem)
    }
  )
}


extension Store where S == Sample21State, A == Sample21Action {
  static let main = Store(
    initialState: Sample21State(),
    middlewares: [],
    resolvers: [],
    reducers: [sample21Reducer],
    onLog: { logItem in
      logRedux(logItem)
    }
  )
}


extension Store where S == UIKitSample01State, A == UIKitSample01Action {
  static let main = Store(
    initialState: UIKitSample01State(dates: [.now]),
    middlewares: [],
    resolvers: [],
    reducers: [uiKitSample01Reducer],
    onLog: { logItem in
      logRedux(logItem)
    }
  )
}


