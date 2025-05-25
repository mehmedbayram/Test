//
//  FileManagerHelper.swift
//  CarPlayKids
//
//  Created by Developer on 22.05.2025.
//


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
        
        return (title: title, artist: artist, artwork: artwork)
    }
    
//    func isAudioFile(_ url: URL) -> Bool {
//        let audioExtensions = ["mp3", "m4a", "wav", "aac", "flac", "ogg", "mp4", "m4p", "aiff", "wma"]
//        let fileExtension = url.pathExtension.lowercased()
//        return audioExtensions.contains(fileExtension)
//    }
    
    
    func isAudioFile(_ url: URL) -> Bool {
        let audioExtensions = ["mp3", "m4a", "wav", "aac", "flac", "ogg", "aiff", "wma"]
        let fileExtension = url.pathExtension.lowercased()
        return audioExtensions.contains(fileExtension)
    }
    
    func isVideoFile(_ url: URL) -> Bool {
        let videoExtensions = ["mp4", "mov", "avi", "mkv", "m4v", "wmv", "flv", "webm"]
        let fileExtension = url.pathExtension.lowercased()
        return videoExtensions.contains(fileExtension)
    }
    
    func isMediaFile(_ url: URL) -> Bool {
        return isAudioFile(url) || isVideoFile(url)
    }
    
    func extractVideoThumbnail(from url: URL) -> UIImage? {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        let time = CMTime(seconds: 1, preferredTimescale: 60)
        
        do {
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            print("Error generating thumbnail: \(error)")
            return nil
        }
    }
    
}
