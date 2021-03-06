//
//  SceneManager.swift
//  
//
//  Created by v.prusakov on 11/3/21.
//

public class SceneManager {
    
    public var currentScene: Scene?
    
    weak var window: Window?
    
    public let serializer: SceneSerializer
    
    // MARK: - Private
    
    internal init() {
        self.serializer = SceneSerializer()
    }
    
    func update(_ deltaTime: TimeInterval) {
        if self.currentScene?.isReady == false {
            self.currentScene?.ready()
        }
        
        self.currentScene?.update(deltaTime)
    }
    
    // MARK: - Public Methods
    
    public func presentScene(_ scene: Scene) {
        scene.sceneManager = self
        scene.window = self.window
        self.currentScene = scene
    }
    
}
