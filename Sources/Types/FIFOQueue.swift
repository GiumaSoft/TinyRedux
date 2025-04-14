//


import Foundation


struct FIFOQueue<Element> {
  private var queue: [Element?] = []
  private var head: Int = 0
  
  var count: Int { queue.count - head }
  var isEmpty: Bool { count == 0 }
  var elements: [Element] { queue.compactMap { $0 } }
}

extension FIFOQueue {
  mutating func enqueue(_ element: Element) {
    queue.append(element)
  }
  
  mutating func enqueue<S>(_ elements: S) where S : Sequence, S.Element == Element {
    for element in elements {
      enqueue(element)
    }
  }
  
  mutating func dequeue() -> Element? {
    guard head < queue.count,
          let element = queue[head]
    else {
      compactAll()
      return nil
    }
    
    queue[head] = nil
    head += 1
    compactIfNeeded()
    
    return element
  }
  
  mutating func removeAll(keepingCapacity keep: Bool = true) {
    queue.removeAll(keepingCapacity: keep)
    head = 0
  }
  
  private mutating func compactIfNeeded() {
    if head > 32 && head * 2 >= queue.count {
      queue.removeFirst(head)
      head = 0
    }
  }
  
  private mutating func compactAll() {
    if head > 0 {
      queue.removeAll(keepingCapacity: true)
      head = 0
    }
  }
}

