//
//  CarPlayMusic.swift
//  CarPlayMusic
//
//  Created by Amerigo Mancino on 07/10/22.
//  Updated by System on 22/05/25.
//

import UIKit
import CarPlay

class CarPlayMusic: ReloadDelegate {

    private var interfaceController: CPInterfaceController?
    private var currentTemplate: CPListTemplate?
    
    // MARK: - Lifecycle methods
    
    init(interface: CPInterfaceController?) {
        self.interfaceController = interface
        MusicPlayerEngine.shared.reloadDelegate = self
    }
    
    // MARK: - Public methods
    
    public func drawList() -> CPListTemplate {
        let songs = MusicPlayerEngine.shared.getSongList()
        
        var items: [CPListItem] = []
        
        for (index, song) in songs.enumerated() {
            let item = CPListItem(
                text: song.title,
                detailText: song.author,
                image: resizeImageForCarPlay(song.image),
                accessoryImage: nil,
                accessoryType: .disclosureIndicator
            )
            
            item.handler = { [weak self] _ , completion in
                MusicPlayerEngine.shared.reloadDelegate?.reloadTable(with: index)
                MusicPlayerEngine.shared.play(id: index)
                
                guard self?.interfaceController?.topTemplate != CPNowPlayingTemplate.shared else {
                    completion()
                    return
                }
                
                self?.interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
                completion()
            }
            
            items.append(item)
        }
        
        let section = CPListSection(items: items, header: "Music (\(songs.count) songs)", sectionIndexTitle: nil)
        let template = CPListTemplate(title: "Music", sections: [section])
        template.tabImage = UIImage(systemName: "music.note")!
        
        self.currentTemplate = template
        return template
    }
    
    // MARK: - Private methods
    
    private func resizeImageForCarPlay(_ image: UIImage) -> UIImage {
        let targetSize = CGSize(width: 60, height: 60)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
    
    // MARK: - ReloadDelegate methods
    
    func reloadTable() {
        updateCarPlayList()
    }
    
    func reloadTable(with index: Int) {
        updateCarPlayList()
    }
    
    func reloadWithLast() {
        updateCarPlayList()
    }
    
    func songsDidUpdate() {
        updateCarPlayList()
    }
    
    private func updateCarPlayList() {
        guard let currentTemplate = self.currentTemplate else { return }
        
        let songs = MusicPlayerEngine.shared.getSongList()
        var items: [CPListItem] = []
        
        for (index, song) in songs.enumerated() {
            let item = CPListItem(
                text: song.title,
                detailText: song.author,
                image: resizeImageForCarPlay(song.image),
                accessoryImage: nil,
                accessoryType: .disclosureIndicator
            )
            
            item.handler = { [weak self] _ , completion in
                MusicPlayerEngine.shared.reloadDelegate?.reloadTable(with: index)
                MusicPlayerEngine.shared.play(id: index)
                
                guard self?.interfaceController?.topTemplate != CPNowPlayingTemplate.shared else {
                    completion()
                    return
                }
                
                self?.interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
                completion()
            }
            
            items.append(item)
        }
        
        let section = CPListSection(items: items, header: "Music (\(songs.count) songs)", sectionIndexTitle: nil)
        currentTemplate.updateSections([section])
    }
}
