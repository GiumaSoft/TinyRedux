//


import SwiftUI


extension Sample.SwiftUI.Sample03View {
  var headerBind: Binding<String> {
    store.bind(\.header) { .setHeader($0) }
  }
}
