//
//  File.swift
//  
//
//  Created by v.prusakov on 5/7/22.
//

import AdaEngine

class ControlCameraComponent: ScriptComponent {
    
    var speed: Float = 4
    
    @RequiredComponent var circle: Camera
    
    override func update(_ deltaTime: TimeInterval) {
        if Input.isKeyPressed(.arrowUp) {
            self.circle.orthographicScale += 0.1
        }

        if Input.isKeyPressed(.arrowDown) {
            self.circle.orthographicScale -= 0.1
        }

        if Input.isKeyPressed(.w) {
            self.transform.position.y -= 0.1 * speed
        }

        if Input.isKeyPressed(.s) {
            self.transform.position.y += 0.1 * speed
        }

        if Input.isKeyPressed(.a) {
            self.transform.position.x -= 0.1 * speed
        }

        if Input.isKeyPressed(.d) {
            self.transform.position.x += 0.1 * speed
        }
        
    }
    
}

class ControlCircleComponent: ScriptComponent {
    
    var speed: Float = 2
    
    @RequiredComponent var circle: Circle2DComponent
    
    override func update(_ deltaTime: TimeInterval) {
        if Input.isKeyPressed(.arrowUp) {
            self.circle.thickness += 0.1
        }

        if Input.isKeyPressed(.arrowDown) {
            self.circle.thickness -= 0.1
        }

        if Input.isKeyPressed(.w) {
            self.transform.position.y += 0.1 * speed
        }

        if Input.isKeyPressed(.s) {
            self.transform.position.y -= 0.1 * speed
        }

        if Input.isKeyPressed(.a) {
            self.transform.position.x -= 0.1 * speed
        }

        if Input.isKeyPressed(.d) {
            self.transform.position.x += 0.1 * speed
        }
        
    }
    
}


class GameScene {
    func makeScene() -> Scene {
        let scene = Scene()

//        
//        let meshRenderer = MeshRenderer()
//        meshRenderer.materials = [BaseMaterial(diffuseColor: .red, metalic: 0)]
//        let mesh = Mesh.generateBox(extent: Vector3(1, 1, 1), segments: Vector3(1, 1, 1))
//
//        meshRenderer.mesh = mesh
//        boxEntity.components[MeshRenderer.self] = meshRenderer
//        scene.addEntity(boxEntity)
//
//        let trainEntity = Entity(name: "train")
//        let trainMeshRenderer = MeshRenderer()
//        let train = Bundle.module.url(forResource: "train", withExtension: "obj")!
//
//        trainMeshRenderer.mesh = Mesh.loadMesh(from: train)
//        trainMeshRenderer.materials = [BaseMaterial(diffuseColor: .orange, metalic: 1)]
//        trainEntity.components[MeshRenderer.self] = trainMeshRenderer
//        trainEntity.components[Transform.self]?.position = Vector3(2, 1, 1)
//        scene.addEntity(trainEntity)
//
            
        for i in 0..<1000 {
            let viewEntity = Entity(name: "Circle \(i)")
            
            let alpha: Float = Float.random(in: 0.3...1)
            
            viewEntity.components += Circle2DComponent(
                color: Color(
                    Float.random(in: 0..<255) / 255,
                    Float.random(in: 0..<255) / 255,
                    Float.random(in: 0..<255) / 255,
                    alpha
                ),
                thickness: 1
            )
            
            let scale: Float = Float.random(in: 0.3...1)
            
            var transform = Transform()
            transform.position = [Float.random(in: -5..<5), Float.random(in: -5..<5), 0]
            transform.scale = [scale, scale, scale]
            
            viewEntity.components += transform
            
            scene.addEntity(viewEntity)
        }
        
//        let viewEntity = Entity(name: "Circle")
//        viewEntity.components += Circle2DComponent(color: .blue, thickness: 1)
//        scene.addEntity(viewEntity)
//
//        let viewEntity1 = Entity(name: "Circle 1")
//        viewEntity1.components += Circle2DComponent(color: .yellow, thickness: 1)
//
//        var transform = Transform()
//        transform.position = [4, 4, 4]
//        transform.scale = [0.2, 0.2, 0.2]
//        viewEntity1.components += transform
//        viewEntity1.components += ControlCircleComponent()
//        scene.addEntity(viewEntity1)
        
        let userEntity = Entity(name: "camera")
        let camera = Camera()
        camera.projection = .orthographic
        camera.isPrimal = true
        userEntity.components += camera
        userEntity.components += ControlCameraComponent()
        scene.addEntity(userEntity)
        
//        let editorCamera = EditorCameraEntity()
//        let camera = editorCamera.components[Camera.self]!
//        camera.isPrimal = true
//        scene.addEntity(editorCamera)
//
//        scene.addSystem(EditorCameraSystem.selfa)
        
        return scene
    }
    
}
