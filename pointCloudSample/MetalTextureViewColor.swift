/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A view that combines colorY and colorCbCr textures into one RGB texture and draws it.
*/

import Foundation
import SwiftUI
import MetalKit
import Metal

final class CoordinatorColor: MTKCoordinator {
    var colorYContent: MetalTextureContent
    var colorCbCrContent: MetalTextureContent
    init(colorYContent: MetalTextureContent, colorCbCrContent: MetalTextureContent) {
        self.colorYContent = colorYContent
        self.colorCbCrContent = colorCbCrContent
        super.init(content: colorYContent)
    }
    override func prepareFunctions() {
        guard let metalDevice = mtkView.device else { fatalError("Expected a Metal device.") }
        do {
            let library = EnvironmentVariables.shared.metalLibrary
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipelineDescriptor.vertexFunction = library.makeFunction(name: "planeVertexShader")
            pipelineDescriptor.fragmentFunction = library.makeFunction(name: "planeFragmentShaderColor")
            pipelineDescriptor.vertexDescriptor = createPlaneMetalVertexDescriptor()
            pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
            pipelineState = try metalDevice.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Unexpected error: \(error).")
        }
    }
    
    // Draw a textured quad.
    override func draw(in view: MTKView) {
        guard colorYContent.texture != nil && colorCbCrContent.texture != nil else {
            print("There's no content to display.")
            return
        }
        guard let commandBuffer = metalCommandQueue.makeCommandBuffer() else { return }
        guard let passDescriptor = view.currentRenderPassDescriptor else { return }
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else { return }
        let vertexData: [Float] = [  -1, -1, 1, 1,
                                     1, -1, 1, 0,
                                     -1, 1, 0, 1,
                                     1, 1, 0, 0]
        encoder.setVertexBytes(vertexData, length: vertexData.count * MemoryLayout<Float>.stride, index: 0)
        encoder.setFragmentTexture(colorYContent.texture, index: 0)
        encoder.setFragmentTexture(colorCbCrContent.texture, index: 1)
        encoder.setRenderPipelineState(pipelineState)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
    }
    
}

struct MetalTextureViewColor: UIViewRepresentable{
    var colorYContent: MetalTextureContent
    var colorCbCrContent: MetalTextureContent
    func makeCoordinator() -> CoordinatorColor {
        CoordinatorColor(colorYContent: colorYContent, colorCbCrContent: colorCbCrContent)
    }
    func makeUIView(context: UIViewRepresentableContext<MetalTextureViewColor>) -> MTKView {
        let mtkView = MTKView()
        mtkView.delegate = context.coordinator
        mtkView.backgroundColor = context.environment.colorScheme == .dark ? .black : .white
        context.coordinator.setupView(mtkView: mtkView)
        return mtkView
    }

    // `UIViewRepresentable` requires this implementation; however, the sample
    // app doesn't use it. Instead, `MTKView.delegate` handles display updates.
    func updateUIView(_ uiView: MTKView, context: UIViewRepresentableContext<MetalTextureViewColor>) {
        
    }
}
