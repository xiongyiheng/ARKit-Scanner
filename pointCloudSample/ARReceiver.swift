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
//    var RGBAValues = [UInt8]()
//    var depthValues = [UInt8]()
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
            // print out some statistics
//            print("ArKit Pose:")
//            // The position and orientation of the camera in world coordinate space.
//            print(frame.camera.transform)
            arData.cameraTransform = frame.camera.transform
//            print("Camera Intristics:")
//            print(frame.camera.intrinsics)
//            print("Time Stamps:")
//            print(frame.timestamp)
            arData.timeStamp = frame.timestamp
//            print("Exposure Duration:")
//            print(frame.camera.exposureDuration)
            arData.exposureDuration = frame.camera.exposureDuration
//            print("Exposure Offset:")
//            print(frame.camera.exposureOffset)
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
            
//            // Get RGBA values
//            var colorImage: CGImage?
//            VTCreateCGImageFromCVPixelBuffer(frame.capturedImage, options: nil, imageOut: &colorImage)
//            //print("Color Image:")
//            let RGBAValues:[UInt8] = pixelValues(fromCGImage: colorImage, isRGB: true)!
//            arData.RGBAValues = RGBAValues
//            //print(RGBAValues.count)
//
            // Get depth values but still in rgb values
            //let depthImage_ci: CIImage = CIImage(cvPixelBuffer: frame.sceneDepth!.depthMap)
            //let depthImage_cg: CGImage = convertCIImageToCGImage(inputImage: depthImage_ci)!
            //print("Depth Image:")
            //let depthValues:[UInt8] = pixelValues(fromCGImage: depthImage_cg, isRGB: false)!
//            arData.depthValues = depthValues
//            //print(depthValues.count)
//            let width = CVPixelBufferGetWidth(frame.sceneDepth!.depthMap)
//            CVPixelBufferLockBaseAddress(frame.sceneDepth!.depthMap, CVPixelBufferLockFlags(rawValue: 0))
//            let depthPointer = unsafeBitCast(CVPixelBufferGetBaseAddress(frame.sceneDepth!.depthMap), to:UnsafeMutablePointer<Float32>.self)
//            print(depthPointer)
//            for i in 0...256 {
//                for j in 0...192 {
//                    var point = CGPoint(x:i, y:j)
//                    let distanceAtXYPoint = depthPointer[Int(point.y * CGFloat(width) + point.x)]
//                    print(distanceAtXYPoint)
//                }
//            }
//            print("depthvalues")
//            print(distanceAtXYPoint)
//            print(depthValues[910])
        }
    }
    
    // Get pixel values of CGImage
//    func pixelValues(fromCGImage imageRef: CGImage?, isRGB: Bool) -> [UInt8]?
//        {
//            var width = 0
//            var height = 0
//            var pixelValues: [UInt8]?
//
//            if let imageRef = imageRef {
//                width = imageRef.width
//                height = imageRef.height
//                let bitsPerComponent = imageRef.bitsPerComponent
//                let bytesPerRow = imageRef.bytesPerRow
//                let totalBytes = height * bytesPerRow
//                let bitmapInfo = imageRef.bitmapInfo
//                let colorSpace = CGColorSpaceCreateDeviceRGB()
//                //if (!isRGB) {
//                //    colorSpace = CGColorSpaceCreateDeviceGray()
//                //}
//                var intensities = [UInt8](repeating: 0, count: totalBytes)
//
//                let contextRef = CGContext(data: &intensities,
//                                          width: width,
//                                         height: height,
//                               bitsPerComponent: bitsPerComponent,
//                                    bytesPerRow: bytesPerRow,
//                                          space: colorSpace,
//                                     bitmapInfo: bitmapInfo.rawValue)
//                contextRef?.draw(imageRef, in: CGRect(x: 0.0, y: 0.0, width: CGFloat(width), height: CGFloat(height)))
//
//                pixelValues = intensities
//            }
//
//            return pixelValues
//    }
    
    // Convert CIImage to CGImage
//    func convertCIImageToCGImage(inputImage: CIImage) -> CGImage? {
//        let context = CIContext(options: nil)
//        if let cgImage = context.createCGImage(inputImage, from: inputImage.extent) {
//            return cgImage
//        }
//        return nil
//    }
    
    
}
