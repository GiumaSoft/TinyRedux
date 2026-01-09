//


import Foundation
import TinyRedux


let sample10Reducer = AnyReducer<Sample10State, Sample10Action>(id: "sample10Reducer") { context in
  
  let (state, action) = context.args
  
  switch action {
  default:
    
    return .defaultNext
  }
}
