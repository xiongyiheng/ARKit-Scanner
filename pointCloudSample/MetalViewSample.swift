/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 A parent view class that displays the sample app's other views.
 */

import Foundation
import SwiftUI
import MetalKit
import ARKit
import UIKit

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
    @State var accumulatedTime_str = "00:00"
    @State var sceneName: String = ""
    @State var sceneType = "apartment"
    let sceneTypes = ["apartment", "bathroom", "bedroom / hotel", "bookstore / library", "conference room", "copy / mail room", "hallway", "kitchen", "laundry room", "living room / lounge", "office", "storage / basement / garage", "classroom", "misc"]
    
    var body: some View {
        if !ARWorldTrackingConfiguration.supportsFrameSemantics([.sceneDepth, .smoothedSceneDepth]) {
            Text("Unsupported Device: This app requires the LiDAR Scanner to access the scene's depth.")
        } else {
            GeometryReader { geometry in
                VStack(alignment: .leading) {
                    HStack() {
                        if #available(iOS 15.0, *) {
                            TextField(
                                "Scene Name",
                                text: $sceneName
                            )
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .border(.secondary)
                            .frame(width: 100)
                            
                        } else {
                            // Fallback on earlier versions
                        }
                        
                        Picker("", selection: $sceneType) {
                            ForEach(sceneTypes, id: \.self) {
                                Text($0)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 120)
                        
                        Text(self.accumulatedTime_str).frame(width: 80)
                        
                    }
                    
                    if self.displayStatus == "DEPTH" {
                        MetalTextureViewColor(colorYContent: arProvider.colorYContent, colorCbCrContent: arProvider.colorCbCrContent).frame(width: 192 * 2, height: 256 * 2)
                        
                    } else {
                        MetalTextureViewColor(colorYContent: arProvider.colorYContent, colorCbCrContent: arProvider.colorCbCrContent).frame(width: 192 * 2, height: 256 * 2).overlay(MetalTextureViewDepth(content: arProvider.depthContent, confSelection: $selectedConfidence).frame(width: 192 * 2, height: 256 * 2).opacity(0.5))
                    }
                    
                }
                
            }
            HStack() {
                Button(self.displayStatus) {
                    if self.displayStatus == "DEPTH" {
                        self.displayStatus = "RGB"
                    } else {
                        self.displayStatus = "DEPTH"
                    }
                }.opacity(0.7).frame(width: 80)
                
                Button(self.recordStatus) {
                    if arProvider.arReceiver.isRecord == false {
                        // timer initialization
                        self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                            self.accumulatedTime += 1
                            let (_,m,s) = secondsToHoursMinutesSeconds(self.accumulatedTime)
//                            var h_str = String(h)
                            var m_str = String(m)
                            var s_str = String(s)
//                            if h_str.count == 1 {
//                                h_str = "0" + h_str
//                            }
                            
                            if m_str.count == 1 {
                                m_str = "0" + m_str
                            }
                            
                            if s_str.count == 1 {
                                s_str = "0" + s_str
                            }
                                    
                            self.accumulatedTime_str = m_str + ":" + s_str
                        }
                        
                        self.recordStatus = "STOP"
                        let currentTime = Date()
                        let dateFormater = DateFormatter()
                        dateFormater.dateFormat = "dd-MM-YY HH:mm:ss"
                        let directory = sceneName + dateFormater.string(from: currentTime)
                        
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
                        arProvider.record(isRecord: true, directory: directory, sceneType: self.sceneType, sceneName: self.sceneName)
                    } else {
                        self.timer?.invalidate()
                        self.accumulatedTime = 0
                        self.accumulatedTime_str = "00:00"
                        self.recordStatus = "RECORD"
                        arProvider.record(isRecord: false, directory: "", sceneType: self.sceneType, sceneName: self.sceneName)
                    }
                }.padding()
                    .foregroundColor(.black)
                    .background(Color(red: 1, green: 0, blue: 0))
                    .clipShape(Capsule())
                    .opacity(0.7)
                    .frame(width: 100)
            }
        }
    }
}

// helper function
func secondsToHoursMinutesSeconds(_ seconds: Int) -> (Int, Int, Int) {
    return (seconds / 3600, (seconds % 3600) / 60, (seconds % 3600) % 60)
}
