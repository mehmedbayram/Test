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
        let currentSongIndex = MusicPlayerEngine.shared.getCurrentSongIndex()
        
        var items: [CPListItem] = []
        
        for (index, song) in songs.enumerated() {
            let isCurrentSong = (index == currentSongIndex && MusicPlayerEngine.shared.isPlaying())
            
            let item = CPListItem(
                text: song.title,
                detailText: song.author,
                image: resizeImageForCarPlay(song.image),
                accessoryImage: isCurrentSong ? createPlayingIcon() : nil,
                accessoryType: .none
            )
            
            // Yeni davranış: Şarkıyı çal ve highlight yap, başka ekrana geçiş yapma
            item.handler = { [weak self] _, completion in
                MusicPlayerEngine.shared.reloadDelegate?.reloadTable(with: index)
                MusicPlayerEngine.shared.play(id: index)
                
                // Highlight güncellemesi
                self?.updateCarPlayList()
                
                // Completion çağrısı
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
    
    // Çalan şarkı için simge oluştur
    private func createPlayingIcon() -> UIImage? {
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        return UIImage(systemName: "speaker.wave.2.fill", withConfiguration: config)?.withTintColor(.independence, renderingMode: .alwaysOriginal)
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
        let currentSongIndex = MusicPlayerEngine.shared.getCurrentSongIndex()
        var items: [CPListItem] = []
        
        for (index, song) in songs.enumerated() {
            let isCurrentSong = (index == currentSongIndex)
            let isPlaying = MusicPlayerEngine.shared.isPlaying()
            
            let shouldHighlight = isCurrentSong && isPlaying
            
            let item = CPListItem(
                text: song.title,
                detailText: song.author,
                image: resizeImageForCarPlay(song.image),
                accessoryImage: shouldHighlight ? createPlayingIcon() : nil,
                accessoryType: .none
            )
            
            item.handler = { [weak self] _, completion in
                MusicPlayerEngine.shared.reloadDelegate?.reloadTable(with: index)
                MusicPlayerEngine.shared.play(id: index)
                
                // Highlight güncellemesi
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self?.updateCarPlayList()
                }
                
                completion()
            }
            
            items.append(item)
        }
        
        let section = CPListSection(items: items, header: "\(PlaylistTitleManager.shared.getTitle()) (\(songs.count) songs)", sectionIndexTitle: nil)
        currentTemplate.updateSections([section])
    }
}
