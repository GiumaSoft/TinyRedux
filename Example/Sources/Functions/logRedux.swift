//


import Foundation
import Logging
import TinyRedux


func logRedux<S, A>(_ log: Store<S, A>.Log) where S : ReduxState, A : ReduxAction {
  switch log {
  ///
  case let .middleware(id, action, duration, .next):
    logger.info("processed action.",
      metadata: [
        "id": "\(id)",
        "action": "\(action)",
        "duration": "\(duration.fmt())",
        "exit": "next"
      ],
      source: "MIDDLEWARE"
    )
  ///
  case let .middleware(id, action, duration, .nextAs):
    logger.info("processed action.",
      metadata: [
        "id": "\(id)",
        "action": "\(action)",
        "duration": "\(duration.fmt())",
        "exit": "nextAs"
      ],
      source: "MIDDLEWARE"
    )
  ///
  case let .middleware(id, action, duration, .exit(.success)):
    logger.info("processed action.",
      metadata: [
        "id": "\(id)",
        "action": "\(action)",
        "duration": "\(duration.fmt())",
        "exit": "exit(.success)"
      ],
      source: "MIDDLEWARE"
    )
  ///
  case let .middleware(id, action, duration, .resolve):
    logger.error("failed to process action and forward resolver.",
      metadata: [
        "id": "\(id)",
        "action": "\(action)",
        "duration": "\(duration.fmt())",
        "exit": "resolve"
      ],
      source: "MIDDLEWARE"
    )
  ///
  case let .middleware(id, action, duration, .exit(.done)):
    logger.info("processed action and exit pipeline.",
      metadata: [
        "id": "\(id)",
        "action": "\(action)",
        "duration": "\(duration.fmt())",
        "exit": "exit(.done)"
      ],
      source: "MIDDLEWARE"
    )
  ///
  case let .middleware(id, action, duration, .exit(.failure)):
    logger.error("failed to process action and exit pipeline.",
      metadata: [
        "id": "\(id)",
        "action": "\(action)",
        "duration": "\(duration.fmt())",
        "exit": "exit(.failure)"
      ],
      source: "MIDDLEWARE"
    )
  ///
  case let .reducer(id, action, duration, .next):
    logger.info("mutated state.",
      metadata: [
        "id": "\(id)",
        "action": "\(action.debugDescription)",
        "duration": "\(duration.fmt())",
        "exit": "next"
      ],
      source: "REDUCER"
    )
  ///
  case let .reducer(id, action, duration, .done):
    logger.info("mutated state.",
      metadata: [
        "id": "\(id)",
        "action": "\(action.debugDescription)",
        "duration": "\(duration.fmt())",
        "exit": "done"
      ],
      source: "REDUCER"
    )
  ///
  case let .resolver(id, action, duration, .exit(.success), error):
    logger.info("resolved error \"\(error)\"",
      metadata: [
        "id": "\(id)",
        "action": "\(action)",
        "duration": "\(duration.fmt())",
        "exit": "exit(.success)"
      ],
      source: "RESOLVER"
    )
  ///
  case let .resolver(id, action, duration, .reduce, error):
    logger.info("resolved error \"\(error)\"",
      metadata: [
        "id": "\(id)",
        "action": "\(action)",
        "duration": "\(duration.fmt())",
        "exit": "reduce"
      ],
      source: "RESOLVER"
    )
  ///
  case let .resolver(id, action, duration, .reduceAs, error):
    logger.info("resolved error \"\(error)\"",
      metadata: [
        "id": "\(id)",
        "action": "\(action)",
        "duration": "\(duration.fmt())",
        "exit": "reduceAs"
      ],
      source: "RESOLVER"
    )
  ///
  case let .resolver(id, action, duration, .next, error):
    logger.info("resolved error \"\(error)\"",
      metadata: [
        "id": "\(id)",
        "action": "\(action)",
        "duration": "\(duration.fmt())",
        "exit": "next"
      ],
      source: "RESOLVER"
    )
  ///
  case let .resolver(id, action, duration, .nextAs, error):
    logger.info("resolved error \"\(error)\"",
      metadata: [
        "id": "\(id)",
        "action": "\(action)",
        "duration": "\(duration.fmt())",
        "exit": "nextAs"
      ],
      source: "RESOLVER"
    )
  ///
  case let .resolver(id, action, duration, .exit(.done), error):
    logger.error("failed to resolve error \"\(error)\"",
      metadata: [
        "id": "\(id)",
        "action": "\(action)",
        "duration": "\(duration.fmt())",
        "exit": "exit(.done)"
      ],
      source: "RESOLVER"
    )
  ///
  case let .resolver(id, action, duration, .exit(.failure), error):
    logger.error("failed to resolve error \"\(error)\"",
      metadata: [
        "id": "\(id)",
        "action": "\(action)",
        "duration": "\(duration.fmt())",
        "exit": "exit(.failure)"
      ],
      source: "RESOLVER"
    )
  ///
  case .store(let message):
    logger.info("\(message)", source: "STORE")
  ///
  case .middleware(_, _, _, .task),
       .middleware(_, _, _, .deferred),
       .middleware(_, _, _, .defaultNext),
       .resolver(_, _, _, .defaultNext, _),
       .reducer(_, _, _, .defaultNext):
    break
  }
}

fileprivate extension Duration {
  func fmt() -> String {
    let ms = UInt64(components.seconds * 1_000) +
             UInt64(components.attoseconds / 1_000_000_000_000_000)

    switch ms {
    case 0..<5_000:
      return "\(ms)ms"
    case 5_000..<60_000:
      return "\(ms / 1_000)s"
    case 60_000..<3_600_000:
      return "\(ms / 60_000)m"
    default:
      let h = ms / 3_600_000
      let m = (ms / 60_000) % 60

      return m == 0 ? "\(h)h" : "\(h)h\(m)m"
    }
  }
}
