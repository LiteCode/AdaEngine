//
//  Time.swift
//  
//
//  Created by v.prusakov on 10/9/21.
//


#if os(iOS) || os(tvOS)
import QuartzCore
#endif
#if os(macOS)
import Quartz
#endif
#if os(Android) || os(Linux)
import Glibc
#endif

public struct Time {
    public static var deltaTime: Double = 0
    
    public static var absolute: Double {
        #if os(iOS) || os(tvOS) || os(OSX) || os(watchOS)
        return CACurrentMediaTime()
        #else
        var t = timespec()
        clock_gettime(CLOCK_MONOTONIC, &t)

        return Double(t.tv_sec) + Double(t.tv_nsec) / Double(1.0e-9)
        #endif
    }
}