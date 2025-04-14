//


import Foundation


func printLog(_ text: String) {
  #if DEBUG
  print(text)
  #endif
}
