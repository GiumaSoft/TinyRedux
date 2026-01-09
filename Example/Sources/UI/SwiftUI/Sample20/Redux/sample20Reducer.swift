//


import Foundation
import TinyRedux


let sample20Reducer = AnyReducer<Sample20State, Sample20Action>(id: "sample20Reducer") { context in
  
  let (state, action) = context.args
  
  switch action {
  default:
    
    return .defaultNext
  }
}
