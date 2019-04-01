//
//  AppDelegate.swift
//  Drop Memory
//
//  Created by Marie Kristein-Harmsen on 2019/04/01.
//  Copyright © 2019 DVT. All rights reserved.
//
import UIKit
import Firebase

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

