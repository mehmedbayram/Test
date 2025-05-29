//
//  ViewController.swift
//  CarPlayMusic
//
//  Created by Amerigo Mancino on 03/08/22.
//

import UIKit

class ViewController: UIViewController {
    
    private var titleLabel: UILabel!
    
    //Bottom Home Indicator'ini gizlemek
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
    
    var statusBarHidden = true {
        didSet {
            setNeedsStatusBarAppearanceUpdate()
        }
    }
     
    override var prefersStatusBarHidden: Bool {
        return statusBarHidden
    }
    
    //LaunchScreen süresini ve görüntülenmesini ayarlama -->
    func showLaunchScreen() {
        // ... mevcut kod ...
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        showLaunchScreen()
        setupEditableTitle()
    }
    
    // MARK: - Editable Title Setup
    
    private func setupEditableTitle() {
        // Özel bir UILabel oluşturarak title'ı gösterme
        titleLabel = UILabel()
        titleLabel.text = PlaylistTitleManager.shared.getTitle()
        titleLabel.textColor = .label
        titleLabel.font = UIFont.boldSystemFont(ofSize: 17)
        
        // Uzun başlıkları ekrana sığdırma ayarları
        titleLabel.numberOfLines = 1  // Tek satır olarak göster
        titleLabel.adjustsFontSizeToFitWidth = true  // Font büyüklüğünü otomatik ayarla
        titleLabel.minimumScaleFactor = 0.7  // En az %70 küçültme yapabilir
        titleLabel.lineBreakMode = .byTruncatingTail  // Sığmazsa sonunda "..." göster
        
        // Maximum genişlik sınırlama (navigation bar genişliğinin %70'i)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Kullanıcı etkileşimi aktif
        titleLabel.isUserInteractionEnabled = true
        
        // Uzun dokunma ve tek dokunma tanıma
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(titleLongPressed(_:)))
        longPressGesture.minimumPressDuration = 1.0
        titleLabel.addGestureRecognizer(longPressGesture)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(titleTapped(_:)))
        titleLabel.addGestureRecognizer(tapGesture)
        
        // Navigation item'a özel view olarak ekle
        let containerView = UIView()
        containerView.addSubview(titleLabel)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        // Title'ı container içinde ortalama ve maximum genişlik ayarlama
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            // Maksimum genişliği belirle (Navigation bar genişliğinin %80'i kadar)
            titleLabel.widthAnchor.constraint(lessThanOrEqualToConstant: UIScreen.main.bounds.width * 0.8),
            // Container view'ın boyutları
            containerView.widthAnchor.constraint(equalTo: titleLabel.widthAnchor),
            containerView.heightAnchor.constraint(equalTo: titleLabel.heightAnchor)
        ])
        
        self.navigationItem.titleView = containerView
        
        // viewWillLayoutSubviews çağrıldığında title genişliğini tekrar hesapla
        NotificationCenter.default.addObserver(self, selector: #selector(deviceOrientationDidChange),
                                               name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    @objc private func deviceOrientationDidChange() {
        // Ekran döndürme veya boyut değişikliğinde title'ı yeniden ayarla
        if let titleLabel = self.titleLabel {
            titleLabel.widthAnchor.constraint(lessThanOrEqualToConstant: UIScreen.main.bounds.width * 0.8).isActive = true
        }
    }
    
    @objc private func titleLongPressed(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            // Actions menüsü göster
            let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            
            // Başlığı düzenle
            alert.addAction(UIAlertAction(title: "Başlığı Düzenle", style: .default) { [weak self] _ in
                self?.showEditTitleAlert()
            })
            
            // Varsayılan başlığa sıfırla
            alert.addAction(UIAlertAction(title: "Varsayılan Başlığa Sıfırla", style: .default) { [weak self] _ in
                PlaylistTitleManager.shared.resetToDefault()
                self?.titleLabel.text = PlaylistTitleManager.shared.getTitle()
            })
            
            // Tüm başlığı göster (pop-up içinde)
            if let title = titleLabel.text, title.count > 25 {
                alert.addAction(UIAlertAction(title: "Tüm Başlığı Göster", style: .default) { [weak self] _ in
                    let fullAlert = UIAlertController(title: "Şarkı Listesi Başlığı", message: title, preferredStyle: .alert)
                    fullAlert.addAction(UIAlertAction(title: "Tamam", style: .default))
                    self?.present(fullAlert, animated: true)
                })
            }
            
            // İptal
            alert.addAction(UIAlertAction(title: "İptal", style: .cancel))
            
            // iPad uyumluluğu için
            if let popoverController = alert.popoverPresentationController {
                popoverController.sourceView = titleLabel
                popoverController.sourceRect = titleLabel.bounds
            }
            
            present(alert, animated: true)
        }
    }
    
    @objc private func titleTapped(_ gesture: UITapGestureRecognizer) {
        // Tek dokunma ile direkt düzenleme göster
        showEditTitleAlert()
    }
    
    private func showEditTitleAlert() {
        let alert = UIAlertController(title: "Başlığı Düzenle", message: nil, preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.text = PlaylistTitleManager.shared.getTitle()
            textField.clearButtonMode = .whileEditing
            textField.autocapitalizationType = .sentences
        }
        
        alert.addAction(UIAlertAction(title: "İptal", style: .cancel))
        alert.addAction(UIAlertAction(title: "Kaydet", style: .default) { [weak self] _ in
            if let newTitle = alert.textFields?.first?.text, !newTitle.isEmpty {
                PlaylistTitleManager.shared.setTitle(newTitle)
                self?.titleLabel.text = newTitle
            }
        })
        
        present(alert, animated: true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Title'ı her zaman güncel tut
        titleLabel?.text = PlaylistTitleManager.shared.getTitle()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
    }
}
