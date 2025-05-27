//
//  AppDelegate.swift
//  CarPlayTest1
//
//  Created by Amerigo Mancino on 03/08/22.
//

import UIKit
import AVFoundation

import CoreData


@main
class AppDelegate: UIResponder, UIApplicationDelegate {



    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        UIScrollView.appearance().showsVerticalScrollIndicator = false
        UIScrollView.appearance().showsHorizontalScrollIndicator = false
        
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(AVAudioSession.Category.playback/*, mode: .moviePlayback*/)
            try audioSession.setActive(true, options: [])
            UIApplication.shared.beginReceivingRemoteControlEvents() //Now Playing //Kilitli ekrandan ve Dynamik island'dan kontrol vs için
        } catch  {
            print("Audio session failed")
        }
        
        // Initialize Core Data
        _ = CoreDataManager.shared.persistentContainer
        
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate.
        CoreDataManager.shared.saveContext()
    }

}

