// swift-tools-version: 6.2


import Foundation
import Synchronization


/// Dispatcher
///
/// Serializes action dispatch through an AsyncStream relay with flush support.
/// Two-stream design: upstream (write side) → relay Task → downstream (read side).
/// Flush discards pending actions by hot-swapping the upstream.
/// Thread-safety guaranteed by ``Mutex`` (Synchronization framework).
final class Dispatcher<Action: ReduxAction>: Sendable {
  typealias Stream = AsyncStream<Action>
  typealias StreamContinuation = AsyncStream<Action>.Continuation
  typealias StreamBufferingPolicy = AsyncStream<Action>.Continuation.BufferingPolicy

  private let downstream: Stream
  private let bufferingPolicy: StreamBufferingPolicy
  private let mutex: Mutex<MutableState>

  struct MutableState: ~Copyable {
    var upstream: Stream
    var upstreamContinuation: StreamContinuation
    var generation: UInt64 = 0
    var isConsumed: Bool = false
    var isFinished: Bool = false
    var worker: Task<Void, Never>?
  }

  init(bufferingPolicy: StreamBufferingPolicy = .bufferingOldest(256)) {
    let (upstream, upstreamContinuation) = AsyncStream.makeStream(
      of: Action.self,
      bufferingPolicy: bufferingPolicy
    )

    let (downstream, downstreamContinuation) = AsyncStream.makeStream(
      of: Action.self,
      bufferingPolicy: bufferingPolicy
    )

    self.downstream = downstream
    self.bufferingPolicy = bufferingPolicy
    self.mutex = Mutex(MutableState(
      upstream: upstream,
      upstreamContinuation: upstreamContinuation )
    )

    let task = Task { [weak self] in
      while let self, !Task.isCancelled {
        let (upstream, gen) = mutex.withLock { ($0.upstream, $0.generation) }

        for await action in upstream {
          let isCurrent = mutex.withLock { $0.generation == gen }
          guard !Task.isCancelled, isCurrent else { break }
          downstreamContinuation.yield(action)
        }

        let done = mutex.withLock { $0.isFinished }
        guard !Task.isCancelled, !done else { break }
      }
      downstreamContinuation.finish()
    }
    mutex.withLock { $0.worker = task }
  }

  deinit { finish() }

  /// The downstream action stream. Single-consumption; returns nil on repeated access.
  var actions: Stream? {
    let didConsume = mutex.withLock {
      guard !$0.isConsumed else { return false }
      $0.isConsumed = true
      return true
    }
    guard didConsume else { return nil }
    return downstream
  }

  /// Publishes an action to the upstream.
  func dispatch(_ action: Action) {
    mutex.withLock {
      guard !$0.isFinished else { return }
      $0.upstreamContinuation.yield(action)
    }
  }

  /// Discards pending actions by replacing the upstream, incrementing the generation counter.
  func flush() {
    let oldCont: StreamContinuation? = mutex.withLock {
      guard !$0.isFinished else { return nil }

      let (newUpstream, newContinuation) = AsyncStream.makeStream(
        of: Action.self,
        bufferingPolicy: bufferingPolicy
      )

      let cont = $0.upstreamContinuation
      $0.upstream = newUpstream
      $0.upstreamContinuation = newContinuation
      $0.generation &+= 1

      return cont
    }
    oldCont?.finish()
  }

  /// Terminates the dispatcher: finishes the upstream and cancels the relay task.
  func finish() {
    let (oldCont, worker): (StreamContinuation?, Task<Void, Never>?) = mutex.withLock {
      guard !$0.isFinished else { return (nil, nil) }
      $0.isFinished = true
      return ($0.upstreamContinuation, $0.worker)
    }
    if let oldCont {
      oldCont.finish()
      worker?.cancel()
    }
  }
}
