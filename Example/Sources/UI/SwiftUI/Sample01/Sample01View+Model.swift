//


import Foundation


extension SwiftUISample.Sample01View {
  var entries: Array<Product> {
    store.items
  }
  
  var total: Decimal {
    store.total
  }
}
