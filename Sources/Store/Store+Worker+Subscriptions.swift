//


import Foundation


extension Store.Worker {

  /// Subscriptions
  ///
  /// Collection of active subscription entries owned by the Worker. Reference
  /// semantics allow mutation to be shared between the context's `register`/
  /// `unregister` closures and the `subscriptionChain` closure without `inout`.
  @MainActor
  final class Subscriptions {

    /// Entry
    ///
    /// Registry entry: identifier + predicate + action builder + generation tag.
    struct Entry {

      /// Caller-provided identifier. Enables dedupe (replace) and `unsubscribe`.
      let id: String

      /// Action that was flowing when the subscription was registered.
      let origin: A

      /// Identifier of the middleware that registered the subscription.
      let registeredBy: String

      /// Dispatcher generation at registration time. Entries with stale generation are invalidated by `flush`/`suspend`.
      let generation: UInt64

      /// Predicate evaluated post-reducer.
      let when: SubscriptionPredicate<S>

      /// Action builder invoked at match time.
      let then: SubscriptionHandler<S, A>

      init(
        id: String,
        origin: A,
        registeredBy: String,
        generation: UInt64,
        when: @escaping SubscriptionPredicate<S>,
        then: @escaping SubscriptionHandler<S, A>
      ) {
        self.id = id
        self.origin = origin
        self.registeredBy = registeredBy
        self.generation = generation
        self.when = when
        self.then = then
      }
    }

    var entries: [Entry] = []

    /// Appends an entry. Dedupe replace semantics: existing entry with same `id` is removed first.
    func register(_ entry: Entry) {
      entries.removeAll { $0.id == entry.id }
      entries.append(entry)
    }

    /// Removes the entry matching `id`. Returns `true` if removed, `false` if not present.
    @discardableResult
    func unregister(id: String) -> Bool {
      guard let index = entries.firstIndex(where: { $0.id == id }) else {

        return false
      }

      entries.remove(at: index)

      return true
    }
  }
}
