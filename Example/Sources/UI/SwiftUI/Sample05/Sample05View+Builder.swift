//


import SwiftUI
import RealityKit


extension Sample.SwiftUI.Sample05View {
  
  @ViewBuilder
  var _main_: some View {
    _realityContent_
      .overlay(alignment: .bottom) {
        _commands_
          .padding(.bottom)
      }
      .ignoresSafeArea()
  }
  
  @ViewBuilder var _realityContent_: some View {
    RealityView { content in
      content.camera = .spatialTracking
      
      let configuration = SpatialTrackingSession.Configuration(
        tracking: [.camera],
        sceneUnderstanding: [],
        camera: .back
      )
      let session = SpatialTrackingSession()
      _ = await session.run(configuration)
      
      let mesh = MeshResource.generateBox(size: 0.3, cornerRadius: 0.02)
      let material = SimpleMaterial(color: .systemRed, isMetallic: true)
      let entity = ModelEntity(mesh: mesh, materials: [material])
      entity.name = "cube"
      entity.position = [0, 0, -1]
      
      let anchor = AnchorEntity(.camera)
      anchor.name = "cameraAnchor"
      anchor.addChild(entity)
      content.add(anchor)
    } update: { content in
      guard let anchor = content.entities.first(where: { $0.name == "cameraAnchor" }),
            let entity = anchor.children.first(where: { $0.name == "cube" })
      else { return }
      
      let rotation = simd_quatf(angle: xAngle, axis: [1, 0, 0])
                    * simd_quatf(angle: yAngle, axis: [0, 1, 0])
                    * simd_quatf(angle: zAngle, axis: [0, 0, 1])
      entity.transform.rotation = rotation
    }
  }
  
  @ViewBuilder var _commands_: some View {
    HStack(spacing: 20) {
      _rotateButton_("X", axis: .incXRotation)
      _rotateButton_("Y", axis: .incYRotation)
      _rotateButton_("Z", axis: .incZRotation)
    }
  }
  
  @ViewBuilder
  func _rotateButton_(_ label: String, axis: Sample05Action) -> some View {
    Text(label)
      .padding()
      .foregroundStyle(.black)
      .background(
        RoundedRectangle(cornerRadius: 16)
          .fill(.white)
      )
      .onLongPressGesture(minimumDuration: .infinity, pressing: { isPressing in
        if isPressing {
          store.dispatch(axis)
          activeAxis = axis
        } else {
          activeAxis = nil
        }
      }, perform: {})
  }
}
