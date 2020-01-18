//
//  CTPanoramaView
//  CTPanoramaView
//
//  Created by Cihan Tek on 11/10/16.
//  Copyright © 2016 Home. All rights reserved.
//

import UIKit
import SceneKit
import CoreMotion
import ImageIO

var vec: SCNVector4 = SCNVector4Make(0, 0, 0, 0)
var diff: SCNVector4 = SCNVector4Make(0, 0, 0, 0)
var prevAngles: SCNVector3 = SCNVector3Make(0, 0, 0)

@objc public protocol CTPanoramaCompass {
    func updateUI(rotationAngle: CGFloat, fieldOfViewAngle: CGFloat)
}

@objc public enum CTPanoramaControlMethod: Int {
    case motion
    case touch
}

@objc public enum CTPanoramaTransitionMethod: Int {
  case rotate
  case move
}

@objc public enum CTPanoramaType: Int {
    case cylindrical
    case spherical
}

@objc public class CTPanoramaView: UIView {

    // MARK: Public properties

    @objc public var panSpeed = CGPoint(x: 0.005, y: 0.005)

    @objc public var image: UIImage? {
        didSet {
            panoramaType = panoramaTypeForCurrentImage
        }
    }

    @objc public var overlayView: UIView? {
        didSet {
            replace(overlayView: oldValue, with: overlayView)
        }
    }

    @objc public var panoramaType: CTPanoramaType = .cylindrical {
        didSet {
            createGeometryNode()
            resetCameraAngles()
        }
    }

    @objc public var controlMethod: CTPanoramaControlMethod = .touch {
        didSet {
            switchControlMethod(to: controlMethod)
            resetCameraAngles()
        }
    }
  
  @objc public var transitionMethod: CTPanoramaTransitionMethod = .rotate {
    didSet {
      switchTransitionMethod(to: transitionMethod)
      resetCameraAngles()
    }
  }

    @objc public var compass: CTPanoramaCompass?
    @objc public var views: UIView?
    @objc public var movementHandler: ((_ rotationAngle: CGFloat, _ fieldOfViewAngle: CGFloat) -> Void)?

    // MARK: Private properties

    private let radius: CGFloat = 100
    private let sceneView = SCNView()
    private var scene = SCNScene()
    private let motionManager = CMMotionManager()
    private var geometryNode: SCNNode?
    private var prevLocation = CGPoint.zero
    private var prevBounds = CGRect.zero
    private var prevAngleVect: SCNVector4 = SCNVector4Make(0, 0, 0, 0)
  var currentAnglex: Float = 0
  var currentAngley: Float = 0
  

    private lazy var cameraNode: SCNNode = {
        let node = SCNNode()
        let camera = SCNCamera()
        node.camera = camera
        return node
    }()

    private lazy var opQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.qualityOfService = .userInteractive
        return queue
    }()

    private lazy var fovHeight: CGFloat = {
        return tan(self.yFov/2 * .pi / 180.0) * 2 * self.radius
    }()

    private var xFov: CGFloat {
        return yFov * self.bounds.width / self.bounds.height
    }

    private var yFov: CGFloat {
        get {
            if #available(iOS 11.0, *) {
                return cameraNode.camera?.fieldOfView ?? 0
            } else {
                return CGFloat(cameraNode.camera?.yFov ?? 0)
            }
        }
        set {
            if #available(iOS 11.0, *) {
                cameraNode.camera?.fieldOfView = newValue
            } else {
                cameraNode.camera?.yFov = Double(newValue)
            }
        }
    }

    private var panoramaTypeForCurrentImage: CTPanoramaType {
        if let image = image {
            if image.size.width / image.size.height == 2 {
                return .spherical
            }
        }
        return .cylindrical
    }

    // MARK: Class lifecycle methods

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    public convenience init(frame: CGRect, image: UIImage) {
        self.init(frame: frame)
        // Force Swift to call the property observer by calling the setter from a non-init context
        ({ self.image = image })()
    }

    deinit {
        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
        }
    }

    private func commonInit() {
        add(view: sceneView)
        scene.rootNode.addChildNode(cameraNode)
      
        yFov = 70
      
        sceneView.scene = scene
      
        sceneView.backgroundColor = UIColor.black
        switchControlMethod(to: controlMethod)
      
     }

    // MARK: Configuration helper methods

    private func createGeometryNode() {
        guard let image = image else {return}

        geometryNode?.removeFromParentNode()

        let material = SCNMaterial()
        material.diffuse.contents = image
        material.diffuse.mipFilter = .nearest
        material.diffuse.magnificationFilter = .nearest
        material.diffuse.contentsTransform = SCNMatrix4MakeScale(-1, 1, 1)
        material.diffuse.wrapS = .repeat
        material.cullMode = .front
        let customScene = SCNScene(named: "art.scnassets/orb.scn")!
      
//      scene.rootNode.geometry?.materials[1].diffuse.contents = image
      guard  let node = customScene.rootNode.childNode(withName: "_material_1", recursively: true) else {
        return
      }
      node.geometry?.materials.first?.diffuse.contents = image;

      geometryNode = node
//      geometryNode?.geometry?.firstMaterial = material
      scene.rootNode.addChildNode(geometryNode!)
      
      
      
//      scene.rootNode.childNode(withName: "_material_1", recursively: true)?.geometry?.firstMaterial = material

//        if panoramaType == .spherical {
//            let sphere = SCNSphere(radius: radius)
//            sphere.segmentCount = 300
//            sphere.firstMaterial = material
//
//            let sphereNode = SCNNode()
//            sphereNode.geometry = sphere
//            geometryNode = sphereNode
//        } else {
//            let tube = SCNTube(innerRadius: radius, outerRadius: radius, height: fovHeight)
//            tube.heightSegmentCount = 50
//            tube.radialSegmentCount = 300
//            tube.firstMaterial = material
//
//            let tubeNode = SCNNode()
//            tubeNode.geometry = tube
//            geometryNode = tubeNode
//        }
//
//            scene.rootNode.addChildNode(geometryNode!)
    }
  
  
  public func getGeomateryNode()->SCNNode {
    return self.geometryNode!
  }
  
  

    private func replace(overlayView: UIView?, with newOverlayView: UIView?) {
        overlayView?.removeFromSuperview()
        guard let newOverlayView = newOverlayView else {return}
        add(view: newOverlayView)
    }
  
  private func switchTransitionMethod(to method: CTPanoramaTransitionMethod) {
    viewsst.gestureRecognizers?.removeAll()
    switch method {
    case .move:
      let panGestureRec = UIPanGestureRecognizer(target: self, action: #selector(panZoom(gesture:)))
      viewsst.addGestureRecognizer(panGestureRec)
    case .rotate:
      let panGestureRec = UIPanGestureRecognizer(target: self, action: #selector(handlePan(panRec:)))
      viewsst.addGestureRecognizer(panGestureRec)
    }
  }
  


    private func switchControlMethod(to method: CTPanoramaControlMethod) {
        sceneView.gestureRecognizers?.removeAll()

        if method == .touch {
                let panGestureRec = UIPanGestureRecognizer(target: self, action: #selector(handlePan(panRec:)))
//          let panGestureRec = UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(gestureRecognize:)))
                          viewsst.addGestureRecognizer(panGestureRec)

            deviceMotionControl()
//            if motionManager.isDeviceMotionActive {
//                motionManager.stopDeviceMotionUpdates()
//            }
        } else {
            guard motionManager.isDeviceMotionAvailable else {return}
            motionManager.deviceMotionUpdateInterval = 0.015
            motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: opQueue,
                                                   withHandler: { [weak self] (motionData, error) in
                guard let panoramaView = self else {return}
                guard panoramaView.controlMethod == .motion else {return}

                guard let motionData = motionData else {
                    print("\(String(describing: error?.localizedDescription))")
                    panoramaView.motionManager.stopDeviceMotionUpdates()
                    return
                }

                let rotationMatrix = motionData.attitude.rotationMatrix
                var userHeading = .pi - atan2(rotationMatrix.m32, rotationMatrix.m31)
                userHeading += .pi/2

                DispatchQueue.main.async {
                    if panoramaView.panoramaType == .cylindrical {
                        // Prevent vertical movement in a cylindrical panorama
                        panoramaView.cameraNode.eulerAngles = SCNVector3Make(0, Float(-userHeading), 0)
                    } else {
                        // Use quaternions when in spherical mode to prevent gimbal lock
                        panoramaView.cameraNode.orientation = motionData.orientation()
                    }
                    panoramaView.reportMovement(CGFloat(userHeading), panoramaView.xFov.toRadians())
                }
            })
        }
    }

    private func resetCameraAngles() {
        cameraNode.eulerAngles = SCNVector3Make(0, 0, 0)
        self.reportMovement(0, xFov.toRadians(), callHandler: false)
    }

    private func reportMovement(_ rotationAngle: CGFloat, _ fieldOfViewAngle: CGFloat, callHandler: Bool = true) {
        compass?.updateUI(rotationAngle: rotationAngle, fieldOfViewAngle: fieldOfViewAngle)
        if callHandler {
            movementHandler?(rotationAngle, fieldOfViewAngle)
        }
    }

    // MARK: Gesture handling

    @objc private func handlePan(panRec: UIPanGestureRecognizer) {
      print("handlePan")
      if panRec.location(in: viewsst).y <= 700 {
        if panRec.state == .began {
          prevLocation = CGPoint.zero
          motionManager.stopDeviceMotionUpdates()
          vec = cameraNode.orientation
          
        } else if panRec.state == .changed {
          var modifiedPanSpeed = panSpeed
          
          if panoramaType == .cylindrical {
            modifiedPanSpeed.y = 0 // Prevent vertical movement in a cylindrical panorama
          }
          //===This check prevents to changes Eular angles from last position/Davinder/
          if (cameraNode.eulerAngles.x - prevAngles.x > 1.0) || (cameraNode.eulerAngles.x - prevAngles.x < -1.0){
            cameraNode.eulerAngles = prevAngles
          }
          print("cameraNode.eulerAngles:\(cameraNode.eulerAngles)")
          //          print("cameraNode.orientation: \(cameraNode.orientation)")
          //          print("cameraNode.rotation: \(cameraNode.rotation)")
          
          let location = panRec.translation(in: sceneView)
          let orientation = cameraNode.eulerAngles
          
          var newOrientation = SCNVector3Make(orientation.x + Float(location.y - prevLocation.y) * Float(modifiedPanSpeed.y),
                                              orientation.y + Float(location.x - prevLocation.x) * Float(modifiedPanSpeed.x),
                                              0)
          if controlMethod == .touch {
            newOrientation.x = max(min(newOrientation.x, 1.1), -0.2)
          }
          cameraNode.eulerAngles = newOrientation
          
          //        let orientation = cameraNode.orientation
          //        var newOrientation = SCNVector4(orientation.x + Float(location.y - prevLocation.y) * Float(modifiedPanSpeed.y),
          //                                             orientation.y + Float(location.x - prevLocation.x) * Float(modifiedPanSpeed.x),
          //                                             orientation.z,
          //                                             orientation.w)
          //            cameraNode.orientation = newOrientation
          prevLocation = location
          
          //            reportMovement(CGFloat(-cameraNode.eulerAngles.y), xFov.toRadians())
          
        }else if panRec.state == .ended{
          let c = cameraNode.orientation
          diff = SCNVector4Make(diff.x + (c.x - vec.x), diff.y + (c.y - vec.y), diff.z + (c.z - vec.z), diff.w + (c.w - vec.w))
          print("diff: \(diff)")
          prevAngles = cameraNode.eulerAngles
          deviceMotionControl()
        }
      }
    }

  
  @objc func handleTransitionPan(pan:UIPanGestureRecognizer) {
    print("handleTransitionPan")
    if pan.location(in: viewsst).y <= 700 {
      if pan.state == .began {
        motionManager.stopDeviceMotionUpdates()
      }else if pan.state == .changed {
        let translation = pan.translation(in: pan.view!)
        
        // calculating new positions based on translation
        // (translation.x * 0.1)  converting translation to meters
        
        let newPosX = (geometryNode?.position.x ?? 0) + Float(translation.x * 0.01)
        let newPosY = (geometryNode?.position.y ?? 0) - Float(translation.y * 0.01)
        if ((newPosX < 4.6 && newPosX > -4.6) && (newPosY < 2 && newPosY > -4)) {
          geometryNode?.position = SCNVector3(x:newPosX,
                                              y:newPosY,
                                              z:(geometryNode?.position.z ?? 0))
        }
        print(" geometryNode.position:-\(String(describing:  geometryNode?.position))")
        pan.setTranslation(CGPoint.zero, in: pan.view!)
      }else if pan.state == .ended{
        deviceMotionControl()
      }
    }
  }
  
  @objc func panZoom(gesture: UIPanGestureRecognizer) {
    let node = cameraNode
    let translation = gesture.translation(in: gesture.view!)
    let scale = gesture.velocity(in: gesture.view)
    let xPos = (geometryNode?.position.x ?? 0) + Float(scale.x * 0.0005)
    
    switch gesture.state {
    case .began:
      break
    case .changed:
      // Positioning Left/Right
      if (xPos < 4.0 && xPos > -4.0){
        geometryNode?.position = SCNVector3(x:Float(xPos),
                                            y:(geometryNode?.position.y ?? 0),
                                            z:(geometryNode?.position.z ?? 0))
        }
      //== Zoom IN/OUT
      let scaleFactor = node.camera!.fieldOfView - CGFloat(scale.y * 0.005)
      if(scaleFactor > 40.0 && scaleFactor < 170.0){
        node.camera!.fieldOfView = scaleFactor
        print(node.camera!.fieldOfView)
      }
      break
    default: break
    }
  }
  
  
  func norm(v: Float) -> Float {
    return max(min(v, 1), -1)
  }
  
  @objc func deviceMotionControl(){

    guard motionManager.isDeviceMotionAvailable else {
      return
    }
    motionManager.deviceMotionUpdateInterval = 0.015
    motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: opQueue,
                                           withHandler: { [weak self] (motionData, error) in
                                            guard let panoramaView = self else {
                                              return
                                              
                                            }
                                            //                                                  guard panoramaView.controlMethod == .motion else {return}
                                            
                                            guard let motionData = motionData else {
                                              print("\(String(describing: error?.localizedDescription))")
                                              panoramaView.motionManager.stopDeviceMotionUpdates()
                                              return
                                            }
                                            
                                            let rotationMatrix = motionData.attitude.rotationMatrix
                                            var userHeading = .pi - atan2(rotationMatrix.m32, rotationMatrix.m31)
                                            userHeading += .pi/2
                                            
                                            DispatchQueue.main.async {
                                              if panoramaView.panoramaType == .cylindrical {
                                                // Prevent vertical movement in a cylindrical panorama
                                                panoramaView.cameraNode.eulerAngles = SCNVector3Make(0, Float(-userHeading), 0)
                                              } else {
                                                // Use quaternions when in spherical mode to prevent gimbal lock
//                                                panoramaView.cameraNode.orientation = motionData.orientation()
                                              
                                                let c = motionData.orientation()
                                                 panoramaView.cameraNode.orientation = SCNVector4Make((self?.norm(v:c.x + diff.x))!, (self?.norm(v:c.y + diff.y))!, (self?.norm(v:c.z + diff.z))!, (self?.norm(v:c.w + diff.w))!)
                                              }
                                              panoramaView.reportMovement(CGFloat(userHeading), panoramaView.xFov.toRadians())
                                            }
    })
  }

    public override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.size.width != prevBounds.size.width || bounds.size.height != prevBounds.size.height {
            sceneView.setNeedsDisplay()
            reportMovement(CGFloat(-cameraNode.eulerAngles.y), xFov.toRadians(), callHandler: false)
        }
    }
  
  public func snapshot() -> UIImage {
    return self.sceneView.snapshot()
  }
}

fileprivate extension CMDeviceMotion {

    func orientation() -> SCNVector4 {

        let attitude = self.attitude.quaternion
        let attitudeQuanternion = GLKQuaternion(quanternion: attitude)

        let result: SCNVector4

        switch UIApplication.shared.statusBarOrientation {

        case .landscapeRight:
            let cq1 = GLKQuaternionMakeWithAngleAndAxis(.pi/2, 0, 1, 0)
            let cq2 = GLKQuaternionMakeWithAngleAndAxis(-(.pi/2), 1, 0, 0)
            var quanternionMultiplier = GLKQuaternionMultiply(cq1, attitudeQuanternion)
            quanternionMultiplier = GLKQuaternionMultiply(cq2, quanternionMultiplier)

            result = quanternionMultiplier.vector(for: .landscapeRight)

        case .landscapeLeft:
            let cq1 = GLKQuaternionMakeWithAngleAndAxis(-(.pi/2), 0, 1, 0)
            let cq2 = GLKQuaternionMakeWithAngleAndAxis(-(.pi/2), 1, 0, 0)
            var quanternionMultiplier = GLKQuaternionMultiply(cq1, attitudeQuanternion)
            quanternionMultiplier = GLKQuaternionMultiply(cq2, quanternionMultiplier)

            result = quanternionMultiplier.vector(for: .landscapeLeft)

        case .portraitUpsideDown:
            let cq1 = GLKQuaternionMakeWithAngleAndAxis(-(.pi/2), 1, 0, 0)
            let cq2 = GLKQuaternionMakeWithAngleAndAxis(.pi, 0, 0, 1)
            var quanternionMultiplier = GLKQuaternionMultiply(cq1, attitudeQuanternion)
            quanternionMultiplier = GLKQuaternionMultiply(cq2, quanternionMultiplier)

            result = quanternionMultiplier.vector(for: .portraitUpsideDown)

        case .unknown, .portrait:
            let clockwiseQuanternion = GLKQuaternionMakeWithAngleAndAxis(-(.pi/2), 1, 0, 0)
            let quanternionMultiplier = GLKQuaternionMultiply(clockwiseQuanternion, attitudeQuanternion)

            result = quanternionMultiplier.vector(for: .portrait)
        }
        return result
    }
}

fileprivate extension UIView {
    func add(view: UIView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        let views = ["view": view]
        let hConstraints = NSLayoutConstraint.constraints(withVisualFormat: "|[view]|", options: [], metrics: nil, views: views)    //swiftlint:disable:this line_length
        let vConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|[view]|", options: [], metrics: nil, views: views)  //swiftlint:disable:this line_length
        self.addConstraints(hConstraints)
        self.addConstraints(vConstraints)
    }
}

fileprivate extension FloatingPoint {
    func toDegrees() -> Self {
        return self * 180 / .pi
    }

    func toRadians() -> Self {
        return self * .pi / 180
      
    }
}

private extension GLKQuaternion {
    init(quanternion: CMQuaternion) {
        self.init(q: (Float(quanternion.x), Float(quanternion.y), Float(quanternion.z), Float(quanternion.w)))
    }

    func vector(for orientation: UIInterfaceOrientation) -> SCNVector4 {
        switch orientation {
        case .landscapeRight:
            return SCNVector4(x: -self.y, y: self.x, z: self.z, w: self.w)

        case .landscapeLeft:
            return SCNVector4(x: self.y, y: -self.x, z: self.z, w: self.w)

        case .portraitUpsideDown:
            return SCNVector4(x: -self.x, y: -self.y, z: self.z, w: self.w)

        case .unknown, .portrait:
          return SCNVector4(x: -self.x, y: -self.y, z: self.z, w: self.w)  // modified: negatived to show back side
        }
    }
}
