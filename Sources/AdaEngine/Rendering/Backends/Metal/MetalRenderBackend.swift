//
//  MetalRenderBackend.swift
//  
//
//  Created by v.prusakov on 10/20/21.
//

#if canImport(Metal)
import Metal
import ModelIO
import MetalKit
import OrderedCollections

enum BufferIndex {
    static let baseUniform = 1
    static let material = 2
}

enum IndexBufferFormat {
    case uInt32
    case uInt16
}

class MetalRenderBackend: RenderBackend {
    
    var shaders: ResourceHashMap<Shader> = [:]
    
    let context: Context
    var currentFrameIndex: Int = 0
    var currentBuffers: [MTLCommandBuffer] = []
    var maxFramesInFlight = 3
    
    var resourceMap: ResourceHashMap<MTLResource> = [:]
    var vertexBuffers: ResourceHashMap<Buffer> = [:]
    var indexBuffers: ResourceHashMap<Buffer> = [:]
    var uniformSet: ResourceHashMap<Uniform> = [:]
    
    var indexArrays: ResourceHashMap<IndexArray> = [:]
    var vertexArrays: ResourceHashMap<VertexArray> = [:]
    
    var renderPipelineStateMap: ResourceHashMap<MTLRenderPipelineState> = [:]
    
    var depthState: MTLDepthStencilState!
    
    var inFlightSemaphore: DispatchSemaphore!
    
    init(appName: String) {
        self.context = Context()
        
        // TEST
        let depthStateDescriptor = MTLDepthStencilDescriptor()
        depthStateDescriptor.depthCompareFunction = MTLCompareFunction.less
        depthStateDescriptor.isDepthWriteEnabled = true
        
        self.depthState = self.context.physicalDevice.makeDepthStencilState(descriptor:depthStateDescriptor)
    }
    
    func createWindow(_ windowId: Window.ID, for view: RenderView, size: Size) throws {
        let mtlView = (view as! MetalView)
        try self.context.createRenderWindow(with: windowId, view: mtlView, size: size)
        
        self.inFlightSemaphore = DispatchSemaphore(value: self.maxFramesInFlight)
        
//        for _ in 0 ..< maxFramesInFlight {
//            let cmdBuffer = self.context.commandQueue.makeCommandBuffer()!
//            self.currentBuffers.append(cmdBuffer)
//        }
    }
    
    func resizeWindow(_ windowId: Window.ID, newSize: Size) throws {
        self.context.updateSizeForRenderWindow(windowId, size: newSize)
    }
    
    func destroyWindow(_ windowId: Window.ID) throws {
        guard let window = self.context.windows[windowId] else {
            return
        }
        
        guard let draw = self.drawList.first(where: { $0.value.window === window }) else {
            return
        }
        
        self.drawList[draw.key] = nil
        
        self.context.destroyWindow(by: windowId)
    }
    
    func beginFrame() throws {
//        self.inFlightSemaphore.wait()
        
        for (_, window) in self.context.windows {
            window.commandBuffer = window.commandQueue.makeCommandBuffer()
        }
    }
    
    func endFrame() throws {
//        self.inFlightSemaphore.wait()
//        self.currentFrameIndex = (currentFrameIndex + 1) % maxFramesInFlight
//        let currentBuffer = self.currentBuffers[self.currentFrameIndex]
        
        for (_, window) in self.context.windows {
            guard let currentDrawable = window.view?.currentDrawable else {
                return
            }
            
            window.commandBuffer?.present(currentDrawable)
            
            window.commandBuffer?.commit()
            
            window.commandBuffer?.waitUntilCompleted()
        }
    }
    
    func setClearColor(_ color: Color, forWindow windowId: Window.ID) {
        guard let window = self.context.windows[windowId] else {
            return
        }
        
        window.view?.clearColor = MTLClearColor(red: Double(color.red), green: Double(color.green), blue: Double(color.blue), alpha: Double(color.alpha))
    }
    
    func makeShader(from descriptor: ShaderDescriptor) -> RID {
        do {
            let url = Bundle.current.url(forResource: descriptor.shaderName, withExtension: "metallib")!
            let library = try self.context.physicalDevice.makeLibrary(URL: url)
            let vertexFunc = library.makeFunction(name: descriptor.vertexFunction)!
            let fragmentFunc = library.makeFunction(name: descriptor.fragmentFunction)!
            
            let shader = Shader(binary: library, vertexFunction: vertexFunc, fragmentFunction: fragmentFunc)
            
            for (index, attribute) in descriptor.vertexDescriptor.attributes.enumerated() {
                shader.vertexDescriptor.attributes[index].offset = attribute.offset
                shader.vertexDescriptor.attributes[index].bufferIndex = attribute.bufferIndex
                shader.vertexDescriptor.attributes[index].format = attribute.format.metalFormat
            }
            
            for (index, layout) in descriptor.vertexDescriptor.layouts.enumerated() {
                shader.vertexDescriptor.layouts[index].stride = layout.stride
            }
            
            return self.shaders.setValue(shader)
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    func makePipelineState(for shader: RID) -> RID {
        guard let shader = self.shaders[shader] else {
            fatalError("Shader not found")
        }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = shader.vertexFunction
        pipelineDescriptor.fragmentFunction = shader.fragmentFunction
        pipelineDescriptor.vertexDescriptor = shader.vertexDescriptor
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float_stencil8
        pipelineDescriptor.stencilAttachmentPixelFormat = .depth32Float_stencil8
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        
        do {
            let state = try self.context.physicalDevice.makeRenderPipelineState(descriptor: pipelineDescriptor)
            return self.renderPipelineStateMap.setValue(state)
        } catch {
            fatalError(error.localizedDescription)
        }
        
    }
    
    // MARK: - Buffers
    
    func makeIndexArray(indexBuffer ibRid: RID, indexOffset: Int, indexCount: Int) -> RID {
        guard let indexBuffer = self.indexBuffers[ibRid] else {
            fatalError("Can't find index buffer for rid - \(ibRid)")
        }
        
        let array = IndexArray(
            buffer: ibRid,
            format: indexBuffer.indexFormat!,
            offset: indexOffset,
            indecies: indexCount
        )
        
        return self.indexArrays.setValue(array)
    }
    
    func makeVertexArray(vertexBuffers: [RID], vertexCount: Int) -> RID {
        let array = VertexArray(buffers: vertexBuffers, vertexCount: vertexCount)
        return self.vertexArrays.setValue(array)
    }
    
    func makeIndexBuffer(offset: Int, index: Int, format: IndexBufferFormat, bytes: UnsafeRawPointer?, length: Int) -> RID {
        let buffer = self.context.physicalDevice.makeBuffer(length: length, options: .storageModeShared)!
        
        if let bytes = bytes {
            buffer.contents().copyMemory(from: bytes, byteCount: length)
        }
        
        let indexBuffer = Buffer(buffer: buffer, offset: offset, index: index, indexFormat: format)
        return self.indexBuffers.setValue(indexBuffer)
    }
    
    func makeVertexBuffer(offset: Int, index: Int, bytes: UnsafeRawPointer?, length: Int) -> RID {
        let buffer = self.context.physicalDevice.makeBuffer(length: length, options: .storageModeShared)!
        
        if let bytes = bytes {
            buffer.contents().copyMemory(from: bytes, byteCount: length)
        }
        
        let indexBuffer = Buffer(buffer: buffer, offset: offset, index: index)
        return self.vertexBuffers.setValue(indexBuffer)
    }
    
    func setVertexBufferData(_ vertexBuffer: RID, bytes: UnsafeRawPointer, length: Int) {
        guard let buffer = self.vertexBuffers[vertexBuffer] else {
            assertionFailure("Vertex buffer not found")
            return
        }
        
        buffer.buffer.contents().copyMemory(from: bytes, byteCount: length)
    }
    
    func setIndexBufferData(_ indexBuffer: RID, bytes: UnsafeRawPointer, length: Int) {
        guard let buffer = self.indexBuffers[indexBuffer] else {
            assertionFailure("Vertex buffer not found")
            return
        }
        
        buffer.buffer.contents().copyMemory(from: bytes, byteCount: length)
    }
    
    func makeBuffer(length: Int, options: ResourceOptions) -> RID {
        let buffer = self.context.physicalDevice.makeBuffer(length: length, options: options.metal)!
        return self.resourceMap.setValue(buffer)
    }
    
    func makeBuffer(bytes: UnsafeRawPointer, length: Int, options: ResourceOptions) -> RID {
        let buffer = self.context.physicalDevice.makeBuffer(bytes: bytes, length: length, options: options.metal)!
        return self.resourceMap.setValue(buffer)
    }
    
    func getBuffer(for rid: RID) -> RenderBuffer {
        guard let buffer = self.resourceMap.get(rid) as? MTLBuffer else {
            fatalError("Can't find buffer for rid \(rid)")
        }
        
        return MetalBuffer(buffer)
    }
    
    var drawList: ResourceHashMap<Draw> = [:]
}

// MARK: - Drawings

extension MetalRenderBackend {
    
    struct Draw {
        var window: Context.RenderWindow
        var debugName: String?
        let commandBuffer: MTLCommandBuffer
        let renderPassDescriptor: MTLRenderPassDescriptor
        var vertexArray: RID?
        var indexArray: RID?
        var uniformSet: [Int: RID] = [:]
        var renderState: MTLRenderPipelineState?
        var lineWidth: Float?
    }
    
    struct Buffer {
        var buffer: MTLBuffer
        var offset: Int
        var index: Int
        
        /// Only for index buffer
        var indexFormat: IndexBufferFormat?
    }
    
    struct Uniform {
        var buffer: MTLBuffer
        var offset: Int
    }
    
    struct IndexArray {
        var buffer: RID
        var format: IndexBufferFormat
        var offset: Int = 0
        var indecies: Int = 0
    }
    
    struct VertexArray {
        var buffers: [RID] = []
        var vertexCount: Int = 0
    }
    
    struct Shader {
        let binary: MTLLibrary
        let vertexFunction: MTLFunction
        let fragmentFunction: MTLFunction
        
        var vertexDescriptor: MTLVertexDescriptor = MTLVertexDescriptor()
    }
    
    func beginDraw(for window: Window.ID) -> RID {
        guard let window = self.context.windows[window] else {
            fatalError("Render Window not exists.")
        }
        
        guard let renderPass = window.view?.currentRenderPassDescriptor else {
            fatalError("Can't get render pass descriptor")
        }
        
        let draw = Draw(
            window: window,
            commandBuffer: window.commandBuffer!,
            renderPassDescriptor: renderPass
        )
        
        return self.drawList.setValue(draw)
    }
    
    func bindDebugName(name: String, forDraw drawId: RID) {
        self.drawList[drawId]?.debugName = name
    }
    
    func bindLineWidth(_ width: Float, forDraw drawId: RID) {
        self.drawList[drawId]?.lineWidth = width
    }
    
    func bindRenderState(_ drawRid: RID, renderPassId: RID) {
        var draw = self.drawList[drawRid]
        assert(draw != nil, "Draw is not exists")
        
        let renderState = self.renderPipelineStateMap[renderPassId]
        draw?.renderState = renderState
        
        self.drawList[drawRid] = draw
    }
    
    func bindUniformSet(_ drawRid: RID, uniformSet: RID, at index: Int) {
        var draw = self.drawList[drawRid]
        assert(draw != nil, "Draw is not exists")
        draw?.uniformSet[index] = uniformSet
        self.drawList[drawRid] = draw
    }
    
    func bindVertexArray(_ drawRid: RID, vertexArray: RID) {
        var draw = self.drawList[drawRid]
        assert(draw != nil, "Draw is not exists")
        draw?.vertexArray = vertexArray
        self.drawList[drawRid] = draw
    }
    
    func bindIndexArray(_ drawRid: RID, indexArray: RID) {
        var draw = self.drawList[drawRid]
        assert(draw != nil, "Draw is not exists")
        draw?.indexArray = indexArray
        self.drawList[drawRid] = draw
    }
    
    func makeUniform<T>(_ uniformType: T.Type, count: Int, offset: Int, options: ResourceOptions) -> RID {
        let buffer = self.context.physicalDevice.makeBuffer(
            length: MemoryLayout<T>.size * count,
            options: options.metal
        )!
        
        let uniform = Uniform(
            buffer: buffer,
            offset: offset
        )
        
        return self.uniformSet.setValue(uniform)
    }
    
    func updateUniform<T>(_ rid: RID, value: T, count: Int) {
        guard let uniform = self.uniformSet.get(rid) else {
            fatalError("Can't find uniform for rid \(rid)")
        }
        var temp = value
        uniform.buffer.contents().copyMemory(from: &temp, byteCount: MemoryLayout.stride(ofValue: value) * count)
    }
    
    func removeUniform(_ rid: RID) {
        self.uniformSet.setValue(nil, forKey: rid)
    }
    
    func createTexture(size: Size?) -> RID {
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type2D
        descriptor.height = Int(size?.height ?? 1)
        descriptor.width = Int(size?.width ?? 1)
        guard let texture = self.context.physicalDevice.makeTexture(descriptor: descriptor) else {
            fatalError()
        }
        return self.resourceMap.setValue(texture)
    }
    
    func setLineWidth(_ lineWidth: Float, forDraw drawRid: RID) {
        guard var draw = self.drawList[drawRid] else {
            fatalError("Draw list not found")
        }
        
        draw.lineWidth = lineWidth
        self.drawList[drawRid] = draw
    }
    
    // swiftlint:disable:next cyclomatic_complexity
    func draw(_ drawRid: RID, indexCount: Int, instancesCount: Int) {
        guard let draw = self.drawList[drawRid] else {
            fatalError("Draw not found")
        }
        
        guard let encoder = draw.commandBuffer.makeRenderCommandEncoder(descriptor: draw.renderPassDescriptor) else {
            assertionFailure("Can't create render command encoder")
            return
        }
        
        if let name = draw.debugName {
            encoder.label = name
        }
        
        // Should be in draw settings
        encoder.setCullMode(.back)

        encoder.setFrontFacing(.counterClockwise)
        
        if let renderState = draw.renderState {
            encoder.setRenderPipelineState(renderState)
        }
        
//        encoder.setDepthStencilState(depthState)
        
        guard let iaRid = draw.indexArray, let indexArray = self.indexArrays[iaRid] else {
            fatalError("can't draw without index array")
        }
        
        if let vaRid = draw.vertexArray, let vertexArray = self.vertexArrays[vaRid] {
            for vertexRid in vertexArray.buffers {
                guard let vertexBuffer = self.vertexBuffers[vertexRid] else {
                    continue
                }
                
                encoder.setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, index: vertexBuffer.index)
            }
        }
        
        for (index, uniRid) in draw.uniformSet {
            let uniform = self.uniformSet[uniRid]!
            encoder.setVertexBuffer(uniform.buffer, offset: uniform.offset, index: index)
        }
        
        guard let indexBuffer = self.indexBuffers[indexArray.buffer] else {
            fatalError("Can't get index buffer for draw")
        }
        
//        encoder.setTriangleFillMode(.lines)
        
        encoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: indexCount,
            indexType: indexArray.format == .uInt32 ? .uint32 : .uint16,
            indexBuffer: indexBuffer.buffer,
            indexBufferOffset: indexArray.offset,
            instanceCount: instancesCount
        )
        
        encoder.endEncoding()
    }
    
    func drawEnd(_ drawId: RID) {
        self.drawList[drawId] = nil
    }
}

#endif

// FIXME: Think about it

extension Bundle {
    static var current: Bundle {
#if SWIFT_PACKAGE
        return Bundle.module
#else
        return Bundle.init(for: BundleToken.self)
#endif
    }
}

#if !SWIFT_PACKAGE
class BundleToken {}
#endif
