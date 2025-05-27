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
