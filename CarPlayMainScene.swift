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
    private var musicTemplate: CarPlayMusic?
    
    // MARK: - CPTemplateApplicationScene delegate methods
    
    //CarPlayMainScene'e bu bildirimi dinlemek için bir observer ekleyelim: -->
    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(handlePlayingSongUpdate(_:)), name: .didUpdatePlayingSong, object: nil)
    }

    @objc private func handlePlayingSongUpdate(_ notification: Notification) {
        updatePlayingSong()
    }
    //CarPlayMainScene'e bu bildirimi dinlemek için bir observer ekleyelim: <--
    
    /// CarPlay was connected to device.
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didConnect interfaceController: CPInterfaceController) {
        // Store a reference to the interface controller so you can add and remove templates as the user interacts with your app
        self.interfaceController = interfaceController
        
        // Create the music template
        self.musicTemplate = CarPlayMusic(interface: self.interfaceController)
        guard let musicListTemplate = self.musicTemplate?.drawList() else { return }
        
        
        // Create additional templates
        let section2 = CPListSection(items: [])
        let moreMusicTemplate = CPListTemplate(title: "More Music", sections: [section2])
        moreMusicTemplate.tabImage = UIImage(systemName: "music.quarternote.3")!
        
        let section3 = CPListSection(items: [])
        let voiceTemplate = CPListTemplate(title: "Voice", sections: [section3])
        voiceTemplate.tabImage = UIImage(systemName: "music.mic")!
        
        // Combine templates into a tab bar
        let tabBarTemplate = CPTabBarTemplate(templates: [musicListTemplate, moreMusicTemplate, voiceTemplate])
        self.interfaceController?.setRootTemplate(tabBarTemplate, animated: true, completion: nil)
    }
    
    /// CarPlay was disconnected to device.
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        // Release the reference to the controller
        self.interfaceController = nil
        self.musicTemplate = nil
    }
    
    // MARK: - New Methods for Synchronization
    
    /// Updates the currently playing song in the CarPlay interface.
    func updatePlayingSong() {
        self.musicTemplate?.reloadTable()
    }
}
