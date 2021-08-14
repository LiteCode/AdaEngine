// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

let applePlatforms: [Platform] = [.iOS, .macOS, .tvOS, .watchOS]

let package = Package(
    name: "AdaEngine",
    platforms: [
        .iOS(.v12),
        .macOS(.v10_15),
//        .watchOS(.v6),
//        .tvOS(.v13)
    ],
    products: [
        .library(
            name: "AdaEngine",
            type: .dynamic,
            targets: ["AdaEngine"]),
        
        .executable(
            name: "AdaEditor",
            targets: ["AdaEditor"]
        )
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        
        .target(
            name: "AdaEditor",
            dependencies: ["AdaEngine", "Vulkan", "CSDL2"]
        ),
        
        .target(
            name: "AdaEngine",
            dependencies: ["Vulkan"]
        ),
        
        // Just for test
        .systemLibrary(
                name: "CSDL2",
                pkgConfig: "sdl2",
                providers: [
                    .brew(["sdl2"]),
                    .apt(["libsdl2-dev"])
                ]
        ),
        
        .systemLibrary(
            name: "CVulkan",
            pkgConfig: "vulkan"
        ),
        
        .target(name: "Math"),
        
        .target(
            name: "Vulkan",
            dependencies: ["CVulkan"],
            cxxSettings: [
                // Apple
                .define("VK_USE_PLATFORM_IOS_MVK", .when(platforms: [.iOS])),
                .define("VK_USE_PLATFORM_MACOS_MVK", .when(platforms: [.macOS])),
                .define("VK_USE_PLATFORM_METAL_EXT", .when(platforms: applePlatforms)),
                
                // Android
                .define("VK_USE_PLATFORM_ANDROID_KHR", .when(platforms: [.android])),
                
                // Windows
                .define("VK_USE_PLATFORM_WIN32_KHR", .when(platforms: [.windows])),
            ]
        ),
        
        .testTarget(
            name: "AdaEngineTests",
            dependencies: ["AdaEngine"]),
    ],
    swiftLanguageVersions: [.v5]
)
