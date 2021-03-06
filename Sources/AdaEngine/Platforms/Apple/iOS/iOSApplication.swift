//
//  iOSApplication.swift
//  
//
//  Created by v.prusakov on 5/24/22.
//

#if os(iOS) || os(tvOS) || os(watchOS)
import UIKit

// swiftlint:disable type_name
final public class iOSApplication: Application {
    
    let argc: Int32
    let argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>
     
    required init(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) throws {
        self.argv = argv
        self.argc = argc
        
        try super.init(argc: argc, argv: argv)
    }
    
    override func run() throws {
        let exitCode = UIApplicationMain(
            argc,
            argv,
            NSStringFromClass(AdaApplication.self),
            NSStringFromClass(iOSAppDelegate.self)
        )
        
        if exitCode != EXIT_SUCCESS {
            throw NSError(domain: "", code: Int(exitCode))
        }
    }
    
    @discardableResult
    override func openURL(_ url: URL) -> Bool {
        UIApplication.shared.open(url)
        return true
    }
}

class AdaApplication: UIApplication { }

// swiftlint:enable type_name

#endif
