//


import Foundation
import TinyRedux


let sample19Reducer = AnyReducer<Sample19State, Sample19Action>(id: "sample19Reducer") { context in
  
  let (state, action) = context.args
  
  switch action {
  default:
    
    return .defaultNext
  }
}
