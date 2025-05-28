//
//  FileManagerHelper.swift
//  CarPlayMusic
//
//  Created by System on 22/05/25.
//

import Foundation
import UIKit
import AVFoundation
import UniformTypeIdentifiers

class FileManagerHelper {
    static let shared = FileManagerHelper()
    
    private init() {}
    
    func copyAudioFileToDocumentsDirectory(from sourceURL: URL) -> String? {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileName = sourceURL.lastPathComponent
        let destinationURL = documentsDirectory.appendingPathComponent(fileName)
        
        do {
            // Check if file already exists
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                // Generate unique name
                let name = sourceURL.deletingPathExtension().lastPathComponent
                let ext = sourceURL.pathExtension
                let uniqueName = "\(name)_\(Int(Date().timeIntervalSince1970)).\(ext)"
                let uniqueDestinationURL = documentsDirectory.appendingPathComponent(uniqueName)
                
                try FileManager.default.copyItem(at: sourceURL, to: uniqueDestinationURL)
                return uniqueName
            } else {
                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                return fileName
            }
        } catch {
            print("Error copying file: \(error)")
            return nil
        }
    }
    
    func extractMetadata(from url: URL) -> (title: String, artist: String, artwork: UIImage?) {
        let asset = AVAsset(url: url)
        let metadata = asset.metadata
        
        var title = url.deletingPathExtension().lastPathComponent
        var artist = "Unknown Artist"
        var artwork: UIImage?
        
        // Check if it's a video file and extract thumbnail
        if isVideoFile(url) {
            artwork = extractVideoThumbnail(from: url)
        }
        
        for item in metadata {
            guard let key = item.commonKey?.rawValue,
                  let value = item.value else { continue }
            
            switch key {
            case AVMetadataKey.commonKeyTitle.rawValue:
                if let titleValue = value as? String {
                    title = titleValue
                }
            case AVMetadataKey.commonKeyArtist.rawValue:
                if let artistValue = value as? String {
                    artist = artistValue
                }
            case AVMetadataKey.commonKeyArtwork.rawValue:
                if let artworkData = value as? Data {
                    artwork = UIImage(data: artworkData)
                }
            default:
                break
            }
        }
        
        // If no artwork found, use default music icon
        if artwork == nil {
            artwork = createDefaultMusicIcon()
        }
        
        return (title: title, artist: artist, artwork: artwork)
    }
    
    private func extractVideoThumbnail(from url: URL) -> UIImage? {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        let time = CMTime(seconds: 1.0, preferredTimescale: 600)
        
        do {
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            print("Error generating thumbnail: \(error)")
            return nil
        }
    }
    
    private func createDefaultMusicIcon() -> UIImage {
        if let musicNote = UIImage(systemName: "music.note") {
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 200))
            return renderer.image { context in
                UIColor.independence.setFill()
                context.fill(CGRect(origin: .zero, size: CGSize(width: 200, height: 200)))
                
                let imageRect = CGRect(x: 50, y: 50, width: 100, height: 100)
                UIColor.white.setFill()
                musicNote.withTintColor(.white).draw(in: imageRect)
            }
        }
        return UIImage()
    }
    
    func isAudioFile(_ url: URL) -> Bool {
        let audioExtensions = ["mp3", "m4a", "wav", "aac", "flac", "ogg", "aiff", "wma"]
        let fileExtension = url.pathExtension.lowercased()
        return audioExtensions.contains(fileExtension)
    }
    
    func isVideoFile(_ url: URL) -> Bool {
        let videoExtensions = ["mp4", "mov", "avi", "mkv", "m4v", "3gp", "webm", "flv"]
        let fileExtension = url.pathExtension.lowercased()
        return videoExtensions.contains(fileExtension)
    }
    
    func isMediaFile(_ url: URL) -> Bool {
        return isAudioFile(url) || isVideoFile(url)
    }
}


// FileManagerHelper.swift dosyasına eklenecek fonksiyonlar

extension FileManagerHelper {
    
    // MARK: - File Scanning and Synchronization
    
    /// Documents directory'deki tüm medya dosyalarını tarar
    func scanDocumentsDirectoryForNewFiles() -> [URL] {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        var newFiles: [URL] = []
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: documentsDirectory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
            )
            
            for fileURL in fileURLs {
                if isMediaFile(fileURL) {
                    // Core Data'da bu dosya var mı kontrol et
                    let fileName = fileURL.lastPathComponent
                    if !CoreDataManager.shared.songExists(fileName: fileName) {
                        newFiles.append(fileURL)
                    }
                }
            }
        } catch {
            print("Error scanning documents directory: \(error)")
        }
        
        return newFiles
    }
    
    /// Dosya ismini güvenli hale getirir (title'dan dosya ismi oluşturmak için)
    func sanitizeFileName(_ title: String, withExtension ext: String) -> String {
        // Türkçe karakterleri ve özel karakterleri temizle
        let invalidCharacters = CharacterSet(charactersIn: "\\/:*?\"<>|")
        let sanitized = title
            .components(separatedBy: invalidCharacters)
            .joined(separator: "_")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Boş string kontrolü
        let finalName = sanitized.isEmpty ? "Unknown_Song" : sanitized
        return "\(finalName).\(ext)"
    }
    
    /// Dosya ismini değiştirir
    func renameFile(from oldFileName: String, to newFileName: String) -> Bool {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let oldURL = documentsDirectory.appendingPathComponent(oldFileName)
        let newURL = documentsDirectory.appendingPathComponent(newFileName)
        
        // Dosya var mı kontrol et
        guard FileManager.default.fileExists(atPath: oldURL.path) else {
            print("Source file does not exist: \(oldFileName)")
            return false
        }
        
        // Hedef dosya zaten var mı kontrol et
        if FileManager.default.fileExists(atPath: newURL.path) {
            print("Target file already exists: \(newFileName)")
            return false
        }
        
        do {
            try FileManager.default.moveItem(at: oldURL, to: newURL)
            print("File renamed from \(oldFileName) to \(newFileName)")
            return true
        } catch {
            print("Error renaming file: \(error)")
            return false
        }
    }
    
    /// Mevcut dosyanın uzantısını alır
    func getFileExtension(fileName: String) -> String {
        return URL(fileURLWithPath: fileName).pathExtension
    }
    
    // MARK: - File Validation and Cleanup
        
        /// Documents directory'deki tüm dosyaları listeler
        func getAllFilesInDocuments() -> [String] {
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            var allFiles: [String] = []
            
            do {
                let fileURLs = try FileManager.default.contentsOfDirectory(
                    at: documentsDirectory,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
                )
                
                for fileURL in fileURLs {
                    if isMediaFile(fileURL) {
                        allFiles.append(fileURL.lastPathComponent)
                    }
                }
            } catch {
                print("Error getting files in documents: \(error)")
            }
            
            return allFiles
        }
        
        /// Core Data'daki dosyalar ile fiziksel dosyaları karşılaştırır
        func compareFilesWithCoreData() -> (missing: [String], orphaned: [String]) {
            let physicalFiles = Set(getAllFilesInDocuments())
            let coreDataSongs = CoreDataManager.shared.fetchAllSongs()
            let coreDataFiles = Set(coreDataSongs.compactMap { $0.fileName })
            
            let missingFiles = Array(coreDataFiles.subtracting(physicalFiles)) // Core Data'da var ama fiziksel dosya yok
            let orphanedFiles = Array(physicalFiles.subtracting(coreDataFiles)) // Fiziksel dosya var ama Core Data'da yok
            
            return (missing: missingFiles, orphaned: orphanedFiles)
        }
        
    /*
        /// Dosya boyutunu alır (opsiyonel bilgi için)
        func getFileSize(fileName: String) -> Int64? {
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fileURL = documentsDirectory.appendingPathComponent(fileName)
            
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                return attributes[.size] as? Int64
            } catch {
                return nil
            }
        }
     */
    
    // MARK: - File Rename Detection
    
    /// Dosya ismi değişikliklerini tespit eder
    func detectFileChanges() -> (renamed: [(old: String, new: String, metadata: (title: String, artist: String, artwork: UIImage?))], deleted: [String], added: [URL]) {
        let currentFiles = getAllFilesInDocuments()
        let coreDataSongs = CoreDataManager.shared.fetchAllSongs()
        let coreDataFiles = Set(coreDataSongs.compactMap { $0.fileName })
        
        var renamedFiles: [(old: String, new: String, metadata: (title: String, artist: String, artwork: UIImage?))] = []
        var deletedFiles: [String] = []
        var addedFiles: [URL] = []
        
        let currentFilesSet = Set(currentFiles)
        
        // Silinen dosyaları bul
        deletedFiles = Array(coreDataFiles.subtracting(currentFilesSet))
        
        // Yeni eklenen dosyaları bul
        for fileName in currentFiles {
            if !coreDataFiles.contains(fileName) {
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let fileURL = documentsPath.appendingPathComponent(fileName)
                addedFiles.append(fileURL)
            }
        }
        
        // Rename işlemlerini tespit et (metadata karşılaştırması ile)
        if deletedFiles.count == 1 && addedFiles.count == 1 {
            let deletedFile = deletedFiles[0]
            let addedFile = addedFiles[0]
            
            // Silinen dosyanın Core Data'daki metadata'sını al
            if let deletedSong = coreDataSongs.first(where: { $0.fileName == deletedFile }) {
                // Yeni dosyanın metadata'sını çıkar
                let newMetadata = extractMetadata(from: addedFile)
                
                // Metadata benzerliğini kontrol et (dosya boyutu, süre vs.)
                if areFilesSimilar(deletedSong: deletedSong, newFileURL: addedFile) {
                    renamedFiles.append((
                        old: deletedFile,
                        new: addedFile.lastPathComponent,
                        metadata: newMetadata
                    ))
                    
                    // Renamed olarak tespit edildiyse deleted ve added listelerinden çıkar
                    deletedFiles.removeAll()
                    addedFiles.removeAll()
                }
            }
        }
        
        return (renamed: renamedFiles, deleted: deletedFiles, added: addedFiles)
    }
    
    /// İki dosyanın aynı dosya olup olmadığını kontrol eder
    private func areFilesSimilar(deletedSong: SongEntity, newFileURL: URL) -> Bool {
        // Dosya uzantısı aynı mı?
        let deletedExtension = URL(fileURLWithPath: deletedSong.fileName ?? "").pathExtension
        let newExtension = newFileURL.pathExtension
        
        if deletedExtension != newExtension {
            return false
        }
        
        // Dosya boyutu karşılaştırması
        if let deletedSize = getFileSize(fileName: deletedSong.fileName ?? ""),
           let newSize = getFileSize(fileName: newFileURL.lastPathComponent) {
            
            // Boyut farkı %5'ten fazla ise farklı dosyalar
            let sizeDifference = abs(deletedSize - newSize)
            let averageSize = (deletedSize + newSize) / 2
            let differencePercentage = Double(sizeDifference) / Double(averageSize) * 100
            
            if differencePercentage > 5.0 {
                return false
            }
        }
        
        // Dosya oluşturulma tarihi kontrolü (yakın zamanda mı oluşturuldu?)
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let newFileURL_full = documentsPath.appendingPathComponent(newFileURL.lastPathComponent)
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: newFileURL_full.path)
            if let creationDate = attributes[.creationDate] as? Date {
                let timeDifference = abs(creationDate.timeIntervalSinceNow)
                // Son 30 saniye içinde oluşturulmuş mu?
                return timeDifference < 30
            }
        } catch {
            print("Error getting file attributes: \(error)")
        }
        
        return true
    }
    
    /// Dosya boyutunu güvenli şekilde alır
    private func getFileSize(fileName: String) -> Int64? {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            return attributes[.size] as? Int64
        } catch {
            return nil
        }
    }
    
}
