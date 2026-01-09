//


import Foundation
import TinyRedux


let sample05Reducer = AnyReducer<Sample05State, Sample05Action>(id: "sample05Reducer") { context in
  
  let (state, action) = context.args
  
  switch action {
  default:
    
    return .defaultNext
  }
}
