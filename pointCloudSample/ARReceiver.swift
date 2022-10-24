/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A utility class that receives processed depth information.
*/

import Foundation
import SwiftUI
import Combine
import ARKit
import AVFoundation
import CoreMotion

struct VideoSettings {
    var size = CGSize(width: 1920, height: 1440) // predefined in arkit
    var fps: Int32 = 60   // predefined in arkit
    var avCodecKey = AVVideoCodecType.h264
    var videoFilename = "rgbVideo"
    var videoFilenameExt = "mp4"
    
    var outputURL: URL {
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            return dir.appendingPathComponent(videoFilename + "/video").appendingPathExtension(videoFilenameExt)
        }
        fatalError("URLForDirectory() failed")
    }
}

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
    var uiImageColor = UIImage()
}

// Configure and run an AR session to provide the app with depth-related AR data.
final class ARReceiver: NSObject, ARSessionDelegate {
    var arData = ARData()
    var arSession = ARSession()
    weak var delegate: ARDataReceiver?
    public var isRecord = false
    public var directory = ""
    var frameNum = 0
    var settings = VideoSettings()
    var videoWriter: VideoWriter?
    var depthBufferSequence: Data?
    
    var motion = CMMotionManager()
    
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
        self.frameNum = 0
        if self.isRecord == true {
            self.directory = directory
            self.settings.videoFilename = directory
            self.videoWriter = VideoWriter(videoSettings: self.settings)
            self.videoWriter!.start()
            self.motion.startDeviceMotionUpdates()
        } else {
            self.motion.stopDeviceMotionUpdates()
            self.videoWriter!.videoWriterInput.markAsFinished()
            self.videoWriter!.videoWriter.finishWriting {
                print("finish video generating")
            }
            
            if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                do {
                    try self.depthBufferSequence?.write(to: dir.appendingPathComponent(self.directory + "/" + "depthBufferSequence.bin"))
                } catch {}
            }
        }
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

            let ciImageColor = CIImage(cvPixelBuffer: frame.capturedImage)
            let contextColor:CIContext = CIContext.init(options: nil)
            let cgImageColor:CGImage = contextColor.createCGImage(ciImageColor, from: ciImageColor.extent)!
            let uiImageColor:UIImage = UIImage(cgImage: cgImageColor, scale: 1, orientation: UIImage.Orientation.up)
            arData.uiImageColor = uiImageColor
            
            if self.isRecord {
                let fileName = "" + arData.timeStamp.description
                CVPixelBufferLockBaseAddress(arData.depthImage!, CVPixelBufferLockFlags(rawValue: 0))
                let depthAddr = CVPixelBufferGetBaseAddress(arData.depthImage!)
                let depthHeight = CVPixelBufferGetHeight(arData.depthImage!)
                let depthBpr = CVPixelBufferGetBytesPerRow(arData.depthImage!)
                let depthBuffer = Data(bytes: depthAddr!, count: (depthBpr*depthHeight))
                
                // save as video
                let frameDuration = CMTimeMake(value: 1, timescale: settings.fps)
                let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(self.frameNum))
                let success = self.videoWriter!.addBuffer(pixelBuffer: arData.colorImage!, withPresentationTime: presentationTime)
                if success == false {
                    fatalError("addBuffer() failed")
                }
                
                // save a binary sequence
                if self.frameNum == 0 {
                    self.depthBufferSequence = depthBuffer
                } else {
                    self.depthBufferSequence?.append(depthBuffer)
                }
                
                self.frameNum += 1
                
                let cameraIntrinsics = (0..<3).flatMap { x in (0..<3).map { y in arData.cameraIntrinsics[x][y] } }
                let cameraTransform = (0..<4).flatMap { x in (0..<4).map { y in arData.cameraTransform[x][y] } }
                let exposureDuration = "" + arData.exposureDuration.description
                let exposureOffset = "" + arData.exposureOffset.description
                
                // imu data
                if let data = self.motion.deviceMotion {
                    let imu = NSArray(array: [data.rotationRate.x, data.rotationRate.y, data.rotationRate.z, data.userAcceleration.x, data.userAcceleration.y, data.userAcceleration.z, data.magneticField.field.x, data.magneticField.field.y, data.magneticField.field.z, data.attitude.roll, data.attitude.pitch, data.attitude.yaw, data.gravity.x, data.gravity.y, data.gravity.z])
                    // imu data's timestamp is different from arkit's
                    let motionFileName = "" + data.timestamp.description
                    if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                        let imuURL = dir.appendingPathComponent(self.directory + "/" + motionFileName + "_imu.xml")
                        (imu as NSArray).write(to: imuURL, atomically: false)
                    }
                }
                
                if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                    let intriURL = dir.appendingPathComponent(self.directory + "/intri.xml")
                    let transURL = dir.appendingPathComponent(self.directory + "/" + fileName + "_trans.xml")
                    let duraURL = dir.appendingPathComponent(self.directory + "/dura.txt")
                    let offsetURL = dir.appendingPathComponent(self.directory + "/" + fileName + "_offset.txt")
//                    let depthBufferURL = dir.appendingPathComponent(self.directory + "/" + fileName + "_depthBuffer.bin")
//                    let colorJpgURL = dir.appendingPathComponent(self.directory + "/" + fileName + "_color.jpeg")
//                    let imuURL = dir.appendingPathComponent(self.directory + "/" + fileName + "_imu.xml")
                    
                    //writing
                    do {
//                        try depthBuffer.write(to: depthBufferURL)
//                        try uiImageColor.jpegData(compressionQuality: 0.0)!.write(to: colorJpgURL)
                        (cameraIntrinsics as NSArray).write(to: intriURL, atomically: false)
                        (cameraTransform as NSArray).write(to: transURL, atomically: false)
                        try exposureDuration.write(to: duraURL, atomically: false, encoding: .utf8)
                        try exposureOffset.write(to: offsetURL, atomically: false, encoding: .utf8)
//                        (imu as NSArray).write(to: imuURL, atomically: false)
                    }
                    catch {/* error handling here */}
                }
            }
        }
    }
}

class VideoWriter {
    
    var videoSettings: VideoSettings
    
    var videoWriter: AVAssetWriter!
    var videoWriterInput: AVAssetWriterInput!
    var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor!
    
    var isReadyForData: Bool {
        return videoWriterInput?.isReadyForMoreMediaData ?? false
    }
    
    init(videoSettings: VideoSettings) {
        self.videoSettings = videoSettings
    }
    
    func start() {
        
        let avOutputSettings: [String: Any] = [
            AVVideoCodecKey: videoSettings.avCodecKey,
            AVVideoWidthKey: NSNumber(value: Float(videoSettings.size.width)),
            AVVideoHeightKey: NSNumber(value: Float(videoSettings.size.height))
        ]
        
        func createPixelBufferAdaptor() {
            let sourcePixelBufferAttributesDictionary = [
                kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32RGBA),
                kCVPixelBufferWidthKey as String: NSNumber(value: Float(videoSettings.size.width)),
                kCVPixelBufferHeightKey as String: NSNumber(value: Float(videoSettings.size.height))
            ]
            pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoWriterInput,
                                                                      sourcePixelBufferAttributes: sourcePixelBufferAttributesDictionary)
        }
        
        func createAssetWriter(outputURL: URL) -> AVAssetWriter {
            guard let assetWriter = try? AVAssetWriter(outputURL: outputURL, fileType: AVFileType.mp4) else {
                fatalError("AVAssetWriter() failed")
            }
            
            guard assetWriter.canApply(outputSettings: avOutputSettings, forMediaType: AVMediaType.video) else {
                fatalError("canApplyOutputSettings() failed")
            }
            
            return assetWriter
        }
        
        videoWriter = createAssetWriter(outputURL: videoSettings.outputURL)
        videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: avOutputSettings)
        
        if videoWriter.canAdd(videoWriterInput) {
            videoWriter.add(videoWriterInput)
        }
        else {
            fatalError("canAddInput() returned false")
        }
        
        // The pixel buffer adaptor must be created before we start writing.
        createPixelBufferAdaptor()
        
        if videoWriter.startWriting() == false {
            fatalError("startWriting() failed")
        }
        
        videoWriter.startSession(atSourceTime: CMTime.zero)
        
        precondition(pixelBufferAdaptor.pixelBufferPool != nil, "nil pixelBufferPool")
    }
    
    func addBuffer(pixelBuffer: CVPixelBuffer, withPresentationTime presentationTime: CMTime) -> Bool {
        precondition(pixelBufferAdaptor != nil, "Call start() to initialze the writer")
        return pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
    }
}
