//
//  File.swift
//  
//
//  Created by v.prusakov on 8/15/21.
//

import Vulkan
@_implementationOnly import CVulkan
import Math

public let NotFound = Int.max

struct QueueFamilyIndices {
    let graphicsIndex: Int
    let presentationIndex: Int
    let isSeparate: Bool
}

public class RenderContext {
    
    public private(set) var vulkan: Vulkan?
    private var queueFamilyIndicies: QueueFamilyIndices!
    private var device: Device!
    private var surface: Surface!
    private var gpu: PhysicalDevice!
    
    private var graphicsQueue: VkQueue?
    private var presentationQueue: VkQueue?
    
    private var imageViews: [ImageView] = []
    private var imageFormat: VkFormat!
    private var colorSpace: VkColorSpaceKHR!
    
    private var renderPass: RenderPass!

    public let vulkanVersion: UInt32
    
    public required init() {
        self.vulkanVersion = Self.determineVulkanVersion()
    }
    
    public func initialize(with appName: String) throws {
        let vulkan = try self.createInstance(appName: appName)
        self.vulkan = vulkan
        
        let gpu = try self.createGPU(vulkan: vulkan)
        self.gpu = gpu
    }
    
    public func flush() {
        
    }
    
    // MARK: - Private
    
    private func createInstance(appName: String) throws -> Vulkan {
        let extensions = try Self.provideExtensions()
        
        let appInfo = VkApplicationInfo(
            sType: VK_STRUCTURE_TYPE_APPLICATION_INFO,
            pNext: nil,
            pApplicationName: appName,
            applicationVersion: 0,
            pEngineName: "Ada Engine",
            engineVersion: 0,
            apiVersion: vulkanVersion
        )
        
        let info = InstanceCreateInfo(
            applicationInfo: appInfo,
            // TODO: Add enabledLayers flag to manage layers
            enabledLayerNames: ["VK_LAYER_KHRONOS_validation"],
            enabledExtensionNames: extensions.map(\.extensionName)
        )
        
        return try Vulkan(info: info)
    }
    
    private func createWindow(surface: Surface, size: Vector2i) throws {
        if self.graphicsQueue == nil && self.presentationQueue == nil {
            try self.createQueues(gpu: self.gpu, surface: surface)
        }
        
        self.surface = surface
        
        try self.createSwapchain(for: size)
    }
    
    private func createGPU(vulkan: Vulkan) throws -> PhysicalDevice {
        let devices = try vulkan.physicalDevices()
        
        if devices.isEmpty {
            throw AdaError("Could not find any compitable devices for Vulkan. Do you have a compitable Vulkan devices?")
        }
        
        let preferredGPU =
            devices.first(where: { $0.properties.deviceType == VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU }) ?? devices[0]
        
        return preferredGPU
    }
    
    private func createQueues(gpu: PhysicalDevice, surface: Surface) throws {
        let queues = gpu.getQueueFamily()
        
        if queues.isEmpty {
            throw AdaError("Could not find any queues for selected GPU.")
        }
        
        let supporterPresentationQueues = try queues.map { try gpu.supportSurface(surface, queueFamily: $0) }
        
        var presentationQueueIndex = NotFound
        var graphicsQueueIndex = NotFound
        
        for (index, queue) in queues.enumerated() {
            if queue.queueFlags.contains(.graphicsBit) && graphicsQueueIndex == NotFound {
                graphicsQueueIndex = index
            }
            
            if supporterPresentationQueues[index] == true {
                graphicsQueueIndex = index
                presentationQueueIndex = index
                break
            }
        }
        
        // We dont find presentation queue
        if
            presentationQueueIndex == NotFound,
            let index = supporterPresentationQueues.firstIndex(where: { $0 == true })
        {
            presentationQueueIndex = index
        }
        
        assert(presentationQueueIndex != NotFound || graphicsQueueIndex != NotFound, "Presentation and/or graphics queues not found")
        
        let indecies = QueueFamilyIndices(
            graphicsIndex: graphicsQueueIndex,
            presentationIndex: presentationQueueIndex,
            isSeparate: graphicsQueueIndex != presentationQueueIndex
        )
        
        self.queueFamilyIndicies = indecies
        
        let device = try self.createDevice(for: gpu, surface: surface, queueIndecies: indecies)
        self.device = device
        
        self.graphicsQueue = device.getQueue(at: indecies.graphicsIndex)
        self.presentationQueue = indecies.isSeparate ? device.getQueue(at: indecies.presentationIndex) : self.graphicsQueue
    }
    
    private func createSwapchain(for size: Vector2i) throws {
        let surfaceCapabilities = try self.gpu.surfaceCapabilities(for: self.surface)
        
        var imageFormat = VK_FORMAT_B8G8R8A8_UNORM
        var colorSpace: VkColorSpaceKHR
        
        let formats = try self.gpu.surfaceFormats(for: self.surface)
        
        if formats.isEmpty {
            throw AdaError("Surface formats not found")
        }
        
        if formats.count == 1 && formats[0].format == VK_FORMAT_UNDEFINED {
            imageFormat = VK_FORMAT_B8G8R8A8_UNORM
            colorSpace = formats[0].colorSpace
        } else {
            let availableFormats = [VK_FORMAT_B8G8R8A8_UNORM, VK_FORMAT_R8G8B8A8_UNORM]
            
            guard let preferredFormat = formats.first(where: { availableFormats.contains($0.format) }) else {
                throw AdaError("Not found supported format")
            }
            
            colorSpace = preferredFormat.colorSpace
            imageFormat = preferredFormat.format
        }
        
        let extent: VkExtent2D
        
        if surfaceCapabilities.currentExtent.width != UInt32.max {
            extent = surfaceCapabilities.currentExtent
        } else {
            extent = VkExtent2D(width: UInt32(size.x), height: UInt32(size.y))
        }
        
        let swapchainPresentMode = VK_PRESENT_MODE_FIFO_KHR
        
        let imageCount = surfaceCapabilities.minImageCount + 1 // TODO: Change it for latter
        
        let preTransform: VkSurfaceTransformFlagsKHR
        if (surfaceCapabilities.supportedTransforms & VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR.rawValue) == true {
            preTransform = VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR.rawValue
        } else {
            preTransform = surfaceCapabilities.supportedTransforms
        }
        
        let availableCompositionAlpha = [VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
                                         VK_COMPOSITE_ALPHA_POST_MULTIPLIED_BIT_KHR,
                                         VK_COMPOSITE_ALPHA_INHERIT_BIT_KHR]
        
        let compositionAlpha = availableCompositionAlpha.first {
            (surfaceCapabilities.supportedCompositeAlpha & $0.rawValue) == true
        } ?? VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR
        
        let swapchainInfo = VkSwapchainCreateInfoKHR(
            sType: VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
            pNext: nil,
            flags: 0,
            surface: surface.rawPointer,
            minImageCount: imageCount,
            imageFormat: imageFormat,
            imageColorSpace: colorSpace,
            imageExtent: extent,
            imageArrayLayers: 1,
            imageUsage: VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT.rawValue,
            imageSharingMode: VK_SHARING_MODE_EXCLUSIVE,
            queueFamilyIndexCount: 0,
            pQueueFamilyIndices: nil,
            preTransform: VkSurfaceTransformFlagBitsKHR(rawValue: preTransform),
            compositeAlpha: compositionAlpha,
            presentMode: swapchainPresentMode,
            clipped: true,
            oldSwapchain: nil)
        
        let swapchain = try Swapchain(device: self.device, createInfo: swapchainInfo)
        
        self.imageFormat = imageFormat
        self.colorSpace = colorSpace
        
        let images = try swapchain.getImages()
        
        self.imageViews.removeAll()
        var imageViews = [ImageView]()
        for image in images {
            let info = VkImageViewCreateInfo(
                sType: VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
                pNext: nil,
                flags: 0,
                image: image,
                viewType: VK_IMAGE_VIEW_TYPE_2D,
                format: imageFormat,
                components: VkComponentMapping(
                    r: VK_COMPONENT_SWIZZLE_R,
                    g: VK_COMPONENT_SWIZZLE_G,
                    b: VK_COMPONENT_SWIZZLE_B,
                    a: VK_COMPONENT_SWIZZLE_A
                ),
                subresourceRange: VkImageSubresourceRange(
                    aspectMask: VK_IMAGE_ASPECT_COLOR_BIT.rawValue,
                    baseMipLevel: 0,
                    levelCount: 1,
                    baseArrayLayer: 0,
                    layerCount: 1
                )
            )
            
            let imageView = try ImageView(device: self.device, info: info)
            imageViews.append(imageView)
        }
        
        self.imageViews = imageViews
        
        try self.createRenderPass(size: size)
        try self.createFramebuffer(size: size)
    }
    
    private func createDevice(for gpu: PhysicalDevice, surface: Surface, queueIndecies: QueueFamilyIndices) throws -> Device {
        
        let deviceExtensions = try gpu.getExtensions()
        var availableExtenstions = [ExtensionProperties]()
        
        for ext in deviceExtensions {
            if ext.extensionName == VK_KHR_SWAPCHAIN_EXTENSION_NAME {
                availableExtenstions.append(ext)
            }
        }
        
        let properties: [Float] = [0.0]
        
        var queueCreateInfos = [DeviceQueueCreateInfo]()
        queueCreateInfos.append(
            DeviceQueueCreateInfo(
                queueFamilyIndex: UInt32(queueIndecies.graphicsIndex),
                flags: .none,
                queuePriorities: properties
            )
        )
        
        if queueIndecies.isSeparate {
            queueCreateInfos.append(
                DeviceQueueCreateInfo(
                    queueFamilyIndex: UInt32(queueIndecies.presentationIndex),
                    flags: .none,
                    queuePriorities: properties
                )
            )
        }
        
        var features = gpu.features
        features.robustBufferAccess = false
        
        let info = DeviceCreateInfo(
            enabledExtensions: availableExtenstions.map(\.extensionName),
            layers: [],
            queueCreateInfo: queueCreateInfos,
            enabledFeatures: features
        )
        
        return try Device(physicalDevice: gpu, createInfo: info)
    }
    
    private func createRenderPass(size: Vector2i) throws {
        var attachment = VkAttachmentDescription(
            flags: 0,
            format: self.imageFormat,
            samples: VK_SAMPLE_COUNT_1_BIT,
            loadOp: VK_ATTACHMENT_LOAD_OP_CLEAR,
            storeOp: VK_ATTACHMENT_STORE_OP_STORE,
            stencilLoadOp: VK_ATTACHMENT_LOAD_OP_DONT_CARE,
            stencilStoreOp: VK_ATTACHMENT_STORE_OP_DONT_CARE,
            initialLayout: VK_IMAGE_LAYOUT_UNDEFINED,
            finalLayout: VK_IMAGE_LAYOUT_PRESENT_SRC_KHR
        )
        
        var colorDescription = VkAttachmentReference(attachment: 0, layout: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL)
        
        var subpass = VkSubpassDescription(
            flags: 0,
            pipelineBindPoint: VK_PIPELINE_BIND_POINT_GRAPHICS,
            inputAttachmentCount: 0,
            pInputAttachments: nil,
            colorAttachmentCount: 1,
            pColorAttachments: &colorDescription,
            pResolveAttachments: nil,
            pDepthStencilAttachment: nil,
            preserveAttachmentCount: 0,
            pPreserveAttachments: nil
        )
        
        let renderPassCreateInfo = VkRenderPassCreateInfo(
            sType: VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
            pNext: nil,
            flags: 0,
            attachmentCount: 1,
            pAttachments:&attachment,
            subpassCount: 1,
            pSubpasses: &subpass,
            dependencyCount: 0,
            pDependencies: nil
        )
        
        let renderPass = try RenderPass(device: self.device, createInfo: renderPassCreateInfo)
        self.renderPass = renderPass
    }
    
    private func createFramebuffer(size: Vector2i) throws {
        
        for imageView in imageViews {
            
            var attachment = imageView.rawPointer
            
            let createInfo = VkFramebufferCreateInfo(
                sType: VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
                pNext: nil,
                flags: 0,
                renderPass: self.renderPass.rawPointer,
                attachmentCount: 1,
                pAttachments: &attachment,
                width: UInt32(size.x),
                height: UInt32(size.y),
                layers: 1
            )
            
            let framebuffer = try Framebuffer(device: self.device, createInfo: createInfo)
            print(framebuffer)
        }

    }
    
}

extension RenderContext {
    
    private static func determineVulkanVersion() -> UInt32 {
        var version: UInt32 = UInt32.max
        let result = vkEnumerateInstanceVersion(&version)
        
        if result != VK_SUCCESS {
            fatalError("Vulkan API got error when trying get sdk version")
        }
        
        return version
    }
    
    private static func provideExtensions() throws -> [ExtensionProperties] {
        let extensions = try Vulkan.getExtensions()
        
        var availableExtenstions = [ExtensionProperties]()
        var isSurfaceFound = false
        var isPlatformExtFound = false
        
        for ext in extensions {
            if ext.extensionName == VK_KHR_SURFACE_EXTENSION_NAME {
                isSurfaceFound = true
                availableExtenstions.append(ext)
            }
            
            if ext.extensionName == Self.platformSpecificSurfaceExtensionName {
                availableExtenstions.append(ext)
                isPlatformExtFound = true
            }
            
            if ext.extensionName == VK_KHR_GET_PHYSICAL_DEVICE_PROPERTIES_2_EXTENSION_NAME {
                availableExtenstions.append(ext)
            }
            
            if ext.extensionName == VK_EXT_DEBUG_UTILS_EXTENSION_NAME {
                availableExtenstions.append(ext)
            }
        }
        
        assert(isSurfaceFound, "No surface extension found, is a driver installed?")
        assert(isPlatformExtFound, "No surface extension found, is a driver installed?")
        
        return availableExtenstions
    }
}

#if os(macOS) || os(iOS) || os(tvOS)

import MetalKit

public extension RenderContext {
    func createWindow(for view: MTKView, size: Vector2i) throws {
        precondition(self.vulkan != nil, "Vulkan instance not created.")
        
        let surface = try Surface(vulkan: self.vulkan!, view: view)
        try self.createWindow(surface: surface, size: size)
    }
}

#endif

extension RenderContext {
    // TODO: Change to constants
    static var platformSpecificSurfaceExtensionName: String {
        #if os(macOS)
        return "VK_MVK_macos_surface"
        #elseif os(iOS) || os(tvOS)
        return "VK_MVK_ios_surface"
        #elseif os(Windows)
        return "VK_MVK_ios_surface"
        #elseif os(Linux)
        return "VK_MVK_ios_surface"
        #else
        return "NotFound"
        #endif
    }
}

public struct AdaError: LocalizedError {
    let message: String
    
    public init(_ message: String) {
        self.message = message
    }
    
    public var errorDescription: String? {
        return message
    }
}
