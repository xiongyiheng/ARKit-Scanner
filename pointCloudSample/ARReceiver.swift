/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A utility class that receives processed depth information.
*/

import Foundation
import SwiftUI
import Combine
import ARKit

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
//    var uiImageDepth = UIImage()
    var uiImageColor = UIImage()
    
}

// Configure and run an AR session to provide the app with depth-related AR data.
final class ARReceiver: NSObject, ARSessionDelegate {
    var arData = ARData()
    var arSession = ARSession()
    weak var delegate: ARDataReceiver?
    public var isRecord = false
    public var directory = ""
    
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
    
    func record(isRecord: Bool, directory: String) {
        self.isRecord = isRecord
        self.directory = directory
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
            
//            let ciImageDepth = CIImage(cvPixelBuffer: frame.sceneDepth!.depthMap)
//            let contextDepth:CIContext = CIContext.init(options: nil)
//            let cgImageDepth:CGImage = contextDepth.createCGImage(ciImageDepth, from: ciImageDepth.extent)!
//            let uiImageDepth:UIImage = UIImage(cgImage: cgImageDepth, scale: 1, orientation: UIImage.Orientation.up)
//            arData.uiImageDepth = uiImageDepth
//
            let ciImageColor = CIImage(cvPixelBuffer: frame.capturedImage)
            let contextColor:CIContext = CIContext.init(options: nil)
            let cgImageColor:CGImage = contextColor.createCGImage(ciImageColor, from: ciImageColor.extent)!
            let uiImageColor:UIImage = UIImage(cgImage: cgImageColor, scale: 1, orientation: UIImage.Orientation.up)
            arData.uiImageColor = uiImageColor
            
            if self.isRecord {
                CVPixelBufferLockBaseAddress(arData.depthImage!, CVPixelBufferLockFlags(rawValue: 0))
                let depthAddr = CVPixelBufferGetBaseAddress(arData.depthImage!)
                let depthHeight = CVPixelBufferGetHeight(arData.depthImage!)
                let depthBpr = CVPixelBufferGetBytesPerRow(arData.depthImage!)
                let depthBuffer = Data(bytes: depthAddr!, count: (depthBpr*depthHeight))
                
//                CVPixelBufferLockBaseAddress(arData.colorImage!, CVPixelBufferLockFlags(rawValue: 0))
//                let colorAddr = CVPixelBufferGetBaseAddress(arData.colorImage!)
//                let colorHeight = CVPixelBufferGetHeight(arData.colorImage!)
//                let colorBpr = CVPixelBufferGetBytesPerRow(arData.colorImage!)
//                let colorBuffer = Data(bytes: colorAddr!, count: (colorBpr*colorHeight))
                
                let cameraIntrinsics = (0..<3).flatMap { x in (0..<3).map { y in arData.cameraIntrinsics[x][y] } }
                let cameraTransform = (0..<4).flatMap { x in (0..<4).map { y in arData.cameraTransform[x][y] } }
                let exposureDuration = "" + arData.exposureDuration.description
                let exposureOffset = "" + arData.exposureOffset.description
                
                let fileName = "" + arData.timeStamp.description
                
                if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                    let intriURL = dir.appendingPathComponent(self.directory + "/intri.xml")
                    let transURL = dir.appendingPathComponent(self.directory + "/" + fileName + "_trans.xml")
                    let duraURL = dir.appendingPathComponent(self.directory + "/dura.txt")
                    let offsetURL = dir.appendingPathComponent(self.directory + "/" + fileName + "_offset.txt")
                    let depthBufferURL = dir.appendingPathComponent(self.directory + "/" + fileName + "_depthBuffer.bin")
                    let colorJpgURL = dir.appendingPathComponent(directory + "/" + fileName + "_color.jpeg")

                    //writing
                    do {
                        try depthBuffer.write(to: depthBufferURL)
                        try uiImageColor.jpegData(compressionQuality: 0.0)!.write(to: colorJpgURL)
                        (cameraIntrinsics as NSArray).write(to: intriURL, atomically: false)
                        (cameraTransform as NSArray).write(to: transURL, atomically: false)
                        try exposureDuration.write(to: duraURL, atomically: false, encoding: .utf8)
                        try exposureOffset.write(to: offsetURL, atomically: false, encoding: .utf8)
                    }
                    catch {/* error handling here */}
                }
            }
        }
    }
}
