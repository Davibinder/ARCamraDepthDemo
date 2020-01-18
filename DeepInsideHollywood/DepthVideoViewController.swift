/**
 * Copyright (c) 2018 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
 * distribute, sublicense, create a derivative work, and/or sell copies of the
 * Software in any work that is designed, intended, or marketed for pedagogical or
 * instructional purposes related to programming, coding, application development,
 * or information technology.  Permission for such use, copying, modification,
 * merger, publication, distribution, sublicensing, creation of derivative works,
 * or sale is expressly withheld.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import UIKit
import AVFoundation
import SceneKit
import ARKit
import CoreMotion
import Photos
import ReplayKit

enum CameraType{
    case photo
    case video
}

class DepthVideoViewController: UIViewController, RPScreenRecorderDelegate, RPPreviewViewControllerDelegate,UIImagePickerControllerDelegate, UINavigationControllerDelegate {

  @IBOutlet weak var photoVideoControl: UISegmentedControl!
  @IBOutlet weak var previewView: UIImageView!
  @IBOutlet weak var previewModeControl: UISegmentedControl!
  @IBOutlet weak var filterControl: UISegmentedControl!
  @IBOutlet weak var filterControlView: UIView!
  @IBOutlet weak var depthSlider: UISlider!
  @IBOutlet weak var imagChangeButton: UIButton!
  @IBOutlet weak var cameraButton: UIButton!
  @IBOutlet weak var recordButton: UIButton!
  @IBOutlet weak var movementButton: UIButton!
  @IBOutlet weak var materialOffsetSlider: UISlider!
    
  let imagePicker = UIImagePickerController()

  // recording
  var isRecording:Bool = false
  var camType = CameraType.photo
  let recorder = RPScreenRecorder.shared()
  
  var sliderValue: CGFloat = 0.0
  var previewMode = PreviewMode.filtered

  let session = AVCaptureSession()
  let stillImageOutput = AVCaptureStillImageOutput()
  let dataOutputQueue = DispatchQueue(label: "video data queue",
                                      qos: .userInitiated,
                                      attributes: [],
                                      autoreleaseFrequency: .workItem)

  var depthMap: CIImage?
  var mask: CIImage?
  var scale: CGFloat = 0.0

  var depthFilters = DepthImageFilters()

  var panoView:CTPanoramaView!
  
    
    @IBAction func imageChangeAction(_ sender: Any) {

      imagePicker.allowsEditing = false
      imagePicker.sourceType = .photoLibrary

      present(imagePicker, animated: true, completion: nil)
    }
    
    
    @IBAction func changeTransitionState(_ sender: UIButton) {
      sender.isSelected = !sender.isSelected
      if sender.isSelected {
        panoView.transitionMethod = .move
      } else {
        panoView.transitionMethod = .rotate
      }
    }

    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
    if let pickedImage = info[UIImagePickerControllerOriginalImage] as? UIImage {

      self.setPanoView(image: pickedImage)
    }
    
    dismiss(animated: true, completion: nil)
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    appDelegate.appState = AppState.MainViewC
    filterControlView.isHidden = true
    depthSlider.isHidden = false

//    previewMode = PreviewMode(rawValue: previewModeControl.selectedSegmentIndex) ?? .original
      NotificationCenter.default.addObserver(self, selector: #selector(start(noti:)), name: NSNotification.Name("update"), object: nil)
    sliderValue = CGFloat(depthSlider.value)
    imagePicker.delegate = self
//    self.view.bringSubview(toFront: previewView)
    var im = UIImage(named: "art.scnassets/InitialBG.png")
    #if DEBUG
    im = UIImage(named: "art.scnassets/InitialBG.png")
    #endif
    setPanoView(image: im!)
      configureCaptureSession()
      session.startRunning()
    
    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.tapGestureAction))
    tapGesture.numberOfTapsRequired = 1
    self.view.addGestureRecognizer(tapGesture)
  }
  
  @objc func start(noti:NSNotification) {
    if let obj = noti.object as? UIImage{
      print(obj)
      self.setPanoView(image: obj)
      session.startRunning()
    }
  }
  
  @objc func tapGestureAction() {
    print("tapGestureAction")
    if self.isRecording {
      self.stopRecording()
    }
    self.hideShowControls(alphaValue: 1.0)
  }
  
  func setPanoView(image:UIImage){
    viewsst = self.view
    panoView = CTPanoramaView(frame: CGRect(x: 0, y: 0, width: self.view.bounds.width, height: self.view.bounds.height))
//    panoView.image = UIImage(named: "orbv2texture") //orbv2texture , sample , orbv2-modified
    panoView.image = image
    panoView.controlMethod = .touch
    panoView.panoramaType = .spherical
    self.view.addSubview(self.panoView)
    panoView.isHidden = true
    
  }

    
    @IBAction func switchToCam(_ sender: Any) {
        let main = UIStoryboard(name: "Main", bundle: nil)
        let u = main.instantiateViewController(withIdentifier: "ViewController") as! ViewController
        u.depthController = self
        self.present(u, animated: true, completion: nil)
    }

  override var shouldAutorotate: Bool {
    return false
  }

  @IBAction func photoVideoChanged(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 0{
            camType = .photo
        }
        if sender.selectedSegmentIndex == 1{
            camType = .video
        }
    }
}

// MARK: - Helper Methods

extension DepthVideoViewController {
    
    

  func configureCaptureSession() {

    guard let camera = AVCaptureDevice.default(.builtInTrueDepthCamera,
                                               for: .video,
                                               position: .unspecified) else {

                                                fatalError("No depth video camera available")
    }

    session.sessionPreset = .photo
    
    do {
      let cameraInput = try AVCaptureDeviceInput(device: camera)
      session.addInput(cameraInput)
    } catch {
      fatalError(error.localizedDescription)
    }

    let videoOutput = AVCaptureVideoDataOutput()
    videoOutput.setSampleBufferDelegate(self, queue: dataOutputQueue)
    videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]

    session.addOutput(videoOutput)

    let videoConnection = videoOutput.connection(with: .video)
    videoConnection?.videoOrientation = .portrait
    
//    videoConnection?.isVideoMirrored = true

    let depthOutput = AVCaptureDepthDataOutput()
    depthOutput.setDelegate(self, callbackQueue: dataOutputQueue)
    depthOutput.isFilteringEnabled = true

    session.addOutput(depthOutput)
    stillImageOutput.outputSettings = [AVVideoCodecKey:AVVideoCodecType.jpeg]
    if session.canAddOutput(stillImageOutput) {
      session.addOutput(stillImageOutput)
    }

    let depthConnection = depthOutput.connection(with: .depthData)
    depthConnection?.videoOrientation = .portrait

    let outputRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    let videoRect = videoOutput.outputRectConverted(fromMetadataOutputRect: outputRect)
    let depthRect = depthOutput.outputRectConverted(fromMetadataOutputRect: outputRect)

    scale = max(videoRect.width, videoRect.height) / max(depthRect.width, depthRect.height)

    do {
      try camera.lockForConfiguration()

      if let frameDuration = camera.activeDepthDataFormat?
        .videoSupportedFrameRateRanges.first?.minFrameDuration {
        camera.activeVideoMinFrameDuration = frameDuration
      }

      camera.unlockForConfiguration()
    } catch {
      fatalError(error.localizedDescription)
    }
  }
}

// MARK: - Capture Video Data Delegate Methods

extension DepthVideoViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
  
  func captureOutput(_ output: AVCaptureOutput,
                     didOutput sampleBuffer: CMSampleBuffer,
                     from connection: AVCaptureConnection) {

    let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
    let image = CIImage(cvPixelBuffer: pixelBuffer!)

    let previewImage: CIImage

    switch previewMode {
    case .original:
      previewImage = image
    case .depth:
      previewImage = depthMap ?? image
    case .mask:
      previewImage = mask ?? image
    case .filtered:
      if let mask = mask {

        if let background = CIImage(image: (panoView.snapshot())) {
          previewImage = depthFilters.greenScreen(image: image,
                                                  background: background,
                                                  mask: mask)
        } else {
          previewImage = image
        }
      } else {
        previewImage = image
      }
    }

    let displayImage = UIImage(ciImage: previewImage)
    DispatchQueue.main.async { [weak self] in
      self?.previewView.image = displayImage
    }
  }
}

// MARK: - Capture Depth Data Delegate Methods

extension DepthVideoViewController: AVCaptureDepthDataOutputDelegate {

  func depthDataOutput(_ output: AVCaptureDepthDataOutput,
                       didOutput depthData: AVDepthData,
                       timestamp: CMTime,
                       connection: AVCaptureConnection) {

    if previewMode == .original {
      return
    }

    var convertedDepth: AVDepthData

    if depthData.depthDataType != kCVPixelFormatType_DisparityFloat32 {
      convertedDepth = depthData.converting(toDepthDataType: kCVPixelFormatType_DisparityFloat32)
    } else {
      convertedDepth = depthData
    }

//    convertedDepth = convertedDepth.applyingExifOrientation(.upMirrored)
    let pixelBuffer = convertedDepth.depthDataMap
    pixelBuffer.clamp()

    let depthMap = CIImage(cvPixelBuffer: pixelBuffer)

    if previewMode == .mask || previewMode == .filtered {
        mask = depthFilters.createHighPassMask(for: depthMap,
                                               withFocus: sliderValue,
                                               andScale: scale,
                                               isSharp: true)
//      }
    }

    DispatchQueue.main.async { [weak self] in
      self?.depthMap = depthMap
    }
  }
}

extension DepthVideoViewController {
  
  // called after stopping the recording
  func screenRecorder(_ screenRecorder: RPScreenRecorder, didStopRecordingWithError error: Error, previewViewController: RPPreviewViewController?) {
    NSLog("Stop recording")
  }
  
  // called when the recorder availability has changed
  func screenRecorderDidChangeAvailability(_ screenRecorder: RPScreenRecorder) {
    let availability = screenRecorder.isAvailable
    NSLog("Availablility: \(availability)")
  }
  
  func showHideControls(_ show:Bool) {
    
  }
  
  func startRecording() {
    guard recorder.isAvailable else {
      print("Recording is not available at this time.")
      return
    }
    
    self.showHideControls(false)
    self.hideShowControls(alphaValue:0.0)
    
    self.recorder.isMicrophoneEnabled = true
    self.recorder.startRecording{ [unowned self] (error) in
      guard error == nil else {
        print("There was an error starting the recording.")
        return
      }
      print("Started Recording Successfully")
      self.isRecording = true
    }
    
    /*
    let alert = UIAlertController(title: "Message!", message: "Recording is about to start, double tap anywhere on screen to stop recording.Do you want to proceed?", preferredStyle: .alert)
    let yesAction = UIAlertAction(title: "OK", style: .default, handler: { (action: UIAlertAction) in
        self.recorder.isMicrophoneEnabled = true
        self.recorder.startRecording{ [unowned self] (error) in
            guard error == nil else {
                print("There was an error starting the recording.")
                return
            }
            print("Started Recording Successfully")
            self.isRecording = true
        }
    })
    let noAction = UIAlertAction(title: "Cancel", style: .destructive, handler: { (action: UIAlertAction) -> Void in
        self.hideShowControls(alphaValue:1.0)
        self.recordButton.isSelected = false
    })
    alert.addAction(yesAction)
    alert.addAction(noAction)
    self.present(alert, animated: true, completion: nil)
 */
  }
  
  func stopRecording() {
    self.showHideControls(true)
    self.hideShowControls(alphaValue:1.0)
    
    recorder.stopRecording { [unowned self] (preview, error) in
      print("Stopped recording")
      
      guard preview != nil else {
        print("Preview controller is not available.")
        return
      }
      
      let alert = UIAlertController(title: "Recording Finished", message: "Would you like to edit or delete your recording?", preferredStyle: .alert)
      
      let deleteAction = UIAlertAction(title: "Delete", style: .destructive, handler: { (action: UIAlertAction) in
        self.recorder.discardRecording(handler: { () -> Void in
          print("Recording suffessfully deleted.")
        })
      })
      
      let editAction = UIAlertAction(title: "Edit", style: .default, handler: { (action: UIAlertAction) -> Void in
        preview?.previewControllerDelegate = self
        preview?.modalPresentationStyle = .overFullScreen
        
        
        self.present(preview!, animated: true, completion: nil)
      })
      
      alert.addAction(editAction)
      alert.addAction(deleteAction)
      self.present(alert, animated: true, completion: nil)
      
      self.isRecording = false
      
    }
    
  }
  
  func previewControllerDidFinish(_ previewController: RPPreviewViewController) {
    dismiss(animated: true)
  }
  
  @IBAction func recordTapped(_ sender: UIButton) {
    if camType == .video{
        // start
        self.startRecording()
      
    }
    if camType == .photo{
      /*
          if let videoConnection = stillImageOutput.connection(with: AVMediaType.video) {
            stillImageOutput.captureStillImageAsynchronously(from: videoConnection) {
              (imageDataSampleBuffer, error) -> Void in
              let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageDataSampleBuffer!)
              UIImageWriteToSavedPhotosAlbum(UIImage(data: imageData!)!, nil, nil, nil)
            }
          }*/
      self.hideShowControls(alphaValue:0.0)
      if #available(iOS 9.0, *) {
        AudioServicesPlaySystemSoundWithCompletion(SystemSoundID(1108), nil)
      } else {
        AudioServicesPlaySystemSound(1108)
      }
      let image = self.takeScreenshot()
      self.hideShowControls(alphaValue:1.0)
    }
  }
  
  func hideShowControls( alphaValue:CGFloat) {
    cameraButton.alpha = alphaValue
    photoVideoControl.alpha = alphaValue
    imagChangeButton.alpha = alphaValue
    recordButton.alpha = alphaValue
    movementButton.alpha = alphaValue
    materialOffsetSlider.alpha = alphaValue
  }
 
  open func takeScreenshot(_ shouldSave: Bool = true) -> UIImage? {
    var screenshotImage :UIImage?
    let layer = UIApplication.shared.keyWindow!.layer
    let scale = UIScreen.main.scale
    UIGraphicsBeginImageContextWithOptions(layer.frame.size, false, scale);
    guard let context = UIGraphicsGetCurrentContext() else {return nil}
    layer.render(in:context)
    screenshotImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    if let image = screenshotImage, shouldSave {
      UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }
    return screenshotImage
  }

  
}

// MARK: - Slider Methods

extension DepthVideoViewController {

  @IBAction func sliderValueChanged(_ sender: UISlider) {
    
    if sender === self.materialOffsetSlider {
      let node = self.panoView.getGeomateryNode()
      print("Slider Value\(self.materialOffsetSlider.value) and Eulare angles \(node.eulerAngles)")
      node.eulerAngles = SCNVector3Make(0, 0, 0)
      node.geometry?.materials.first?.diffuse.contentsTransform = SCNMatrix4MakeTranslation(self.materialOffsetSlider.value, 0.0, 0.0)
      
    }else{
      sliderValue = CGFloat(depthSlider.value)
      print("Slider Value\(sliderValue)")
    }
  }
}

// MARK: - Segmented Control Methods

extension DepthVideoViewController {

  @IBAction func previewModeChanged(_ sender: UISegmentedControl) {
    previewMode = PreviewMode(rawValue: previewModeControl.selectedSegmentIndex) ?? .original

    if previewMode == .mask || previewMode == .filtered {
      //filterControlView.isHidden = false
      if previewMode == .filtered{
        self.imagChangeButton.isHidden = false
      }else{
        self.imagChangeButton.isHidden = true
        }
      depthSlider.isHidden = false
      //here
    } else {
      //filterControlView.isHidden = true
      depthSlider.isHidden = true
        self.imagChangeButton.isHidden = true
    }
  }

  @IBAction func filterTypeChanged(_ sender: UISegmentedControl) {
    //filter = FilterType(rawValue: filterControl.selectedSegmentIndex) ?? .comic
  }
}
