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
    
    @State var recordStatus: String = "RECORD"
    @State var displayStatus: String = "DEPTH"
    
    @State var timer: Timer?
    @State var accumulatedTime = 0
    @State var accumulatedTime_str = "0:0:0"
    
    var body: some View {
        if !ARWorldTrackingConfiguration.supportsFrameSemantics([.sceneDepth, .smoothedSceneDepth]) {
            Text("Unsupported Device: This app requires the LiDAR Scanner to access the scene's depth.")
        } else {
            GeometryReader { geometry in
                VStack() {
                    Text(self.accumulatedTime_str)
                    
                    if self.displayStatus == "DEPTH" {
                        MetalTextureViewColor(colorYContent: arProvider.colorYContent, colorCbCrContent: arProvider.colorCbCrContent)
                    } else {
                        MetalTextureViewDepth(content: arProvider.depthContent, confSelection: $selectedConfidence)
                    }
                    
                    Button(self.displayStatus) {
                        if self.displayStatus == "DEPTH" {
                            self.displayStatus = "RGB"
                        } else {
                            self.displayStatus = "DEPTH"
                        }
                    }
                    
                    Button(self.recordStatus) {
                        if arProvider.arReceiver.isRecord == false {
                            // timer initialization
                            self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                                self.accumulatedTime += 1
                                let (h,m,s) = secondsToHoursMinutesSeconds(self.accumulatedTime)
                                self.accumulatedTime_str = String(h) + ":" + String(m) + ":" + String(s)
                            }
                            self.recordStatus = "STOP"
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
                            self.timer?.invalidate()
                            self.accumulatedTime = 0
                            self.accumulatedTime_str = "0:0:0"
                            self.recordStatus = "RECORD"
                            arProvider.record(isRecord: false, directory: "")
                        }
                    }.padding()
                        .foregroundColor(.black)
                        .background(Color(red: 1, green: 0, blue: 0))
                        .clipShape(Capsule())
                }
            }
        }
    }
}

// helper function
func secondsToHoursMinutesSeconds(_ seconds: Int) -> (Int, Int, Int) {
    return (seconds / 3600, (seconds % 3600) / 60, (seconds % 3600) % 60)
}
