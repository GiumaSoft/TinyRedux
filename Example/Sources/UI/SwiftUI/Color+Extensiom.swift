//

import SwiftUI

extension Color {
  static var random: Color {
    Color(
      .displayP3,
      red: .random(in: 0...1),
      green: .random(in: 0...1),
      blue: .random(in: 0...1),
      opacity: 1.0
    )
  }
}
