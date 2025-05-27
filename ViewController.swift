//
//  ViewController.swift
//  CarPlayMusic
//
//  Created by Amerigo Mancino on 03/08/22.
//

import UIKit

class ViewController: UIViewController {
    
    //Bottom Home Indicator'ini gizlemek
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
    
  //  override var prefersStatusBarHidden: Bool {
  //    return true
  //  }
    
    //Statusbar'ı dinamik olarak gizleyip göstermek : https://stackoverflow.com/a/59275412/17644163 -->
    //https://medium.com/@craiggrummitt/the-mysterious-case-of-the-status-bar-d9059a327c97
    
    var statusBarHidden = true {
      didSet {
        setNeedsStatusBarAppearanceUpdate()
      }
    }
     

    override var prefersStatusBarHidden: Bool {
      return statusBarHidden
    }
    //https://medium.com/@craiggrummitt/the-mysterious-case-of-the-status-bar-d9059a327c97
    //Statusbar'ı dinamik olarak gizleyip göstermek : https://stackoverflow.com/a/59275412/17644163 <--
    
    //LaunchScreen süresini ve görüntülenmesini ayarlama -->
    func showLaunchScreen() {
        let launchScreen = UIStoryboard(name: "LaunchScreen", bundle: nil)
        let launchView = launchScreen.instantiateInitialViewController()
  //        launchView?.view.addSubview(image)
        self.view.addSubview(launchView!.view)
        launchView?.view.layer.zPosition = 104
        self.navigationController?.setNavigationBarHidden(true, animated: true) //Navigationbar'ı gizle
        //Uygulamayı 1 saniye bekletmek -->
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { //Launchscreen görüntülenme süresi
          
  //        self.statusBarHidden.toggle() //Statusbar'ı dinamik olarak gizleyip göstermek
          self.statusBarHidden = false
            self.navigationController?.setNavigationBarHidden(false, animated: true) //Navigationbar'ı gizle
            UIView.animate(withDuration: 0.1, animations: { //Launchscreen kaybolma animasyonunun süresi
                        launchView?.view.alpha = 0.0
                        }) { _ in
                            launchView!.view.removeFromSuperview()
                    }
        }
    }
    //LaunchScreen süresini ve görüntülenmesini ayarlama <--
    

    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        

        
        showLaunchScreen()
        
    }
}

