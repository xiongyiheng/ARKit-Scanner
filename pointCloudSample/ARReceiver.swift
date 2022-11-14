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
            return dir.appendingPathComponent(videoFilename + "/rgb").appendingPathExtension(videoFilenameExt)
        }
        fatalError("URLForDirectory() failed")
    }
}

class BinaryFrameDataWriter {
    var fileHandle: FileHandle?
    init(depthURL: URL, height: Int, width: Int) {
        print(depthURL.path)

        do {
            FileManager.default.createFile(atPath: depthURL.path, contents: nil, attributes: nil)
            try self.fileHandle = FileHandle(forWritingTo: depthURL)
        } catch let error as NSError {
            print("FITFile >>> File open failed: \(error)")
        }
    }
    
    func writerFrame(frameData: Data, compress: Bool) {
        if let fileHandle = self.fileHandle {
            if compress {
                do {
//                    print("original size: \(frameData.count) bytes")
                    let compressedFrameData = try (frameData as NSData).compressed(using: .zlib)
//                    print("zlib compressed size: \(compressedFrameData.count) bytes")
                    var size = Int32(compressedFrameData.count);
                    fileHandle.write(Data(bytes: &size, count: MemoryLayout.size(ofValue: size)))
                    fileHandle.write(compressedFrameData as Data)
                } catch {
                    print ("Compression error: \(error)")
                }
            }
            else {
                fileHandle.write(frameData)
            }
            do {
                try fileHandle.synchronize()
            } catch {
                print(error)
            }
        }
        else {
            print("No handle")
        }
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
    var depthWriter: BinaryFrameDataWriter?

    var motion = CMMotionManager()

    var metadata: [String: String] = [:]
    var cameraTransformDic: [String: String] = [:]
    var exposureOffsetDic: [String: String] = [:]
    var imuDic: [String: String] = [:]
    
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

    func startRecord(sceneName: String, sceneType: String, colorWidth: Int, colorHeight: Int, depthWidth: Int, depthHeight: Int) {
        let currentTime = Date()
        let dateFormater = DateFormatter()
        dateFormater.dateFormat = "dd-MM-YY HH:mm:ss"
        self.directory = sceneName + " " + dateFormater.string(from: currentTime)
        
        // create directory
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let folderPath = dir.appendingPathComponent(self.directory)
            if !FileManager.default.fileExists(atPath: folderPath.path) {
                do {
                    print("Create folder \(folderPath.path)")
                    try FileManager.default.createDirectory(atPath: folderPath.path, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    print(error)
                }
            }
            let depthURL = dir.appendingPathComponent(self.directory + "/depth.bin")
            self.depthWriter = BinaryFrameDataWriter(depthURL: depthURL, height: depthHeight, width: depthWidth)
        }
        self.settings.videoFilename = directory
        self.settings.size.width = CGFloat(colorWidth)
        self.settings.size.height = CGFloat(colorHeight)
        self.videoWriter = VideoWriter(videoSettings: self.settings)
        self.videoWriter!.start()

        self.metadata = [:]
        self.metadata["scene_name"] = sceneName
        self.metadata["scene_type"] = sceneType
        self.metadata["color_width"] = colorWidth.description
        self.metadata["color_height"] =  colorHeight.description
        self.metadata["depth_width"] = depthWidth.description
        self.metadata["depth_height"] = depthHeight.description

        self.isRecord = true
        self.frameNum = 0

    }

    func endRecord() {
        self.motion.stopDeviceMotionUpdates()
        pause()
        self.isRecord = false
        // save metadata when finishing recording

        let cameraIntrinsics = (0..<3).flatMap { x in (0..<3).map { y in arData.cameraIntrinsics[x][y] } }
        self.metadata["intrinsic"] = "[" + cameraIntrinsics[0].description + "," + cameraIntrinsics[1].description + "," + cameraIntrinsics[2].description + "," + cameraIntrinsics[3].description + "," + cameraIntrinsics[4].description + "," + cameraIntrinsics[5].description + "," + cameraIntrinsics[6].description + "," + cameraIntrinsics[7].description + "," + cameraIntrinsics[8].description + "]"
        self.metadata["exposure_duration"] = arData.exposureDuration.description
        
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let encoder = JSONEncoder()
            if let jsonMetaData = try? encoder.encode(self.metadata), let jsonTrans = try? encoder.encode(self.cameraTransformDic), let jsonOffset = try? encoder.encode(self.exposureOffsetDic), let jsonIMU = try? encoder.encode(self.imuDic) {
                let metadataURL = dir.appendingPathComponent(self.directory + "/metadata.json")
                let transURL = dir.appendingPathComponent(self.directory + "/trans.json")
                let offsetURL = dir.appendingPathComponent(self.directory + "/offset.json")
                let imuURL = dir.appendingPathComponent(self.directory + "/imu.json")
                print(metadataURL.path)
                do {
                    try jsonMetaData.write(to: metadataURL)
                    try jsonTrans.write(to: transURL)
                    try jsonOffset.write(to: offsetURL)
                    try jsonIMU.write(to: imuURL)
                } catch {
                    print("metadata writing errors")
                }
            }
        }

        // reinitilize dics
        self.cameraTransformDic = [String: String]()
        self.exposureOffsetDic = [String: String]()
        self.imuDic = [String: String]()
        
        // finish video generating
        self.videoWriter!.videoWriterInput.markAsFinished()
        self.videoWriter!.videoWriter.finishWriting {
            print("finish video generating")
        }
        start()
        self.motion.startDeviceMotionUpdates()
    }
    
    func readARData(frame: ARFrame) {
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
    }

    // Send required data from `ARFrame` to the delegate class via the `onNewARData` callback.
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if(frame.sceneDepth != nil) && (frame.smoothedSceneDepth != nil) {
            readARData(frame: frame)

            if self.videoWriter == nil || !self.videoWriter!.isReadyForData {
                return
            }

            if self.isRecord {
//                let ciImageColor = CIImage(cvPixelBuffer: frame.capturedImage)
//                let contextColor:CIContext = CIContext.init(options: nil)
//                let cgImageColor:CGImage = contextColor.createCGImage(ciImageColor, from: ciImageColor.extent)!
//                let uiImageColor:UIImage = UIImage(cgImage: cgImageColor, scale: 1, orientation: UIImage.Orientation.up)

                CVPixelBufferLockBaseAddress(arData.depthImage!, CVPixelBufferLockFlags(rawValue: 0))
                let depthAddr = CVPixelBufferGetBaseAddress(arData.depthImage!)
                let depthHeight = CVPixelBufferGetHeight(arData.depthImage!)
                let depthBpr = CVPixelBufferGetBytesPerRow(arData.depthImage!)
                let depthBuffer = Data(bytes: depthAddr!, count: (depthBpr*depthHeight))
                if let depthWriter = self.depthWriter {
                    depthWriter.writerFrame(frameData: depthBuffer, compress: true)
                }
                CVPixelBufferUnlockBaseAddress(arData.depthImage!,  CVPixelBufferLockFlags(rawValue: 0));
                // save as video
                let frameDuration = CMTimeMake(value: 1, timescale: settings.fps)
                let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(self.frameNum))
                if self.frameNum < 10 {
                    print(presentationTime)
                }
                let success = self.videoWriter!.addBuffer(pixelBuffer: arData.colorImage!, withPresentationTime: presentationTime)
                if success == false {
                    fatalError("addBuffer() failed")
                }
                
                let cameraTransform = (0..<4).flatMap { x in (0..<4).map { y in arData.cameraTransform[x][y] } }
                cameraTransformDic[self.frameNum.description + ""] = "[" + cameraTransform[0].description + "," + cameraTransform[1].description + "," + cameraTransform[2].description + "," + cameraTransform[3].description + "," + cameraTransform[4].description + "," + cameraTransform[5].description + "," + cameraTransform[6].description + "," + cameraTransform[7].description + "," + cameraTransform[8].description + "," + cameraTransform[9].description + "," + cameraTransform[10].description + "," + cameraTransform[11].description + "," + cameraTransform[12].description + "," + cameraTransform[13].description + "," + cameraTransform[14].description + "," + cameraTransform[15].description + "]"
                exposureOffsetDic[self.frameNum.description + ""] = "" + arData.exposureOffset.description
                
                // imu data
                if let data = self.motion.deviceMotion {
                    imuDic[self.frameNum.description + ""] = "[" + data.rotationRate.x.description + "," +  data.rotationRate.y.description + "," + data.rotationRate.z.description + "," +  data.userAcceleration.x.description + "," + data.userAcceleration.y.description + "," +  data.userAcceleration.z.description + "," + data.magneticField.field.x.description + "," + data.magneticField.field.y.description + "," + data.magneticField.field.z.description + "," + data.attitude.roll.description + "," + data.attitude.pitch.description + "," +  data.attitude.yaw.description + "," + data.gravity.x.description + "," + data.gravity.y.description + "," + data.gravity.z.description + "]"
                }
                
                self.frameNum += 1
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
