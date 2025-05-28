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


// CoreDataManager.swift dosyasına eklenecek fonksiyonlar

extension CoreDataManager {
    
    // MARK: - File Synchronization Functions
    
    /// Belirli dosya isminin Core Data'da olup olmadığını kontrol eder
    func songExists(fileName: String) -> Bool {
        let request: NSFetchRequest<SongEntity> = SongEntity.fetchRequest()
        request.predicate = NSPredicate(format: "fileName == %@", fileName)
        request.fetchLimit = 1
        
        do {
            let count = try context.count(for: request)
            return count > 0
        } catch {
            print("Error checking if song exists: \(error)")
            return false
        }
    }
    
    /// Song'un dosya ismini günceller
    func updateSongFileName(withId id: UUID, newFileName: String) -> Bool {
        let request: NSFetchRequest<SongEntity> = SongEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let songs = try context.fetch(request)
            if let song = songs.first {
                song.fileName = newFileName
                try context.save()
                return true
            }
        } catch {
            print("Error updating song filename: \(error)")
        }
        
        return false
    }
    
    /// Title güncellendiğinde dosya ismini de günceller
    func updateSongWithFileSync(withId id: UUID, title: String, author: String, imageData: Data?) -> Bool {
        let request: NSFetchRequest<SongEntity> = SongEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let songs = try context.fetch(request)
            if let song = songs.first {
                let oldFileName = song.fileName ?? ""
                let fileExtension = FileManagerHelper.shared.getFileExtension(fileName: oldFileName)
                let newFileName = FileManagerHelper.shared.sanitizeFileName(title, withExtension: fileExtension)
                
                // Dosya ismini değiştir
                if oldFileName != newFileName {
                    let renameSuccess = FileManagerHelper.shared.renameFile(from: oldFileName, to: newFileName)
                    if renameSuccess {
                        song.fileName = newFileName
                    }
                }
                
                // Diğer bilgileri güncelle
                song.title = title
                song.author = author
                song.imageData = imageData
                
                try context.save()
                return true
            }
        } catch {
            print("Error updating song with file sync: \(error)")
        }
        
        return false
    }
    
    /// Orphaned files (Core Data'da olmayan dosyalar) için song entity oluşturur
    func addSongFromExistingFile(_ fileURL: URL) -> Bool {
        let fileName = fileURL.lastPathComponent
        
        // Zaten var mı kontrol et
        if songExists(fileName: fileName) {
            return false
        }
        
        // Metadata'yı çıkar
        let metadata = FileManagerHelper.shared.extractMetadata(from: fileURL)
        let imageData = metadata.artwork?.jpegData(compressionQuality: 0.8)
        
        // Yeni song entity oluştur
        let song = SongEntity(context: context)
        song.id = UUID()
        song.title = metadata.title
        song.author = metadata.artist
        song.fileName = fileName
        song.imageData = imageData
        song.dateAdded = Date()
        song.sortOrder = Int32(getNextSortOrder())
        
        do {
            try context.save()
            print("Added existing file to Core Data: \(fileName)")
            return true
        } catch {
            print("Error adding existing file to Core Data: \(error)")
            return false
        }
    }
    
    // MARK: - File Deletion Sync Functions
        
        /// Fiziksel dosyası olmayan song'ları bulur ve siler
        func cleanupOrphanedSongs() -> Int {
            let songs = fetchAllSongs()
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            var deletedCount = 0
            
            for song in songs {
                guard let fileName = song.fileName else { continue }
                
                let fileURL = documentsPath.appendingPathComponent(fileName)
                
                // Fiziksel dosya var mı kontrol et
                if !FileManager.default.fileExists(atPath: fileURL.path) {
                    print("File not found, removing from Core Data: \(fileName)")
                    
                    // Core Data'dan sil (fiziksel dosya zaten yok)
                    context.delete(song)
                    deletedCount += 1
                }
            }
            
            // Değişiklikleri kaydet
            if deletedCount > 0 {
                do {
                    try context.save()
                    print("Cleaned up \(deletedCount) orphaned song(s)")
                } catch {
                    print("Error saving after cleanup: \(error)")
                }
            }
            
            return deletedCount
        }
        
        /// Belirli dosya isminin fiziksel dosyasının var olup olmadığını kontrol eder
        func physicalFileExists(fileName: String) -> Bool {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fileURL = documentsPath.appendingPathComponent(fileName)
            return FileManager.default.fileExists(atPath: fileURL.path)
        }
        
        /// Tüm song'ların fiziksel dosyalarını kontrol eder
        func validateAllSongs() -> [String] {
            let songs = fetchAllSongs()
            var missingFiles: [String] = []
            
            for song in songs {
                guard let fileName = song.fileName else { continue }
                
                if !physicalFileExists(fileName: fileName) {
                    missingFiles.append(fileName)
                }
            }
            
            return missingFiles
        }
    
    // MARK: - File Rename Handling
        
        /// Dosya ismini sıralama koruyarak günceller
        func handleFileRename(oldFileName: String, newFileName: String, keepSortOrder: Bool = true) -> Bool {
            let request: NSFetchRequest<SongEntity> = SongEntity.fetchRequest()
            request.predicate = NSPredicate(format: "fileName == %@", oldFileName)
            
            do {
                let songs = try context.fetch(request)
                if let song = songs.first {
                    let oldSortOrder = song.sortOrder
                    
                    song.fileName = newFileName
                    
                    // Sıralama koruma seçeneği
                    if keepSortOrder {
                        song.sortOrder = oldSortOrder
                    } else {
                        song.sortOrder = Int32(getNextSortOrder())
                    }
                    
                    try context.save()
                    print("File renamed in Core Data: \(oldFileName) -> \(newFileName), sort order: \(song.sortOrder)")
                    return true
                }
            } catch {
                print("Error handling file rename: \(error)")
            }
            
            return false
        }
        
        /// Sıralama düzenini yeniden düzenler (boşlukları kapatır)
        func reorderSongs() {
            let songs = fetchAllSongs() // Zaten sortOrder'a göre sıralı geliyor
            
            for (index, song) in songs.enumerated() {
                song.sortOrder = Int32(index)
            }
            
            saveContext()
        }
        
        /// Belirli sıralama pozisyonundaki song'u bulur
        func getSongAt(sortOrder: Int32) -> SongEntity? {
            let request: NSFetchRequest<SongEntity> = SongEntity.fetchRequest()
            request.predicate = NSPredicate(format: "sortOrder == %d", sortOrder)
            request.fetchLimit = 1
            
            do {
                let songs = try context.fetch(request)
                return songs.first
            } catch {
                print("Error getting song at sort order: \(error)")
                return nil
            }
        }
    
}
