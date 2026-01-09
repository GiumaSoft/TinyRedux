//

import Foundation

extension Int {
  
  var timeFormatted: String {
    let hours = self / 3600
    let minutes = (self - (hours * 3600)) / 60
    let seconds = (self - (hours * 3600) - (minutes * 60))
    return String(format: "%d:%02d:%02d", hours, minutes, seconds)
  }
}
