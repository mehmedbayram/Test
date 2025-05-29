//
//  PlaylistTitleManager.swift
//  CarPlayKids
//
//  Created by Developer on 28.05.2025.
//


import Foundation

class PlaylistTitleManager {
    static let shared = PlaylistTitleManager()
    
    private let titleKey = "playlistTitle"
    private let defaultTitle = "Eren'in Sevdiği Şarkılar"
    
    private init() {}
    
    func getTitle() -> String {
        return UserDefaults.standard.string(forKey: titleKey) ?? defaultTitle
    }
    
    func setTitle(_ title: String) {
        UserDefaults.standard.set(title, forKey: titleKey)
    }
    
    func resetToDefault() {
        UserDefaults.standard.set(defaultTitle, forKey: titleKey)
    }
}