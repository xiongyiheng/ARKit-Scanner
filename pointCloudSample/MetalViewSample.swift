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
    let sizeH: CGFloat = 256 * 1.55
    let sizeW: CGFloat = 192 * 1.55
    
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
    
    @State var sceneName: String = ""
    @State var sceneType = "apartment"
    let sceneTypes = ["apartment", "bathroom", "bedroom / hotel", "bookstore / library", "conference room", "copy / mail room", "hallway", "kitchen", "laundry room", "living room / lounge", "office", "storage / basement / garage", "classroom", "misc"]
    
    var body: some View {
        if !ARWorldTrackingConfiguration.supportsFrameSemantics([.sceneDepth, .smoothedSceneDepth]) {
            Text("Unsupported Device: This app requires the LiDAR Scanner to access the scene's depth.")
        } else {
            GeometryReader { geo in
                VStack(alignment: .center) {
                    HStack(alignment: .center) {
                        if #available(iOS 15.0, *) {
                            TextField(
                                "Scene Name",
                                text: $sceneName
                            )
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .border(.secondary)
                            .padding([.leading, .trailing], 20).frame(height: 30)
                        } else {
                            // Fallback on earlier versions
                            TextField(
                                "Scene Name",
                                text: $sceneName
                            ).padding([.leading, .trailing], 20).frame(height: 30)
                        }
                    }
                    HStack(alignment: .center) {
                        FPSView(arProvider: arProvider)
                        Picker("", selection: $sceneType) {
                            ForEach(sceneTypes, id: \.self) {
                                Text($0)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 120)
                        
                        if (self.recordStatus == "STOP") {
                            AccumulatedTimeView(isRecord: true)
                        } else {
                            AccumulatedTimeView(isRecord: false)
                        }
                        
                    }.frame(height: 25)
                    ZStack(alignment: .bottom) {
                        if self.displayStatus == "DEPTH" {
                            MetalTextureViewColor(colorYContent: arProvider.colorYContent, colorCbCrContent: arProvider.colorCbCrContent).frame(width: sizeW, height: sizeH)
                        } else {
                            MetalTextureViewColor(colorYContent: arProvider.colorYContent, colorCbCrContent: arProvider.colorCbCrContent).frame(width: sizeW, height: sizeH).overlay(MetalTextureViewDepth(content: arProvider.depthContent, confSelection: $selectedConfidence).frame(width: sizeW, height: sizeH).opacity(0.5))
                        }
                        Spacer()
                        
                        HStack (alignment: .center){
                            Button(self.displayStatus) {
                                if self.displayStatus == "DEPTH" {
                                    self.displayStatus = "RGB"
                                } else {
                                    self.displayStatus = "DEPTH"
                                }
                            }.opacity(0.7).frame(width: 100).clipShape(Capsule()).padding([.trailing, .bottom], 20)
                            
                            Button(self.recordStatus) {
                                if arProvider.arReceiver.isRecord == false {
                                    self.recordStatus = "STOP"
                                    arProvider.startRecord(sceneName: sceneName, sceneType: sceneType)
                                    
                                } else {
                                    self.recordStatus = "RECORD"
                                    arProvider.endRecord()
                                }
                            }.padding()
                                .foregroundColor(.black)
                                .background(Color(red: 1, green: 0, blue: 0))
                                .clipShape(Capsule())
                                .opacity(0.7)
                                .frame(width: 100)
                                .padding([.bottom], 10)
                            
                        }
                    }
                }
                
            }
        }
    }
}

struct FPSView: View {
    @State var frameRate = Double()
    var arProvider: ARProvider?
    init(arProvider: ARProvider) {
        self.arProvider = arProvider
    }
    let fpsTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    var body: some View {
        Text(String(format: "FPS: %.2f", self.frameRate)).frame(width: 100)
            .onReceive(self.fpsTimer) { input in
                self.frameRate = self.arProvider!.frameRate
                // print("refresh")
            }
    }
}

struct AccumulatedTimeView: View {
    @State var accumulatedTime = 0
    @State var accumulatedTime_str = "00:00"
    @State var isRecord = true
    init(isRecord: Bool) {
        self.isRecord = isRecord
    }
    let recordTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    var body: some View {
        Text(self.accumulatedTime_str).frame(width: 80)
            .onReceive(self.recordTimer) { input in
                if (self.isRecord == true) {
                    self.accumulatedTime += 1
                    let (_,m,s) = secondsToHoursMinutesSeconds(self.accumulatedTime)
                    var m_str = String(m)
                    var s_str = String(s)
                    if m_str.count == 1 {
                        m_str = "0" + m_str
                    }
                    if s_str.count == 1 {
                        s_str = "0" + s_str
                    }
                    
                    self.accumulatedTime_str = m_str + ":" + s_str
                    print("refresh when true")
                } else {
                    print("refresh when false")
                    self.accumulatedTime = 0
                    self.accumulatedTime_str = "00:00"
                }
            }
        
    }
}

// helper function
func secondsToHoursMinutesSeconds(_ seconds: Int) -> (Int, Int, Int) {
    return (seconds / 3600, (seconds % 3600) / 60, (seconds % 3600) % 60)
}
