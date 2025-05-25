//
//  CarPlayMainScene.swift
//  CarPlayMusic
//
//  Created by Amerigo Mancino on 03/08/22.
//

import CarPlay

class CarPlayMainScene: UIResponder, CPTemplateApplicationSceneDelegate {
    
    /// Interface controller.
    private var interfaceController: CPInterfaceController?
    
    // MARK: - CPTemplateApplicationScene delegate methods
    
    /// CarPlay was connected to device.
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didConnect interfaceController: CPInterfaceController) {
        // Store a reference to the interface controller so you can add and remove templates as the user interacts with your app
        self.interfaceController = interfaceController
        
        // Create a template and set it as the root
        
        let template1 = CarPlayMusic(interface: self.interfaceController)
        
        let section2 = CPListSection(items: [])
        let template2 = CPListTemplate(title: "More music", sections: [section2])
        template2.tabImage = UIImage(systemName: "music.quarternote.3")!
        
        let section3 = CPListSection(items: [])
        let template3 = CPListTemplate(title: "Voice", sections: [section3])
        template3.tabImage = UIImage(systemName: "music.mic")!

        let tabBartTemplate = CPTabBarTemplate(templates: [template1.drawList(), template2, template3])
        self.interfaceController?.setRootTemplate(tabBartTemplate, animated: true, completion: nil)
        
    }
    
    /// CarPlay was disconnected to device.
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        // Release the reference to the controller
        self.interfaceController = nil
    }
}
