//
//  EditSongViewController.swift
//  CarPlayMusic
//
//  Created by mehmedbayram on 25/05/25.
//

import UIKit
import AVFoundation
import AVKit

protocol EditSongDelegate: AnyObject {
    func didUpdateSong(at index: Int)
    func editViewControllerWillDisappear() // YENİ METOD
}

class EditSongViewController: UIViewController {
    
    @IBOutlet weak var titleTextField: UITextField!
    @IBOutlet weak var authorTextField: UITextField!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var changeImageButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    
    var songIndex: Int = -1
    var songItem: SongItem?
    weak var delegate: EditSongDelegate?
    
    let generator = UIImpactFeedbackGenerator(style: .soft)
    
    // YENİ METOD - viewDidDisappear
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        generator.prepare()
        generator.impactOccurred(intensity: 1.0)
        
        saveTapped("" as AnyObject)
        
        // Delegate'e haber ver ki doSomething çalışsın
        delegate?.editViewControllerWillDisappear()
        
        print("EditSongViewController disappeared - delegate called")
    }
    
    //İstenen view'e Dokunulduğunda yapılacaklar
    @objc func tapped(sender: UITapGestureRecognizer){
        print("tapped")
        txtTitleOutlet.resignFirstResponder()
        txtAuthorOutlet.resignFirstResponder()
 
    }
    @IBOutlet weak var txtTitleOutlet: UITextField!
    @IBOutlet weak var txtAuthorOutlet: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Tek dokunuşta yapılacaklar
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapped))
        view.addGestureRecognizer(tapGestureRecognizer)
        //Tek dokunuşta yapılacaklar
        
        setupUI()
        loadSongData()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.txtTitleOutlet.becomeFirstResponder()
        }
    }
    
    private func setupUI() {
        title = "Edit Song"
        
        // Setup image view
        imageView.layer.cornerRadius = 50
        imageView.clipsToBounds = true
//        imageView.contentMode = .scaleAspectFill
        
        // Setup buttons
        changeImageButton.layer.cornerRadius = 8
        saveButton.layer.cornerRadius = 8
        cancelButton.layer.cornerRadius = 8
        
        // Setup text fields
        titleTextField.borderStyle = .roundedRect
        authorTextField.borderStyle = .roundedRect
    }
    
    private func loadSongData() {
        guard let song = songItem else { return }
        
        titleTextField.text = song.title
        authorTextField.text = song.author
        imageView.image = song.image
    }
    
    @IBAction func changeImageTapped(_ sender: UIButton) {
        let alert = UIAlertController(title: "Change Image", message: "Choose an option", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Photo Library", style: .default) { _ in
            self.openImagePicker()
        })
        
        alert.addAction(UIAlertAction(title: "Default Music Icon", style: .default) { _ in
            self.setDefaultMusicIcon()
        })
        
        alert.addAction(UIAlertAction(title: "Extract from Video", style: .default) { _ in
            self.extractVideoThumbnail()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = sender
            popover.sourceRect = sender.bounds
        }
        
        present(alert, animated: true)
    }
    
    private func openImagePicker() {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        present(picker, animated: true)
    }
    
    private func setDefaultMusicIcon() {
        if let defaultImage = UIImage(systemName: "music.note") {
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 200))
            let coloredImage = renderer.image { context in
                UIColor.independence.setFill()
                context.fill(CGRect(origin: .zero, size: CGSize(width: 200, height: 200)))
                
                let imageRect = CGRect(x: 50, y: 50, width: 100, height: 100)
                UIColor.white.setFill()
                defaultImage.withTintColor(.white).draw(in: imageRect)
            }
            imageView.image = coloredImage
        }
    }
    
    private func extractVideoThumbnail() {
        guard let song = songItem else { return }
        
        // Check if it's a video file
        let videoExtensions = ["mp4", "mov", "avi", "mkv", "m4v", "3gp"]
        let fileExtension = song.url.pathExtension.lowercased()
        
        if videoExtensions.contains(fileExtension) {
            let asset = AVAsset(url: song.url)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            
            let time = CMTime(seconds: 1.0, preferredTimescale: 600)
            
            do {
                let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                let thumbnail = UIImage(cgImage: cgImage)
                imageView.image = thumbnail
            } catch {
                print("Error generating thumbnail: \(error)")
                showAlert(message: "Could not extract thumbnail from video")
            }
        } else {
            showAlert(message: "This is not a video file")
        }
    }
    
    @IBAction func saveTapped(_ sender: AnyObject) {
        guard let title = titleTextField.text, !title.isEmpty,
              let author = authorTextField.text, !author.isEmpty,
              let image = imageView.image,
              let song = songItem else {
            showAlert(message: "Please fill all fields")
            return
        }
        
        // Update CoreData
        let success = CoreDataManager.shared.updateSong(
            withId: song.id,
            title: title,
            author: author,
            imageData: image.jpegData(compressionQuality: 0.8)
        )
        
        if success {
            delegate?.didUpdateSong(at: songIndex)
            navigationController?.popViewController(animated: true)
        } else {
            showAlert(message: "Failed to save changes")
        }
    }
    
    @IBAction func cancelTapped(_ sender: UIButton) {
        navigationController?.popViewController(animated: true)
    }
    
    private func showAlert(message: String) {
        let alert = UIAlertController(title: "Info", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UIImagePickerControllerDelegate

extension EditSongViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let editedImage = info[.editedImage] as? UIImage {
            imageView.image = editedImage
        } else if let originalImage = info[.originalImage] as? UIImage {
            imageView.image = originalImage
        }
        picker.dismiss(animated: true)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}
