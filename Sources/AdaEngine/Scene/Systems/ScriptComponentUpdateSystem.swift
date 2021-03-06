//
//  ScriptComponentUpdateSystem.swift
//  
//
//  Created by v.prusakov on 5/7/22.
//

struct ScriptComponentUpdateSystem: System {
    
    init(scene: Scene) { }
    
    func update(context: UpdateContext) {
        let guiRenderContext = GUIRenderContext(window: context.scene.window!.id)
        
        context.scene.world.scripts.values.forEach { component in
            
            // Initialize component
            if !component.isAwaked {
                component.ready()
                component.isAwaked = true
            }
            
            component.update(context.deltaTime)
            
            guiRenderContext.beginDraw(in: Rect(origin: .zero, size: context.scene.viewportSize))
            
            component.updateGUI(context.deltaTime, context: guiRenderContext)
            
            guiRenderContext.commitDraw()
        }
    }
}
