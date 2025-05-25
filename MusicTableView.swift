//
//  MusicTableView.swift
//  CarPlayMusic
//
//  Created by Amerigo Mancino on 15/11/22.
//  Updated by System on 22/05/25.
//

import UIKit
import UniformTypeIdentifiers

class MusicTableView: UITableView, UITableViewDelegate, UITableViewDataSource, ReloadDelegate {

    private let cellID = "MusicCell"
    
    private var selectedRow = -1
    private var rowInPlay = -1
    private var lastInPlay = -1
    
    private var songs: [SongItem] = [] {
        didSet {
            DispatchQueue.main.async {
                self.reloadData()
            }
        }
    }
    
    // MARK: - Init

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        let nibCell = UINib(nibName: cellID, bundle: nil)
        self.register(nibCell, forCellReuseIdentifier: cellID)
        
        self.dataSource = self
        self.delegate = self
        
        // Enable editing for reordering
        self.isEditing = false
        
        MusicPlayerEngine.shared.reloadDelegate = self
        
        self.songs = MusicPlayerEngine.shared.getSongList()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [self] in
            setupDocumentPicker()
        }
    }
    
    // MARK: - Document Picker Setup
    
    private func setupDocumentPicker() {
        // Add navigation bar button for adding music
        if let parentVC = self.findViewController() {
            let addButton = UIBarButtonItem(
                barButtonSystemItem: .add,
                target: self,
                action: #selector(addMusicTapped)
            )
            let editButton = UIBarButtonItem(
                title: "Edit",
                style: .plain,
                target: self,
                action: #selector(editButtonTapped)
            )
            
            parentVC.navigationItem.rightBarButtonItems = [addButton, editButton]
        }
    }
    
    @objc private func addMusicTapped() {
            guard let parentVC = self.findViewController() else { return }
            
            let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [
                UTType.audio,
                UTType.mp3,
                UTType.mpeg4Audio,
                UTType.movie,
                UTType.video,
                UTType.mpeg4Movie
            ])
            documentPicker.delegate = self
            documentPicker.allowsMultipleSelection = true
            documentPicker.modalPresentationStyle = .formSheet
            
            parentVC.present(documentPicker, animated: true)
        }
    
    @objc private func editButtonTapped() {
        setEditing(!isEditing, animated: true)
        
        if let parentVC = self.findViewController() {
            let editButton = parentVC.navigationItem.rightBarButtonItems?.last
            editButton?.title = isEditing ? "Done" : "Edit"
        }
    }
    
    // MARK: - Table view data source methods
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return songs.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellID, for: indexPath) as! MusicCell
        
        let song = songs[indexPath.row]
        cell.authorImage.image =  song.image
        cell.title.text = song.title
        cell.author.text = song.author
        
        cell.playButton.tag = indexPath.row
        cell.playButton.addTarget(self, action: #selector(self.playAction(_:)), for: .touchUpInside)
        
        if self.rowInPlay == indexPath.row {
            cell.playButton.setImage(UIImage(systemName: "pause.circle.fill", withConfiguration: UIImage.SymbolConfiguration(scale: .large)), for: .normal)
        } else {
            cell.playButton.setImage(UIImage(systemName: "play.circle.fill", withConfiguration: UIImage.SymbolConfiguration(scale: .large)), for: .normal)
        }
        
        cell.backgroundColor = UIColor.clear
        cell.selectionStyle = .none
        
        return cell
    }
    
    // MARK: - Table view editing methods
    
    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        if let cell = tableView.cellForRow(at: indexPath) as? MusicCell {
            cell.playButton.tag = indexPath.row
            self.playAction(cell.playButton) // gerçek buton gönderildi
        }
    }
    
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        MusicPlayerEngine.shared.moveSong(from: sourceIndexPath.row, to: destinationIndexPath.row)
        
        // Update local array to reflect the change immediately
        let movedSong = songs.remove(at: sourceIndexPath.row)
        songs.insert(movedSong, at: destinationIndexPath.row)
        
        // Update playing indices
        if rowInPlay == sourceIndexPath.row {
            rowInPlay = destinationIndexPath.row
        } else if rowInPlay == destinationIndexPath.row {
            rowInPlay = sourceIndexPath.row
        }
        
        if selectedRow == sourceIndexPath.row {
            selectedRow = destinationIndexPath.row
        } else if selectedRow == destinationIndexPath.row {
            selectedRow = sourceIndexPath.row
        }
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let alert = UIAlertController(
                title: "Delete Song",
                message: "Are you sure you want to delete this song?",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
                let success = MusicPlayerEngine.shared.deleteSong(at: indexPath.row)
                if success {
                    self.songs.remove(at: indexPath.row)
                    tableView.deleteRows(at: [indexPath], with: .fade)
                    
                    // Update indices
                    if self.rowInPlay == indexPath.row {
                        self.rowInPlay = -1
                        self.selectedRow = -1
                    } else if self.rowInPlay > indexPath.row {
                        self.rowInPlay -= 1
                    }
                    
                    if self.selectedRow > indexPath.row {
                        self.selectedRow -= 1
                    }
                }
            })
            
            self.findViewController()?.present(alert, animated: true)
        }
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    
    // MARK: - Actions
    
    let generator = UIImpactFeedbackGenerator(style: .soft)
    @objc func playAction(_ sender : UIButton) {
    
        generator.prepare()
        generator.impactOccurred(intensity: 1.0)
        
        if selectedRow == sender.tag {
            if MusicPlayerEngine.shared.isPlaying() {
                MusicPlayerEngine.shared.stop()
                self.rowInPlay = -1
                self.lastInPlay = sender.tag
            } else {
                MusicPlayerEngine.shared.resumePlaying()
                self.rowInPlay = sender.tag
                self.lastInPlay = sender.tag
            }
        } else {
            MusicPlayerEngine.shared.play(id: sender.tag)
            self.selectedRow = sender.tag
            self.rowInPlay = sender.tag
            self.lastInPlay = sender.tag
        }
        
        self.reloadData()
        
    }
    
    // MARK: - Reload Delegate protocol
    
    func reloadTable() {
        MusicPlayerEngine.shared.stop()
        self.rowInPlay = -1
        self.selectedRow = -1
        
        DispatchQueue.main.async {
            self.reloadData()
        }
    }
    
    func reloadTable(with index: Int) {
        self.selectedRow = index
        self.rowInPlay = index
        self.lastInPlay = index
        
        DispatchQueue.main.async {
            self.reloadData()
        }
    }
    
    func reloadWithLast() {
        self.selectedRow = self.lastInPlay
        self.rowInPlay = self.lastInPlay
        
        DispatchQueue.main.async {
            self.reloadData()
        }
    }
    
    func songsDidUpdate() {
        self.songs = MusicPlayerEngine.shared.getSongList()
    }
}

// MARK: - Document Picker Delegate

extension MusicTableView: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let parentVC = self.findViewController() else { return }
        
        let loadingAlert = UIAlertController(title: "Adding Songs", message: "Please wait...", preferredStyle: .alert)
        parentVC.present(loadingAlert, animated: true)
        
        let group = DispatchGroup()
        var successCount = 0
        
        for url in urls {
            group.enter()
            
            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                group.leave()
                continue
            }
            
            MusicPlayerEngine.shared.addSongFromFile(url) { success in
                if success {
                    successCount += 1
                }
                url.stopAccessingSecurityScopedResource()
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            loadingAlert.dismiss(animated: true) {
                let message = successCount > 0
                    ? "Successfully added \(successCount) song(s)"
                    : "No songs were added"
                
                let alert = UIAlertController(title: "Import Complete", message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                parentVC.present(alert, animated: true)
            }
        }
    }
}

// MARK: - UIView Extension

extension UIView {
    func findViewController() -> UIViewController? {
        if let nextResponder = self.next as? UIViewController {
            return nextResponder
        } else if let nextResponder = self.next as? UIView {
            return nextResponder.findViewController()
        } else {
            return nil
        }
    }
}
