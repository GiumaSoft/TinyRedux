//


import Foundation


struct FIFOBuffer<Element> {
  private var storage: [Element]
  private var head: Int
  
  init() {
    self.storage = []
    self.head = 0
  }
  
  subscript(index: Int) -> Element {
    storage[head + index]
  }
}

extension FIFOBuffer {
  ///
  var isEmpty: Bool { count == 0 }
  ///
  var count: Int { storage.count - head }
  ///
  var elements: ArraySlice<Element> { storage[head...] }
}

extension FIFOBuffer {
  ///
  mutating func enqueue(_ element: Element) {
    storage.append(element)
  }
  ///
  mutating func enqueue<S: Sequence>(_ elements: S) where S.Element == Element {
    storage.append(contentsOf: elements)
  }
  ///
  mutating func dequeue() -> Element? {
    guard head < storage.count else { return nil }
    let value = storage[head]
    head += 1
    if head > 32 && head * 2 >= storage.count {
      storage.removeFirst(head)
      head = 0
    }
    return value
  }
  ///
  mutating func removeAll(keepingCapacity keep: Bool = true) {
    storage.removeAll(keepingCapacity: keep)
    head = 0
  }

}

extension FIFOBuffer: Sequence {
  func makeIterator() -> IndexingIterator<ArraySlice<Element>> {
    elements.makeIterator()
  }
}

extension FIFOBuffer: Sendable where Element : Sendable { }
