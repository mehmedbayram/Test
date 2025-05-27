//
//  CoreDataManager.swift
//  CarPlayMusic
//
//  Created by System on 22/05/25.
//

import Foundation
import CoreData
import UIKit

class CoreDataManager {
    static let shared = CoreDataManager()
    
    private init() {}
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "MusicModel")
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data error: \(error)")
            }
        }
        return container
    }()
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Save error: \(error)")
            }
        }
    }
    
    // MARK: - Song Operations
    
    func addSong(title: String, author: String, fileName: String, imageData: Data?) -> Bool {
        let song = SongEntity(context: context)
        song.id = UUID()
        song.title = title
        song.author = author
        song.fileName = fileName
        song.imageData = imageData
        song.dateAdded = Date()
        song.sortOrder = Int32(getNextSortOrder())
        
        do {
            try context.save()
            return true
        } catch {
            print("Error saving song: \(error)")
            return false
        }
    }
    
    func fetchAllSongs() -> [SongEntity] {
        let request: NSFetchRequest<SongEntity> = SongEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching songs: \(error)")
            return []
        }
    }
    
    func deleteSong(_ song: SongEntity) -> Bool {
        // Delete physical file
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsPath.appendingPathComponent(song.fileName ?? "")
        
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            print("Error deleting file: \(error)")
        }
        
        context.delete(song)
        
        do {
            try context.save()
            return true
        } catch {
            print("Error deleting song: \(error)")
            return false
        }
    }
    
    // MARK: - New Update Function
    func updateSong(withId id: UUID, title: String, author: String, imageData: Data?) -> Bool {
        let request: NSFetchRequest<SongEntity> = SongEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let songs = try context.fetch(request)
            if let song = songs.first {
                song.title = title
                song.author = author
                song.imageData = imageData
                
                try context.save()
                return true
            }
        } catch {
            print("Error updating song: \(error)")
        }
        
        return false
    }
    
    func updateSongOrder(_ songs: [SongEntity]) {
        for (index, song) in songs.enumerated() {
            song.sortOrder = Int32(index)
        }
        saveContext()
    }
    
    private func getNextSortOrder() -> Int {
        let request: NSFetchRequest<SongEntity> = SongEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: false)]
        request.fetchLimit = 1
        
        do {
            let songs = try context.fetch(request)
            return Int(songs.first?.sortOrder ?? -1) + 1
        } catch {
            return 0
        }
    }
}
