//
//  RenderBuffer.swift
//  
//
//  Created by v.prusakov on 11/4/21.
//

public protocol RenderBuffer {
    var length: Int { get }
    
    func contents() -> UnsafeMutableRawPointer
    
    func copy(bytes: UnsafeRawPointer, length: Int)
    
    func get<T>() -> T?
}

public struct ResourceOptions: OptionSet {
    public let rawValue: UInt
    
    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }
    
    public static let storagePrivate = ResourceOptions(rawValue: 1 << 0)
    
    public static let storageShared = ResourceOptions(rawValue: 1 << 1)
}

#if canImport(Metal)

extension ResourceOptions {
    var metal: MTLResourceOptions {
        
        var options: MTLResourceOptions = []
        
        if self.contains(.storagePrivate) {
            options.insert(.storageModePrivate)
        }
        
        if self.contains(.storageShared) {
            options.insert(.storageModeShared)
        }
        
        return options
    }
}

#endif

#if canImport(Metal)
import Metal

public class MetalBuffer: RenderBuffer {
    let base: MTLBuffer
    
    init(_ buffer: MTLBuffer) {
        self.base = buffer
    }
    
    public var length: Int { return base.length }
    
    public func contents() -> UnsafeMutableRawPointer { return self.base.contents() }
    
    public func copy(bytes: UnsafeRawPointer, length: Int) {
        self.base.contents().copyMemory(from: bytes, byteCount: length)
    }
    
    public func get<T>() -> T? {
        return self.base as? T
    }
    
}
#endif
