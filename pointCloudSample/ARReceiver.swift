/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A utility class that receives processed depth information.
*/

import Foundation
import SwiftUI
import Combine
import ARKit
import VideoToolbox

// Receive the newest AR data from an `ARReceiver`.
protocol ARDataReceiver: AnyObject {
    func onNewARData(arData: ARData)
}

//- Tag: ARData
// Store depth-related AR data.
final class ARData {
    var depthImage: CVPixelBuffer?
    var depthSmoothImage: CVPixelBuffer?
    var colorImage: CVPixelBuffer?
    var confidenceImage: CVPixelBuffer?
    var confidenceSmoothImage: CVPixelBuffer?
    var cameraIntrinsics = simd_float3x3()
    var cameraResolution = CGSize()
    var cameraTransform = simd_float4x4()
    var timeStamp = TimeInterval()
    var exposureDuration = TimeInterval()
    var exposureOffset = Float()
    var uiImageDepth = UIImage()
    var uiImageColor = UIImage()
    
}

// Configure and run an AR session to provide the app with depth-related AR data.
final class ARReceiver: NSObject, ARSessionDelegate {
    var arData = ARData()
    var arSession = ARSession()
    weak var delegate: ARDataReceiver?
    
    // Configure and start the ARSession.
    override init() {
        super.init()
        arSession.delegate = self
        start()
    }
    
    // Configure the ARKit session.
    func start() {
        guard ARWorldTrackingConfiguration.supportsFrameSemantics([.sceneDepth, .smoothedSceneDepth]) else { return }
        // Enable both the `sceneDepth` and `smoothedSceneDepth` frame semantics.
        let config = ARWorldTrackingConfiguration()
        config.frameSemantics = [.sceneDepth, .smoothedSceneDepth]
        arSession.run(config)
    }
    
    func pause() {
        arSession.pause()
    }
    
    // Send required data from `ARFrame` to the delegate class via the `onNewARData` callback.
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if(frame.sceneDepth != nil) && (frame.smoothedSceneDepth != nil) {
            arData.depthImage = frame.sceneDepth?.depthMap
            arData.depthSmoothImage = frame.smoothedSceneDepth?.depthMap
            arData.confidenceImage = frame.sceneDepth?.confidenceMap
            arData.confidenceSmoothImage = frame.smoothedSceneDepth?.confidenceMap
            arData.colorImage = frame.capturedImage
            arData.cameraIntrinsics = frame.camera.intrinsics
            arData.cameraResolution = frame.camera.imageResolution
            delegate?.onNewARData(arData: arData)
            arData.cameraTransform = frame.camera.transform
            arData.timeStamp = frame.timestamp
            arData.exposureDuration = frame.camera.exposureDuration
            arData.exposureOffset = frame.camera.exposureOffset
            
            let ciImageDepth = CIImage(cvPixelBuffer: frame.sceneDepth!.depthMap)
            let contextDepth:CIContext = CIContext.init(options: nil)
            let cgImageDepth:CGImage = contextDepth.createCGImage(ciImageDepth, from: ciImageDepth.extent)!
            let uiImageDepth:UIImage = UIImage(cgImage: cgImageDepth, scale: 1, orientation: UIImage.Orientation.up)
            arData.uiImageDepth = uiImageDepth
            
            let ciImageColor = CIImage(cvPixelBuffer: frame.capturedImage)
            let contextColor:CIContext = CIContext.init(options: nil)
            let cgImageColor:CGImage = contextColor.createCGImage(ciImageColor, from: ciImageColor.extent)!
            let uiImageColor:UIImage = UIImage(cgImage: cgImageColor, scale: 1, orientation: UIImage.Orientation.up)
            arData.uiImageColor = uiImageColor
        }
    }
}
