//
//  MusicPlayerEngine.swift
//  CarPlayMusic
//
//  Created by Amerigo Mancino on 07/10/22.
//  Updated by System on 22/05/25.
//

import Foundation
import MediaPlayer
import AVKit

import NotificationCenter

// MARK: - Structs

public struct SongItem {
    var id: UUID
    var title: String
    var author: String
    var url: URL
    var image: UIImage
    var fileName: String
    var sortOrder: Int
}

// MARK: - Protocols

protocol ReloadDelegate: AnyObject {
    func reloadTable()
    func reloadTable(with: Int)
    func reloadWithLast()
    func songsDidUpdate()
}

// MARK: - Music Player Singleton

class MusicPlayerEngine {
    
    static var shared: MusicPlayerEngine = MusicPlayerEngine()
    
    // MARK: - Class variables
    
    public var player: AVPlayer = AVPlayer()
    
    /// Control center controller
    private var audioInfoControlCenter = [String: Any]()
    
    /// The shared MPRemoteCommandCenter
    private let commandCenter = MPRemoteCommandCenter.shared()
    
    /// Lists of songs - now loaded from Core Data
    private var songList: [SongItem] = [] {
        didSet {
            DispatchQueue.main.async {
                self.reloadDelegate?.songsDidUpdate()
            }
        }
    }
    
    weak var reloadDelegate: ReloadDelegate?
    
    var currentSongIndex: Int = -1
    
    // MARK: - NEW: Get Current Song Index //Carplay için
    public func getCurrentSongIndex() -> Int {
        return currentSongIndex
    }
    
    // MARK: - UI Sync Methods

    /// UI senkronizasyonu için şarkının çalıp çalmadığını ve hangi sırada olduğunu döndürür
    public func getCurrentPlaybackState() -> (isPlaying: Bool, songIndex: Int) {
        return (isPlaying: isPlaying(), songIndex: currentSongIndex)
    }
    
    // MARK: - Initialization
    private init() {
        // init made private to avoid external initialization
        self.setupRemoteTransportControls()
        self.loadSongsFromCoreData()
        
        // Add observer for when song ends
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(audioDidEnded),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
        
        // Add observer for interruptions
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        
    }
    
    // MARK: - Public functions
    
    public func addMediaFromFile(_ fileURL: URL, completion: @escaping (Bool) -> Void) {
        guard FileManagerHelper.shared.isMediaFile(fileURL) else {
            completion(false)
            return
        }
        
        // Copy file to documents directory
        guard let fileName = FileManagerHelper.shared.copyAudioFileToDocumentsDirectory(from: fileURL) else {
            completion(false)
            return
        }
        
        // Extract metadata
        let metadata = FileManagerHelper.shared.extractMetadata(from: fileURL)
        let imageData = metadata.artwork?.jpegData(compressionQuality: 0.8)
        
        // Save to Core Data
        let success = CoreDataManager.shared.addSong(
            title: metadata.title,
            author: metadata.artist,
            fileName: fileName,
            imageData: imageData
        )
        
        if success {
            loadSongsFromCoreData()
        }
        
        completion(success)
    }
    
    // Keep old method for backward compatibility
    public func addSongFromFile(_ fileURL: URL, completion: @escaping (Bool) -> Void) {
        addMediaFromFile(fileURL, completion: completion)
    }
    
    public func deleteSong(at index: Int) -> Bool {
        guard index < songList.count else { return false }
        
        let songToDelete = CoreDataManager.shared.fetchAllSongs()[index]
        let success = CoreDataManager.shared.deleteSong(songToDelete)
        
        if success {
            // If currently playing song is deleted, stop playback
            if currentSongIndex == index {
                stop()
                currentSongIndex = -1
            } else if currentSongIndex > index {
                currentSongIndex -= 1
            }
            
            loadSongsFromCoreData()
        }
        
        return success
    }
    
    // MARK: - NEW: Update Song Function
    public func updateSong(at index: Int, title: String, author: String, imageData: Data?) -> Bool {
        guard index < songList.count else { return false }
        
        let songId = songList[index].id
        let success = CoreDataManager.shared.updateSong(withId: songId, title: title, author: author, imageData: imageData)
        
        if success {
            loadSongsFromCoreData()
            
            // If currently playing song is updated, update the now playing info
            if currentSongIndex == index {
                updateNowPlayingInfo()
            }
        }
        
        return success
    }
    
    // MARK: - NEW: Force Reload Function
    public func reloadSongsFromCoreData() {
        loadSongsFromCoreData()
    }
    
    
    // MARK: - NEW: Update Now Playing Info
    private func updateNowPlayingInfo() {
        guard currentSongIndex >= 0 && currentSongIndex < songList.count else { return }
        
        let currentSong = songList[currentSongIndex]
        
        self.audioInfoControlCenter[MPMediaItemPropertyTitle] = currentSong.title
        self.audioInfoControlCenter[MPMediaItemPropertyArtist] = currentSong.author
        self.audioInfoControlCenter[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: currentSong.image.size, requestHandler: { _ in
            return currentSong.image
        })
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = self.audioInfoControlCenter
    }
    
    public func moveSong(from sourceIndex: Int, to destinationIndex: Int) {
        let songs = CoreDataManager.shared.fetchAllSongs()
        guard sourceIndex < songs.count && destinationIndex < songs.count else { return }
        
        var mutableSongs = songs
        let movedSong = mutableSongs.remove(at: sourceIndex)
        mutableSongs.insert(movedSong, at: destinationIndex)
        
        CoreDataManager.shared.updateSongOrder(mutableSongs)
        loadSongsFromCoreData()
    }
    
    private func loadSongsFromCoreData() {
        let songEntities = CoreDataManager.shared.fetchAllSongs()
        self.songList = songEntities.map { $0.toSongItem() }
    }
    
    /// Play a song by ID
    public func play(id: Int) -> Void {
        guard id < songList.count else { return }
        
        currentSongIndex = id
        
        
        NotificationCenter.default.post(name: .didUpdatePlayingSong, object: nil, userInfo: ["currentSongIndex": id]) //CarPlayMainScene'e bu bildirimi dinlemek için bir observer ekleyelim:
        
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
            object: self.player.currentItem
        )
    
        self.player.replaceCurrentItem(with: AVPlayerItem(url: songList[id].url))
    
        // update general metadata
        self.audioInfoControlCenter[MPNowPlayingInfoPropertyIsLiveStream] = false
        self.audioInfoControlCenter[MPMediaItemPropertyTitle] = songList[id].title
        self.audioInfoControlCenter[MPMediaItemPropertyArtist] = songList[id].author
        self.audioInfoControlCenter[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: songList[id].image.size, requestHandler: { _ in
            return self.songList[id].image
        })
        
        self.commandCenter.changePlaybackPositionCommand.isEnabled = true
        self.commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                let time = CMTime(seconds: event.positionTime, preferredTimescale: 1)
                self?.player.seek(to: time)
                self?.updatePlaybackRateData()
                return .success
            }
            return .commandFailed
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = self.audioInfoControlCenter
        
        // setup observer for when audio end
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.audioDidEnded),
            name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
            object: self.player.currentItem
        )
        
        self.player.play()
        self.updatePlaybackRateData()
        self.activateControlCenterCommands()
        
        // Durumu bildir
        NotificationCenter.default.post(
            name: .playerStateDidChange,
            object: nil,
            userInfo: ["isPlaying": true]
        )
    }
    
    /// Pause the current song.
    public func stop() -> Void {
        self.player.pause()
        self.updatePlaybackRateData()
        // Durumu bildir
        NotificationCenter.default.post(
            name: .playerStateDidChange,
            object: nil,
            userInfo: ["isPlaying": false]
        )
    }
    
    public func getSongList() -> [SongItem] {
        return self.songList
    }
    
    public func isPlaying() -> Bool {
        return self.player.rate != 0
    }
    
    public func resumePlaying() -> Void {
        self.player.play()
        self.updatePlaybackRateData()
        // Durumu bildir
        NotificationCenter.default.post(
            name: .playerStateDidChange,
            object: nil,
            userInfo: ["isPlaying": false]
        )
    }
    
    // MARK: - Control Center Commands
    
    private func activateControlCenterCommands() {
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.previousTrackCommand.isEnabled = currentSongIndex > 0
        commandCenter.nextTrackCommand.isEnabled = currentSongIndex < songList.count - 1
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.isEnabled = true
    }
    
    private func playCommand() -> MPRemoteCommandHandlerStatus {
        self.resumePlaying()
        return .success
    }
    
    private func pauseCommand() -> MPRemoteCommandHandlerStatus {
        self.stop()
        return .success
    }
    
    private func nextTrack() -> MPRemoteCommandHandlerStatus {
        if currentSongIndex < songList.count - 1 {
            play(id: currentSongIndex + 1)
            reloadDelegate?.reloadTable(with: currentSongIndex)
            return .success
        }
        return .commandFailed
    }
    
    private func previousTrack() -> MPRemoteCommandHandlerStatus {
        if currentSongIndex > 0 {
            play(id: currentSongIndex - 1)
            reloadDelegate?.reloadTable(with: currentSongIndex)
            return .success
        }
        return .commandFailed
    }
    
    /// Setup control center.
    private func setupRemoteTransportControls() -> Void {
        // Add handler for play command
        commandCenter.playCommand.addTarget { [unowned self] _ in
            return self.playCommand()
        }
        
        // Add handler for pause command
        commandCenter.pauseCommand.addTarget { [unowned self] _ in
            return self.pauseCommand()
        }
        
        // Add handler for previous track
        commandCenter.previousTrackCommand.addTarget { [unowned self] _ in
            return self.previousTrack()
        }
        
        // Add handler for next track
        commandCenter.nextTrackCommand.addTarget { [unowned self] _ in
            return self.nextTrack()
        }
        
        commandCenter.togglePlayPauseCommand.isEnabled = true
        
        // Add handler for seek command
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                let time = CMTime(seconds: event.positionTime, preferredTimescale: 1)
                self?.player.seek(to: time)
                self?.updatePlaybackRateData()
                return .success
            }
            return .commandFailed
        }
    }
    
    /// Update control center.
    private func updatePlaybackRateData() -> Void {
        self.audioInfoControlCenter[MPNowPlayingInfoPropertyPlaybackRate] = self.player.rate
        self.audioInfoControlCenter[MPNowPlayingInfoPropertyElapsedPlaybackTime] = self.player.currentItem?.currentTime().seconds
        self.audioInfoControlCenter[MPMediaItemPropertyPlaybackDuration] = self.player.currentItem?.asset.duration.seconds
        
        if self.player.rate == 1 {
            MPNowPlayingInfoCenter.default().playbackState = .playing
        } else {
            MPNowPlayingInfoCenter.default().playbackState = .paused
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = self.audioInfoControlCenter
        
        // Durumu bildirir
        NotificationCenter.default.post(
            name: .playerStateDidChange,
            object: nil,
            userInfo: ["isPlaying": self.player.rate != 0]
        )
        
    }
    
    // MARK: - Interruption Handling
    
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            // Interruption began, pause playback
            stop()
        case .ended:
            // Interruption ended, check if we should resume
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                resumePlaying()
            }
        @unknown default:
            break
        }
    }
    
    // MARK: - Protocol functions
    
    func stopSong() -> Void {
        DispatchQueue.main.async {
            self.reloadDelegate?.reloadTable()
        }
    }
    
    // MARK: - Events functions
    
    /// Triggered when an audio reached the end.
    @objc private func audioDidEnded() {
        // Auto play next song if available
        if currentSongIndex < songList.count - 1 {
            play(id: currentSongIndex + 1)
            reloadDelegate?.reloadTable(with: currentSongIndex)
        } else {
            stopSong()
        }
    }
    
    // MusicPlayerEngine.swift dosyasına ekleyin
    // MARK: - Navigation Handling
    private var playbackStateBeforeNavigation: Bool = false

    public func preservePlaybackState() {
        playbackStateBeforeNavigation = isPlaying()
        print("Preserving playback state: \(playbackStateBeforeNavigation ? "playing" : "paused")")
    }

    public func restorePlaybackState() {
        if playbackStateBeforeNavigation && !isPlaying() {
            print("Restoring playback state to playing")
            resumePlaying()
        }
        print("Playback state restored")
    }
    
}



//CarPlayMainScene'e bu bildirimi dinlemek için bir observer ekleyelim: -->
// MARK: - Notification Names
extension Notification.Name {
    static let didUpdatePlayingSong = Notification.Name("didUpdatePlayingSong")
    static let playerStateDidChange = Notification.Name("playerStateDidChange") // Bu satırı ekleyin
}
//CarPlayMainScene'e bu bildirimi dinlemek için bir observer ekleyelim: <--


// MusicPlayerEngine.swift dosyasına eklenecek fonksiyonlar

extension MusicPlayerEngine {
    
    // MARK: - File Synchronization Functions
    
    /// Akıllı dosya senkronizasyonu (düzeltilmiş versiyon)
    public func smartSyncFilesOnStartup() {
        print("Starting smart file synchronization...")
        
        let changes = FileManagerHelper.shared.detectFileChanges()
        var operationCount = 0
        var hasRenameOperations = false
        
        // 1.Rename işlemlerini handle et
        for rename in changes.renamed {
            let success = CoreDataManager.shared.handleFileRename(
                oldFileName: rename.old,
                newFileName: rename.new,
                keepSortOrder: true  // Bu parametre true olarak kalsın
            )
            
            if success {
                print("Handled file rename: \(rename.old) -> \(rename.new)")
                operationCount += 1
            }
        }
        
        // 2. Silinen dosyaları temizle
        for deletedFile in changes.deleted {
            if let song = CoreDataManager.shared.fetchAllSongs().first(where: { $0.fileName == deletedFile }) {
                let success = CoreDataManager.shared.deleteSong(song)
                if success {
                    print("Removed deleted file from Core Data: \(deletedFile)")
                    operationCount += 1
                }
            }
        }
        
        // 3. Yeni dosyaları ekle
        for newFileURL in changes.added {
            let success = CoreDataManager.shared.addSongFromExistingFile(newFileURL)
            if success {
                print("Added new file: \(newFileURL.lastPathComponent)")
                operationCount += 1
            }
        }
        
        // 4. SADECE RENAME OLMAYAN İŞLEMLERDE REORDER YAP
        if operationCount > 0 {
            // Sadece dosya eklenme/silinme varsa reorder yap
            let needsReordering = changes.deleted.count > 0 || changes.added.count > 0
            
            if needsReordering && !hasRenameOperations {
                CoreDataManager.shared.reorderSongs()
                print("Reordered songs after add/delete operations")
            } else if hasRenameOperations && !needsReordering {
                print("Skipped reordering - only rename operations detected")
            }
            
            // Song listesini yeniden yükle
            loadSongsFromCoreData()
            
            // UI'ı güncelle
            DispatchQueue.main.async {
                self.reloadDelegate?.songsDidUpdate()
            }
            
            print("Smart sync completed: \(operationCount) operations")
        } else {
            print("No changes detected")
        }
    }
    
    /// Eski syncFilesOnStartup metodunu güncelle
    public func syncFilesOnStartup() {
        smartSyncFilesOnStartup()
    }
       
       /// Detaylı senkronizasyon raporu döndürür
       public func getSyncReport() -> (missing: [String], orphaned: [String], total: Int) {
           let comparison = FileManagerHelper.shared.compareFilesWithCoreData()
           let totalSongs = CoreDataManager.shared.fetchAllSongs().count
           
           return (missing: comparison.missing, orphaned: comparison.orphaned, total: totalSongs)
       }
       
       /// Manuel temizlik işlemi
       public func cleanupMissingFiles() -> Int {
           let deletedCount = CoreDataManager.shared.cleanupOrphanedSongs()
           
           if deletedCount > 0 {
               loadSongsFromCoreData()
               DispatchQueue.main.async {
                   self.reloadDelegate?.songsDidUpdate()
               }
           }
           
           return deletedCount
       }
    
    /// Title güncellendiğinde dosya senkronizasyonu ile günceller
    public func updateSongWithFileSync(at index: Int, title: String, author: String, imageData: Data?) -> Bool {
        guard index < songList.count else { return false }
        
        let songId = songList[index].id
        let success = CoreDataManager.shared.updateSongWithFileSync(withId: songId, title: title, author: author, imageData: imageData)
        
        if success {
            loadSongsFromCoreData()
            
            // If currently playing song is updated, update the now playing info
            if currentSongIndex == index {
                updateNowPlayingInfo()
            }
            
            // UI'ı güncelle
            DispatchQueue.main.async {
                self.reloadDelegate?.songsDidUpdate()
            }
        }
        
        return success
    }
    
    /// Manual senkronizasyon tetikleyici
    public func forceSyncFiles() {
        syncFilesOnStartup()
    }
    
    
    /// Sıralama düzenini konsola yazdırır
    public func printSortOrder() {
        let songs = CoreDataManager.shared.fetchAllSongs()
        
        print("=== CURRENT SORT ORDER ===")
        for (index, song) in songs.enumerated() {
            print("\(index): \(song.title ?? "Unknown") - sortOrder: \(song.sortOrder) - fileName: \(song.fileName ?? "Unknown")")
        }
        print("==========================")
    }
    
    /// Sıralama tutarlılığını kontrol eder
    public func validateSortOrder() -> Bool {
        let songs = CoreDataManager.shared.fetchAllSongs()
        
        for (index, song) in songs.enumerated() {
            if song.sortOrder != Int32(index) {
                print("Sort order inconsistency detected at index \(index): expected \(index), got \(song.sortOrder)")
                return false
            }
        }
        
        print("Sort order is consistent")
        return true
    }
    
    
}
