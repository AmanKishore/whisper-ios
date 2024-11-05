//
//  SceneDelegate.swift
//  whisper-keyboard
//
//  Created by Aman Kishore on 11/3/24.
//

import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        print("DEBUG: SceneDelegate received URL contexts")
        guard let url = URLContexts.first?.url else {
            print("DEBUG: No URL found in context")
            return
        }
        print("DEBUG: SceneDelegate handling URL: \(url)")
        NotificationCenter.default.post(name: NSNotification.Name("ReceivedURL"), object: url)
    }
}