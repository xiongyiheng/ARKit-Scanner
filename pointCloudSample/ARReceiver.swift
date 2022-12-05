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
import Accelerate
import Compression


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
    var srcBuffer: UnsafeMutablePointer<UInt8>
    var dstBuffer: UnsafeMutablePointer<UInt8>
    let algorithm = COMPRESSION_LZ4_RAW
    var height_ = Int()
    var width_ = Int()

    init(depthURL: URL, height: Int, width: Int) {
        height_ = height
        width_ = width
        print(depthURL.path)
        srcBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: height * width * 4)
        dstBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: height * width * 4)
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
                    frameData.copyBytes(to: srcBuffer, count: height_ * width_ * 2)
                    let compressedSize = compression_encode_buffer(dstBuffer, height_ * width_ * 2,
                                                                   srcBuffer, height_ * width_ * 2,
                                                                   nil,
                                                                   algorithm)

                    print("Before \(frameData.count) bytes. After zlib compressed size: \(compressedSize) bytes")
                    var size = Int32(compressedSize)
                    fileHandle.write(Data(bytes: &size, count: MemoryLayout.size(ofValue: size)))
                    var compressedFrameData = Data(bytes: dstBuffer, count: Int(size))
                    fileHandle.write(compressedFrameData)
                    
//                    let compressedFrameData = try (frameData as NSData).compressed(using: .lz4)
//                    print("Before \(frameData.count) bytes. After zlib compressed size: \(compressedFrameData.count) bytes")
//                    var size = Int32(compressedFrameData.count);
//                    fileHandle.write(Data(bytes: &size, count: MemoryLayout.size(ofValue: size)))
//                    fileHandle.write(compressedFrameData as Data)
                } catch {
                    print ("Compression error: \(error)")
                }
            }
            else {
                fileHandle.write(frameData)
                print("Write \(frameData.count) bytes")
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

class Depth2IntConverter {
    // Convert each pixel from Float32 to UInt16
    var bufferU16 = vImage_Buffer()
    var bufferF32 = vImage_Buffer()
    var dataPtr: UnsafeMutablePointer<UInt8>
    var height_ = Int()
    var width_ = Int()
    let inBitsPerPixel = 32
    let outBitsPerPixel = 16

    init(height: Int, width: Int) {
        height_ = height
        width_ = width
        dataPtr = UnsafeMutablePointer<UInt8>.allocate(capacity: height * width * inBitsPerPixel / 8)
        vImageBuffer_Init(&bufferU16, UInt(height), UInt(width), UInt32(outBitsPerPixel), vImage_Flags(kvImageNoFlags))
    }
    
    func convert(inputData: Data) -> Data {
//        let alignmentAndRowBytes = try vImage_Buffer.preferredAlignmentAndRowBytes(
//            width: width_,
//            height: height_,
//            bitsPerPixel: UInt32(inBitsPerPixel))
        inputData.copyBytes(to: dataPtr, count: height_ * width_ * inBitsPerPixel / 8)
        bufferF32 = vImage_Buffer(data: dataPtr,
                                  height: vImagePixelCount(height_),
                                  width: vImagePixelCount(width_),
                                  rowBytes: width_ * inBitsPerPixel / 8)
        // src_buffer, out_buffer, offset, scale, flag
        // resultPixel = SATURATED_CLIP_0_to_USHRT_MAX( (sourcePixel  - offset) / scale + 0.5f)
        vImageConvert_FTo16U(&bufferF32, &bufferU16, 0, 0.001, vImage_Flags(kvImageNoFlags))
        let debugData = bufferU16.data!.assumingMemoryBound(to: UInt16.self)
        print(debugData[0], debugData[1])
        let outData = Data(bytes: bufferU16.data, count: height_ * width_ * outBitsPerPixel / 8)
        return outData
    }
    
    deinit {
        free(dataPtr)
        free(bufferU16.data)
    }
}

//func convertDepthBuffer(inputBuffer: Data, height: Int, width: Int, bitsPerPixel: Int) -> Data {
//    do {
//
////        print("F32", bufferF32)
//        var bufferF32Format = vImage_CGImageFormat(
//            bitsPerComponent: 32,
//            bitsPerPixel: 32 * 1,
//            colorSpace: nil,
//            bitmapInfo: CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGBitmapInfo.floatComponents.rawValue),
//            version: 0,
//            decode: nil,
//            renderingIntent: .defaultIntent)
//
//        var bufferU16Format = vImage_CGImageFormat(
//            bitsPerComponent: 32,
//            bitsPerPixel: 32 * 1,
//            colorSpace: nil,
//            bitmapInfo: CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGBitmapInfo.floatComponents.rawValue),
//            version: 0,
//            decode: nil,
//            renderingIntent: .defaultIntent)
//        var error = vImageConvert_FTo16U(&bufferF32, &bufferU16, 0, 0.001, vImage_Flags(kvImageNoFlags))  // -> vImage_Error
//
//        print("U16", bufferU16)
//        let debugData = bufferU16.data!.assumingMemoryBound(to: UInt16.self)
//        print(debugData[0], debugData[1])
//        return Data(bytes: bufferU16.data, count: height * width * 16 / 8)
//    } catch let error as NSError {
//        print("convert alignment error: \(error)")
//    } final {
//        free(bufferU16)
//        free(bufferF32)
//        free(dataPtr)
//    }
//    return Data()
////
////    let data = UnsafeMutableRawPointer.allocate(
////        byteCount: alignmentAndRowBytes.rowBytes * height,
////        alignment: alignmentAndRowBytes.alignment)
//
//}

func convertPixelBuffer(inputBuffer: CVPixelBuffer, height: UInt, width: UInt) {
    print(inputBuffer)
    var bufferF32 = vImage_Buffer()
    vImageBuffer_Init(&bufferF32, height, width, 32, vImage_Flags(kvImageNoFlags))
    var bufferU16 = vImage_Buffer()
    vImageBuffer_Init(&bufferU16, height, width, 16, vImage_Flags(kvImageNoFlags))
//    var inputFormat = vImageCVImageFormat.make(buffer: inputBuffer)
    var backgroundColor = CGFloat(0.0)
    var bufferFormat = vImage_CGImageFormat(
        bitsPerComponent: 32,
        bitsPerPixel: 32 * 1,
        colorSpace: nil,
        bitmapInfo: CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGBitmapInfo.floatComponents.rawValue),
        version: 0,
        decode: nil,
        renderingIntent: .defaultIntent)
//    let cvformat = vImageCVImageFormat_CreateWithCVPixelBuffer(inputBuffer)
    let cvformat = vImageCVImageFormat_Create(
//        kCVPixelFormatType_DepthFloat32,
        kCVPixelFormatType_OneComponent32Float,
        kvImage_ARGBToYpCbCrMatrix_ITU_R_709_2,
        kCVImageBufferChromaLocation_TopLeft,
        nil,
        0
    ).takeRetainedValue()
    print(cvformat)
    //.takeRetainedValue()
    var error = kvImageNoError
    error = vImageBuffer_InitWithCVPixelBuffer(&bufferF32, &bufferFormat, inputBuffer, cvformat, nil, vImage_Flags(kvImageNoFlags))
    guard error == kvImageNoError else {
        print("Fail to convert CVPixelBuffer to vImageBuffer")
        return
//        throw EqualizationImageProcessorError.equalizationOperationFailed
    }
//    defer {
//        free(bufferF.data)
//    }
//    vImageBuffer_InitWithCVPixelBuffer(
//        buffer: &buffer,
//        desiredFormat: &bufferFormat,
//        cvPixelBuffer: inputBuffer,
//        cvImageFormat: inputFormat,
//        backgroundColor: &backgroundColor,
//        flags: UInt32(kvImageNoFlags)
//    )
    // src_buffer, out_buffer, offset, scale, flag
    // resultPixel = SATURATED_CLIP_0_to_USHRT_MAX( (sourcePixel  - offset) / scale + 0.5f)
    vImageConvert_FTo16U(&bufferF32, &bufferU16, 0, 4000, vImage_Flags(kvImageNoFlags))  // -> vImage_Error
    bufferFormat = vImage_CGImageFormat(
        bitsPerComponent: 16,
        bitsPerPixel: 16 * 1,
        colorSpace: nil,
        bitmapInfo: CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue),
        version: 0,
        decode: nil,
        renderingIntent: .defaultIntent)
//    var outBuffer = CVPixelBuffer()
//    vImageBuffer_CopyToCVPixelBuffer(&bufferU16, &bufferFormat, inputBuffer, nil, nil, vImage_Flags(kvImageNoFlags))
//    print(inputBuffer)

//    let debugData = bufferU16.data!.assumingMemoryBound(to: UInt16.self)
//    print(debugData[0], debugData[1])
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
    var exifData = [String : Any]()
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
    var depthConverter = Depth2IntConverter(height: 192, width: 256)
    
    var motion = CMMotionManager()
    
    var metadata: [String: String] = [:]
    var cameraTransformDic: [String: String] = [:]
    var intrinsicDic: [String: String] = [:]
    var exposureOffsetDic: [String: String] = [:]
    var imuDic: [String: String] = [:]
    var exifShutterDic: [String: String] = [:]
    var exifBrightnessDic: [String: String] = [:]
    
    // For ultra-wide images
    // var ultra_images = [UIImage]()
//    var captureSession: AVCaptureSession!
//    var cameraOutput: AVCapturePhotoOutput!
    
    // Configure and start the ARSession.
    override init() {
        super.init()
        arSession.delegate = self
        // config ultra images capture
//        captureSession = AVCaptureSession()
//        captureSession.sessionPreset = AVCaptureSession.Preset.photo
//        cameraOutput = AVCapturePhotoOutput()
//
//        if let device = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back),
//           let input = try? AVCaptureDeviceInput(device: device) {
//            if (captureSession.canAddInput(input)) {
//                captureSession.addInput(input)
//                if (captureSession.canAddOutput(cameraOutput)) {
//                    captureSession.addOutput(cameraOutput)
//                    captureSession.startRunning()
//                }
//            } else {
//                print("issue here : captureSesssion.canAddInput")
//            }
//        } else {
//            print("some problem here")
//        }
        
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
        // captureSession.stopRunning()
    }
    
    func startRecord(sceneName: String, sceneType: String, colorWidth: Int, colorHeight: Int, depthWidth: Int, depthHeight: Int) {
        
        let currentTime = Date()
        let dateFormater = DateFormatter()
        dateFormater.dateFormat = "YYYY-MM-dd_HH-mm-ss"
        self.directory = sceneName + "_" + dateFormater.string(from: currentTime)

        self.motion.startDeviceMotionUpdates()
        
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
        
        self.isRecord = true
        self.frameNum = 0
        
        self.metadata = [:]
        self.metadata["scene_name"] = sceneName
        self.metadata["scene_type"] = sceneType
        self.metadata["color_width"] = colorWidth.description
        self.metadata["color_height"] =  colorHeight.description
        self.metadata["depth_width"] = depthWidth.description
        self.metadata["depth_height"] = depthHeight.description
        
    }
    
    func endRecord() {
        self.motion.stopDeviceMotionUpdates()
        pause()
        self.isRecord = false
        
        // save metadata when finishing recording
        self.metadata["exposure_duration"] = arData.exposureDuration.description
        
        // save global exif data in metadata
        self.metadata["exif_OffsetTime"] = arData.exifData["OffsetTime"] as? String
        self.metadata["exif_ExposureBiasValue"] = "\(String(describing: arData.exifData["ExposureBiasValue"]!))"
        self.metadata["exif_ExifVersion"] = arData.exifData["ExifVersion"] as? String
        self.metadata["exif_SceneType"] = "\(String(describing: arData.exifData["SceneType"]!))"
        self.metadata["exif_SensingMethod"] = "\(String(describing: arData.exifData["SensingMethod"]!))"
        self.metadata["exif_FocalLength"] = "\(String(describing: arData.exifData["FocalLength"]!))"
        self.metadata["exif_LensMake"] = arData.exifData["LensMake"] as? String
        self.metadata["exif_LensModel"] = arData.exifData["LensModel"] as? String
        self.metadata["exif_ApertureValue"] = "\(String(describing: arData.exifData["ApertureValue"]!))"
        self.metadata["exif_FNumber"] = "\(String(describing: arData.exifData["FNumber"]!))"
        self.metadata["exif_FocalLenIn35mmFilm"] = "\(String(describing: arData.exifData["FocalLenIn35mmFilm"]!))"
        self.metadata["exif_OffsetTimeDigitized"] = arData.exifData["OffsetTimeDigitized"] as? String
        self.metadata["exif_Flash"] = "\(String(describing: arData.exifData["Flash"]!))"
        self.metadata["exif_OffsetTimeOriginal"] = arData.exifData["OffsetTimeOriginal"] as? String
        self.metadata["exif_MeteringMode"] = "\(String(describing: arData.exifData["MeteringMode"]!))"
        self.metadata["exif_WhiteBalance"] = "\(String(describing: arData.exifData["WhiteBalance"]!))"
        self.metadata["exif_ColorSpace"] = "\(String(describing: arData.exifData["ColorSpace"]!))"

        self.metadata["exif_ISOSpeedRatings"] = "\(String(describing: (arData.exifData["ISOSpeedRatings"] as! NSArray?)![0]))"
        self.metadata["exif_LensSpecification"] = "\(String(describing: (arData.exifData["LensSpecification"] as! NSArray?)![0]))" + "," + "\(String(describing: (arData.exifData["LensSpecification"] as! NSArray?)![1]))" + "," + "\(String(describing: (arData.exifData["LensSpecification"] as! NSArray?)![2]))" + "," + "\(String(describing: (arData.exifData["LensSpecification"] as! NSArray?)![3]))"
        
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let encoder = JSONEncoder()
            if let jsonMetaData = try? encoder.encode(self.metadata), let jsonTrans = try? encoder.encode(self.cameraTransformDic), let jsonIntrinsic = try? encoder.encode(self.intrinsicDic), let jsonOffset = try? encoder.encode(self.exposureOffsetDic), let jsonIMU = try? encoder.encode(self.imuDic), let jsonExifShutter = try? encoder.encode(self.exifShutterDic), let jsonExifBrightness = try? encoder.encode(self.exifBrightnessDic) {
                let metadataURL = dir.appendingPathComponent(self.directory + "/metadata.json")
                let transURL = dir.appendingPathComponent(self.directory + "/trans.json")
                let intriURL = dir.appendingPathComponent(self.directory + "/intri.json")
                let offsetURL = dir.appendingPathComponent(self.directory + "/offset.json")
                let imuURL = dir.appendingPathComponent(self.directory + "/imu.json")
                print(metadataURL.path)
                let exifShutterURL = dir.appendingPathComponent(self.directory + "/exif_ShutterSpeedValue.json")
                let exifBrightnessURL = dir.appendingPathComponent(self.directory + "/exif_BrightnessValue.json")
                do {
                    try jsonMetaData.write(to: metadataURL)
                    try jsonTrans.write(to: transURL)
                    try jsonIntrinsic.write(to: intriURL)
                    try jsonOffset.write(to: offsetURL)
                    try jsonIMU.write(to: imuURL)
                    try jsonExifShutter.write(to: exifShutterURL)
                    try jsonExifBrightness.write(to: exifBrightnessURL)
                } catch {
                    print("metadata writing errors")
                }
            }
        }
        
        // reinitilize dics
        self.cameraTransformDic = [String: String]()
        self.intrinsicDic = [String: String]()
        self.exposureOffsetDic = [String: String]()
        self.imuDic = [String: String]()
        self.exifShutterDic = [String: String]()
        self.exifBrightnessDic = [String: String]()
        
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
        if #available(iOS 16.0, *) {
            arData.exifData = frame.exifData
        } else {
            // Fallback on earlier versions
        }
    }
    
    // Send required data from `ARFrame` to the delegate class via the `onNewARData` callback.
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if(frame.sceneDepth != nil) && (frame.smoothedSceneDepth != nil) {
            readARData(frame: frame)
            
            if self.videoWriter == nil || !self.videoWriter!.isReadyForData {
                return
            }
            
            if self.isRecord {
                
                CVPixelBufferLockBaseAddress(arData.depthImage!, CVPixelBufferLockFlags(rawValue: 0))
                let depthAddr = CVPixelBufferGetBaseAddress(arData.depthImage!)
                let depthHeight = CVPixelBufferGetHeight(arData.depthImage!)
                let depthBpr = CVPixelBufferGetBytesPerRow(arData.depthImage!)
                let depthBuffer = Data(bytes: depthAddr!, count: (depthBpr*depthHeight))
                let depthBufferU16 = depthConverter.convert(inputData: depthBuffer)
                if let depthWriter = self.depthWriter {
                    depthWriter.writerFrame(frameData: depthBufferU16, compress: true)
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
                self.cameraTransformDic[arData.timeStamp.description] = "[" + cameraTransform[0].description + "," + cameraTransform[1].description + "," + cameraTransform[2].description + "," + cameraTransform[3].description + "," + cameraTransform[4].description + "," + cameraTransform[5].description + "," + cameraTransform[6].description + "," + cameraTransform[7].description + "," + cameraTransform[8].description + "," + cameraTransform[9].description + "," + cameraTransform[10].description + "," + cameraTransform[11].description + "," + cameraTransform[12].description + "," + cameraTransform[13].description + "," + cameraTransform[14].description + "," + cameraTransform[15].description + "]"
                self.exposureOffsetDic[arData.timeStamp.description] = arData.exposureOffset.description
                
                let cameraIntrinsics = (0..<3).flatMap { x in (0..<3).map { y in arData.cameraIntrinsics[x][y] } }
                self.intrinsicDic[arData.timeStamp.description] = "[" + cameraIntrinsics[0].description + "," + cameraIntrinsics[1].description + "," + cameraIntrinsics[2].description + "," + cameraIntrinsics[3].description + "," + cameraIntrinsics[4].description + "," + cameraIntrinsics[5].description + "," + cameraIntrinsics[6].description + "," + cameraIntrinsics[7].description + "," + cameraIntrinsics[8].description + "]"
                
                // imu data
                if let data = self.motion.deviceMotion {
                    imuDic[data.timestamp.description] = "[" + data.rotationRate.x.description + "," +  data.rotationRate.y.description + "," + data.rotationRate.z.description + "," +  data.userAcceleration.x.description + "," + data.userAcceleration.y.description + "," +  data.userAcceleration.z.description + "," + data.magneticField.field.x.description + "," + data.magneticField.field.y.description + "," + data.magneticField.field.z.description + "," + data.attitude.roll.description + "," + data.attitude.pitch.description + "," +  data.attitude.yaw.description + "," + data.gravity.x.description + "," + data.gravity.y.description + "," + data.gravity.z.description + "]"
                }
                
                // ultra image
//                let ultra_settings = AVCapturePhotoSettings()
//                self.cameraOutput.capturePhoto(with: ultra_settings, delegate: self)
                
                // non-global exif data
                self.exifShutterDic[arData.timeStamp.description] = "\(String(describing: arData.exifData["ShutterSpeedValue"]!))"
                self.exifBrightnessDic[arData.timeStamp.description] = "\(String(describing: arData.exifData["BrightnessValue"]!))"
                
                self.frameNum += 1
            }
        }
    }
}

//extension ARReceiver: AVCapturePhotoCaptureDelegate {
//    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
//
//        if let error = error {
//            print("error occured : \(error.localizedDescription)")
//        }
//
//        if let dataImage = photo.fileDataRepresentation() {
//            print("size is:")
//            print(UIImage(data: dataImage)?.size as Any)
//
////            let dataProvider = CGDataProvider(data: dataImage as CFData)
////            let cgImageRef: CGImage! = CGImage(jpegDataProviderSource: dataProvider!, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
////             let image = UIImage(cgImage: cgImageRef, scale: 1.0, orientation: UIImage.Orientation.right)
//
//            /**
//             save image in array / do whatever you want to do with the image here
//             */
////             self.images.append(image)
//
//        } else {
//            print("no photo")
//        }
//    }
//}

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
