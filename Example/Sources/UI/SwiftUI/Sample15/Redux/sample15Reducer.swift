//


import Foundation
import TinyRedux


let sample15Reducer = AnyReducer<Sample15State, Sample15Action>(id: "sample15Reducer") { context in
  
  let (state, action) = context.args
  
  switch action {
  default:
    
    return .defaultNext
  }
}
