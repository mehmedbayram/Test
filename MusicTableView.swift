//
//  MusicTableView.swift
//  CarPlayMusic
//
//  Created by Amerigo Mancino on 15/11/22.
//  Updated by System on 22/05/25.
//

import UIKit
import UniformTypeIdentifiers

class MusicTableView: UITableView, UITableViewDelegate, UITableViewDataSource, ReloadDelegate, EditSongDelegate {

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
    
 
    
    // Pull to refresh 2/2 -->
    @objc func doSomething(refreshControl: UIRefreshControl) {
        
        self.refreshControl?.beginRefreshing()
        
        
        generator.impactOccurred(intensity: 1.0)
        
        // Tam file sync işlemini tetikle (ekleme + silme)
        MusicPlayerEngine.shared.syncFilesOnStartup()
        
        // Veriyi çekmiş olsa bile 1 saniye sonra refresh animasyonu bitsin
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            
            // State'leri resetle
            self.reloadTable()
            
            // MusicPlayerEngine'den fresh data çek
            MusicPlayerEngine.shared.reloadSongsFromCoreData()
            
            // Songs array'ini güncelle - didSet otomatik olarak reloadData() yapacak
            self.songs = MusicPlayerEngine.shared.getSongList()
            
            // Delegate metodunu manuel çağır (eğer herhangi bir güncelleme varsa)
            // Bu özellikle başka yerlerden (örneğin CarPlay'den) yapılan değişiklikleri yakalar
            DispatchQueue.main.async {
                // songsDidUpdate delegate metodunu çağır
                self.songsDidUpdate()
            }
            
            self.refreshControl?.endRefreshing()
            
            // reloadData() zaten didSet içinde çağırılacak, tekrar çağırmaya gerek yok
            // self.reloadData() // Bu satırı kaldırıyoruz
            
            
            self.generator.impactOccurred(intensity: 1.0)
        }
    }
    // Pull to refresh 2/2 <--
    
    // YENİ METOD - EditSongViewController disappear olduğunda çağırılacak
    func editViewControllerWillDisappear() {
        print("Edit view controller disappeared - calling doSomething")
        
        /*
        // doSomething metodunu çağır
        // Eğer refreshControl varsa onu kullan, yoksa direkt çağır
        if let refreshControl = self.refreshControl {
            self.doSomething(refreshControl: refreshControl)
        } else {
            // refreshControl yoksa manuel olarak refresh işlemini yap
            self.manualRefresh()
        }
         */
        self.manualRefresh()
    }
    
    // Helper method - refreshControl olmadığında kullanmak için
    private func manualRefresh() {

        
        // State'leri resetle
        self.reloadTable()
        
        // MusicPlayerEngine'den fresh data çek
        MusicPlayerEngine.shared.reloadSongsFromCoreData()
        
        // Songs array'ini güncelle
        self.songs = MusicPlayerEngine.shared.getSongList()
        
        // Delegate metodunu manuel çağır
        DispatchQueue.main.async {
            self.songsDidUpdate()
        }
        

        
        print("Manual refresh completed")
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
        
        let refreshControl = UIRefreshControl()
        // Pull to refresh 1/2 -->
//        let refreshControl = UIRefreshControl() // Pull to refresh
        refreshControl.tintColor = UIColor.independence
        refreshControl.transform = CGAffineTransform(scaleX: 0.75, y: 0.75) //Refresh control büyüklüğü, bunu yaparken yazı fontunu büyütmelisin ama
        
        refreshControl.attributedTitle = NSMutableAttributedString(string: "↓ Güncellemek için aşağı çekin ↓"/*"Son güncelleme: \(refreshDateTime)"*/, attributes: [NSAttributedString.Key.font: UIFont(name: "Helvetica Neue", size: 14.0)!, NSAttributedString.Key.foregroundColor: UIColor.independence])
        
        refreshControl.addTarget(self, action: #selector(doSomething), for: .valueChanged)

        self.refreshControl = refreshControl
        // Pull to refresh 1/2 <--
        
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
//                title: "Sort",
                image: UIImage(systemName: "arrow.up.arrow.down"),
                style: .plain,
                target: self,
                action: #selector(editButtonTapped)
            )
            
            parentVC.navigationItem.rightBarButtonItems = [editButton]
            parentVC.navigationItem.leftBarButtonItems = [addButton]
        }
    }
    
    @objc private func addMusicTapped() {
        
        generator.prepare()
        generator.impactOccurred(intensity: 1.0)
        
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
        
        generator.prepare()
        generator.impactOccurred(intensity: 1.0)
        
        if let parentVC = self.findViewController() {
            let editButton = parentVC.navigationItem.rightBarButtonItems?.last
            editButton?.title = isEditing ? "Done" : "Sort"
            editButton?.image = isEditing ? UIImage(systemName: "checkmark") : UIImage(systemName: "arrow.up.arrow.down")
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
            self.playAction(cell.playButton)
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
    
    // MARK: - Swipe Actions
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        // Edit Action
        let editAction = UIContextualAction(style: .normal, title: "Edit") { [weak self] (action, view, completionHandler) in
            self?.editSong(at: indexPath)
            completionHandler(true)
        }
        editAction.backgroundColor = UIColor.independence
        editAction.image = UIImage(systemName: "pencil")
        
        // Delete Action
        let deleteAction = UIContextualAction(style: .normal/*.destructive*/, title: "Delete") { [weak self] (action, view, completionHandler) in
            self?.deleteSong(at: indexPath)
            completionHandler(true)
        }
        deleteAction.backgroundColor = UIColor.systemPink
        deleteAction.image = UIImage(systemName: "trash")
        
        let configuration = UISwipeActionsConfiguration(actions: [deleteAction, editAction])
        configuration.performsFirstActionWithFullSwipe = true
        
        return configuration
    }
    
    private func editSong(at indexPath: IndexPath) {
        guard let parentVC = self.findViewController() else { return }
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let editVC = storyboard.instantiateViewController(withIdentifier: "EditSongViewController") as? EditSongViewController {
            editVC.songIndex = indexPath.row
            editVC.songItem = songs[indexPath.row]
            editVC.delegate = self
            
            parentVC.navigationController?.pushViewController(editVC, animated: true)
        }
    }
    
    private func deleteSong(at indexPath: IndexPath) {
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
                self.deleteRows(at: [indexPath], with: .fade)
                
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
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .none //.delete yaparsan soldan delete ikonları da gelir
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            deleteSong(at: indexPath)
        }
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
    
    // MARK: - EditSongDelegate
    
    func didUpdateSong(at index: Int) {
        // MusicPlayerEngine already handles the update and will call songsDidUpdate
        // But we can also force a refresh here to be sure
        DispatchQueue.main.async {
            // Get the updated songs list from MusicPlayerEngine
            self.songs = MusicPlayerEngine.shared.getSongList()
            
            // Optionally, reload only the specific row for better performance
            if index < self.songs.count {
                let indexPath = IndexPath(row: index, section: 0)
                if let visibleIndexPaths = self.indexPathsForVisibleRows,
                   visibleIndexPaths.contains(indexPath) {
                    self.reloadRows(at: [indexPath], with: .none)
                } else {
                    self.reloadData()
                }
            } else {
                self.reloadData()
            }
        }
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
        // UPDATE: This will be called automatically when MusicPlayerEngine updates songs
        DispatchQueue.main.async {
            self.songs = MusicPlayerEngine.shared.getSongList()
        }
    }
}

// MARK: - Document Picker Delegate

extension MusicTableView: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let parentVC = self.findViewController() else { return }
        
        let loadingAlert = UIAlertController(title: "Adding Media", message: "Please wait...", preferredStyle: .alert)
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
            
            MusicPlayerEngine.shared.addMediaFromFile(url) { success in
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
                    ? "Successfully added \(successCount) file(s)"
                    : "No files were added"
                
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
