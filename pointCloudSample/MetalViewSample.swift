/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A parent view class that displays the sample app's other views.
*/

import Foundation
import SwiftUI
import MetalKit
import ARKit

// Add a title to a view that enlarges the view to full screen on tap.
struct Texture<T: View>: ViewModifier {
    let height: CGFloat
    let width: CGFloat
    let title: String
    let view: T
    func body(content: Content) -> some View {
        VStack {
            Text(title).foregroundColor(Color.red)
            // To display the same view in the navigation, reference the view
            // directly versus using the view's `content` property.
            NavigationLink(destination: view.aspectRatio(CGSize(width: width, height: height), contentMode: .fill)) {
                view.frame(maxWidth: width, maxHeight: height, alignment: .center)
                    .aspectRatio(CGSize(width: width, height: height), contentMode: .fill)
            }
        }
    }
}

extension View {
    // Apply `zoomOnTapModifier` with a `self` reference to show the same view
    // on tap.
    func zoomOnTapModifier(height: CGFloat, width: CGFloat, title: String) -> some View {
        modifier(Texture(height: height, width: width, title: title, view: self))
    }
}
extension Image {
    init(_ texture: MTLTexture, ciContext: CIContext, scale: CGFloat, orientation: Image.Orientation, label: Text) {
        let ciimage = CIImage(mtlTexture: texture)!
        let cgimage = ciContext.createCGImage(ciimage, from: ciimage.extent)
        self.init(cgimage!, scale: 1.0, orientation: orientation, label: label)
    }
}
//- Tag: MetalDepthView
struct MetalDepthView: View {
    
    // Set the default sizes for the texture views.
    let sizeH: CGFloat = 256
    let sizeW: CGFloat = 192
    
    // Manage the AR session and AR data processing.
    //- Tag: ARProvider
    var arProvider: ARProvider = ARProvider()
    let ciContext: CIContext = CIContext()
    
    // Save the user's confidence selection.
    @State private var selectedConfidence = 0
    // Set the depth view's state data.
    @State var isToUpsampleDepth = false
    @State var isShowSmoothDepth = false
    @State var isArPaused = false
    @State private var scaleMovement: Float = 1.5
    
    var confLevels = ["🔵🟢🔴", "🔵🟢", "🔵"]
    
    var body: some View {
        if !ARWorldTrackingConfiguration.supportsFrameSemantics([.sceneDepth, .smoothedSceneDepth]) {
            Text("Unsupported Device: This app requires the LiDAR Scanner to access the scene's depth.")
        } else {
            NavigationView {
                GeometryReader { geometry in
                    VStack() {
                        ScrollView(.horizontal) {
                            VStack() {
                                MetalTextureViewDepth(content: arProvider.depthContent, confSelection: $selectedConfidence)
                                    .zoomOnTapModifier(height: sizeH, width: sizeW, title: isToUpsampleDepth ? "Upscaled Depth" : "Depth")
                                MetalTextureViewColor(colorYContent: arProvider.colorYContent, colorCbCrContent: arProvider.colorCbCrContent).zoomOnTapModifier(height: sizeH, width: sizeW, title: "RGB")
                            }
                        }
                        Spacer()
                        Button("Record") {
                            if arProvider.arReceiver.isRecord == false {
                                let currentTime = Date()
                                let dateFormater = DateFormatter()
                                dateFormater.dateFormat = "dd-MM-YY:HH:mm:ss"
                                let directory = dateFormater.string(from: currentTime)
                                // create directory
                                let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
                                let documentsDirectory = paths[0]
                                let docURL = URL(string: documentsDirectory)!
                                let dataPath = docURL.appendingPathComponent(directory)
                                if !FileManager.default.fileExists(atPath: dataPath.path) {
                                    do {
                                        try FileManager.default.createDirectory(atPath: dataPath.path, withIntermediateDirectories: true, attributes: nil)
                                    } catch {
                                        print(error.localizedDescription)
                                    }
                                }
                                arProvider.record(isRecord: true, directory: directory)
                            } else {
                                arProvider.record(isRecord: false, directory: "")
                            }
                        }
                        Spacer()
                        Button("Save") {
                            let currentTime = Date()
                            let dateFormater = DateFormatter()
                            dateFormater.dateFormat = "dd-MM-YY:HH:mm:ss"
                            let directory = dateFormater.string(from: currentTime)
                            // let directory = "testDiretory"
                            // create directory
                            let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
                            let documentsDirectory = paths[0]
                            let docURL = URL(string: documentsDirectory)!
                            let dataPath = docURL.appendingPathComponent(directory)
                            if !FileManager.default.fileExists(atPath: dataPath.path) {
                                do {
                                    try FileManager.default.createDirectory(atPath: dataPath.path, withIntermediateDirectories: true, attributes: nil)
                                } catch {
                                    print(error.localizedDescription)
                                }
                            }
//                            UIImageWriteToSavedPhotosAlbum(arProvider.uiImageColor, nil, nil, nil)
//                            UIImageWriteToSavedPhotosAlbum(arProvider.uiImageDepth, nil, nil, nil)
                            CVPixelBufferLockBaseAddress(arProvider.depthImage!, CVPixelBufferLockFlags(rawValue: 0))
                            let depthAddr = CVPixelBufferGetBaseAddress(arProvider.depthImage!)
                            let depthHeight = CVPixelBufferGetHeight(arProvider.depthImage!)
                            let depthBpr = CVPixelBufferGetBytesPerRow(arProvider.depthImage!)
                            let depthBuffer = Data(bytes: depthAddr!, count: (depthBpr*depthHeight))
                            
                            let uiImageColor = arProvider.uiImageColor
                            
//                            CVPixelBufferLockBaseAddress(arProvider.colorImage!, CVPixelBufferLockFlags(rawValue: 0))
//                            let colorAddr = CVPixelBufferGetBaseAddress(arProvider.colorImage!)
//                            let colorHeight = CVPixelBufferGetHeight(arProvider.colorImage!)
//                            let colorBpr = CVPixelBufferGetBytesPerRow(arProvider.colorImage!)
//                            let colorBuffer = Data(bytes: colorAddr!, count: (colorBpr*colorHeight))
                            
                            let cameraIntrinsics = (0..<3).flatMap { x in (0..<3).map { y in arProvider.cameraIntrinsics[x][y] } }
                            let cameraTransform = (0..<4).flatMap { x in (0..<4).map { y in arProvider.cameraTransform[x][y] } }
                            let exposureDuration = "" + arProvider.exposureDuration.description
                            let exposureOffset = "" + arProvider.exposureOffset.description
                            
                            let fileName = "" + arProvider.timeStamp.description
                            
                            if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                                let intriURL = dir.appendingPathComponent(directory + "/intri.xml")
                                let transURL = dir.appendingPathComponent(directory + "/trans.xml")
                                let duraURL = dir.appendingPathComponent(directory + "/dura.txt")
                                let offsetURL = dir.appendingPathComponent(directory + "/offset.txt")
                                let depthBufferURL = dir.appendingPathComponent(directory + "/" + fileName + "_depthBuffer.bin")
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
                }.navigationViewStyle(StackNavigationViewStyle())
            }
        }
    }
    struct MtkView_Previews: PreviewProvider {
        static var previews: some View {
            Group {
                MetalDepthView().previewDevice("iPad Pro (12.9-inch) (4th generation)")
                MetalDepthView().previewDevice("iPhone 11 Pro")
            }
        }
    }
}
