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
            // print out some statistics
//            print("ArKit Pose:")
//            // The position and orientation of the camera in world coordinate space.
//            print(frame.camera.transform)
//            print("Camera Intristics:")
//            print(frame.camera.intrinsics)
//            print("Time Stamps:")
//            print(frame.timestamp)
//            print("Exposure Duration:")
//            print(frame.camera.exposureDuration)
//            print("Exposure Offset:")
//            print(frame.camera.exposureOffset)
            
            // Get RGBA values
            var colorImage: CGImage?
            VTCreateCGImageFromCVPixelBuffer(frame.capturedImage, options: nil, imageOut: &colorImage)
            print("Color Image:")
            let RGBAValues:[UInt8] = pixelValues(fromCGImage: colorImage)!
            print(RGBAValues.count)
            
            // Get depth values
            let depthImage_ci: CIImage = CIImage(cvPixelBuffer: frame.sceneDepth!.depthMap)
            let depthImage_cg: CGImage = convertCIImageToCGImage(inputImage: depthImage_ci)!
            print("Depth Image:")
            let depthValues:[UInt8] = pixelValues(fromCGImage: depthImage_cg)!
            print(depthValues.count)
        }
    }
    
    // Get pixel values of CGImage
    func pixelValues(fromCGImage imageRef: CGImage?) -> [UInt8]?
        {
            var width = 0
            var height = 0
            var pixelValues: [UInt8]?

            if let imageRef = imageRef {
                width = imageRef.width
                height = imageRef.height
                let bitsPerComponent = imageRef.bitsPerComponent
                let bytesPerRow = imageRef.bytesPerRow
                let totalBytes = height * bytesPerRow
                let bitmapInfo = imageRef.bitmapInfo

                //let colorSpace = CGColorSpaceCreateDeviceRGB()
                let colorSpace = CGColorSpaceCreateDeviceGray()
                var intensities = [UInt8](repeating: 0, count: totalBytes)

                let contextRef = CGContext(data: &intensities,
                                          width: width,
                                         height: height,
                               bitsPerComponent: bitsPerComponent,
                                    bytesPerRow: bytesPerRow,
                                          space: colorSpace,
                                     bitmapInfo: bitmapInfo.rawValue)
                contextRef?.draw(imageRef, in: CGRect(x: 0.0, y: 0.0, width: CGFloat(width), height: CGFloat(height)))

                pixelValues = intensities
            }

            return pixelValues
    }
    
    // Convert CIImage to CGImage
    func convertCIImageToCGImage(inputImage: CIImage) -> CGImage? {
        let context = CIContext(options: nil)
        if let cgImage = context.createCGImage(inputImage, from: inputImage.extent) {
            return cgImage
        }
        return nil
    }
    
    
}
