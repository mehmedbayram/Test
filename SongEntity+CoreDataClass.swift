//
//  SongEntity.swift
//  CarPlayKids
//
//  Created by Developer on 22.05.2025.
//


//
//  SongEntity+CoreDataClass.swift
//  CarPlayMusic
//
//  Created by System on 22/05/25.
//

import Foundation
import CoreData
import UIKit

@objc(SongEntity)
public class SongEntity: NSManagedObject {
    
    func toSongItem() -> SongItem {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let songURL = documentsPath.appendingPathComponent(self.fileName ?? "")
        
        var songImage = UIImage(named: "default_song_image") ?? UIImage()
        if let imageData = self.imageData {
            songImage = UIImage(data: imageData) ?? songImage
        }
        
        return SongItem(
            id: self.id ?? UUID(),
            title: self.title ?? "",
            author: self.author ?? "",
            url: songURL,
            image: songImage,
            fileName: self.fileName ?? "",
            sortOrder: Int(self.sortOrder)
        )
    }
}