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
    }
    
    // MARK: - Public functions
    
    public func addSongFromFile(_ fileURL: URL, completion: @escaping (Bool) -> Void) {
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
    
    public func moveSong(from sourceIndex: Int, to destinationIndex: Int) {
        var songs = CoreDataManager.shared.fetchAllSongs()
        let movedSong = songs.remove(at: sourceIndex)
        songs.insert(movedSong, at: destinationIndex)
        
        CoreDataManager.shared.updateSongOrder(songs)
        loadSongsFromCoreData()
        
        // Update current playing index if needed
        if currentSongIndex == sourceIndex {
            currentSongIndex = destinationIndex
        } else if currentSongIndex > sourceIndex && currentSongIndex <= destinationIndex {
            currentSongIndex -= 1
        } else if currentSongIndex < sourceIndex && currentSongIndex >= destinationIndex {
            currentSongIndex += 1
        }
    }
    
    private func loadSongsFromCoreData() {
        let songEntities = CoreDataManager.shared.fetchAllSongs()
        self.songList = songEntities.map { $0.toSongItem() }
    }
    
    /// Play one of the songs in the song list.
    public func play(id: Int) -> Void {
        guard id < songList.count else { return }
        
        currentSongIndex = id
        
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
    }
    
    /// Pause the current song.
    public func stop() -> Void {
        self.player.pause()
        self.updatePlaybackRateData()
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
    }
    
    // MARK: - Control Center Commands
    
    private func activateControlCenterCommands() {
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.previousTrackCommand.isEnabled = currentSongIndex > 0
        commandCenter.nextTrackCommand.isEnabled = currentSongIndex < songList.count - 1
    }
    
    @objc private func playCommand() -> MPRemoteCommandHandlerStatus {
        resumePlaying()
        reloadDelegate?.reloadWithLast()
        return .success
    }
    
    @objc private func pauseCommand() -> MPRemoteCommandHandlerStatus {
        stop()
        reloadDelegate?.reloadTable()
        return .success
    }
    
    @objc private func previousTrack() -> MPRemoteCommandHandlerStatus {
        guard currentSongIndex > 0 else { return .commandFailed }
        play(id: currentSongIndex - 1)
        reloadDelegate?.reloadTable(with: currentSongIndex)
        return .success
    }
    
    @objc private func nextTrack() -> MPRemoteCommandHandlerStatus {
        guard currentSongIndex < songList.count - 1 else { return .commandFailed }
        play(id: currentSongIndex + 1)
        reloadDelegate?.reloadTable(with: currentSongIndex)
        return .success
    }
    
    // MARK: - Private functions
    
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
}
