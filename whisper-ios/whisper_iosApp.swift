//
//  whisper_iosApp.swift
//  whisper-ios
//
//  Created by Aman Kishore on 10/20/24.
//

import SwiftUI

@main
struct whisper_iosApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    print("DEBUG: Received URL in App WindowGroup: \(url)")
                    handleURL(url)
                }
                .onChange(of: scenePhase) { newPhase in
                    print("DEBUG: Scene phase changed to: \(newPhase)")
                }
        }
    }
    
    private func handleURL(_ url: URL) {
        print("DEBUG: Processing URL in App: \(url)")
        print("DEBUG: URL components - scheme: \(url.scheme ?? "nil"), host: \(url.host ?? "nil"), path: \(url.path)")
        NotificationCenter.default.post(
            name: NSNotification.Name("ReceivedURL"),
            object: url
        )
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
        print("DEBUG: Received URL in AppDelegate: \(url)")
        NotificationCenter.default.post(name: NSNotification.Name("ReceivedURL"), object: url)
        return true
    }
}
