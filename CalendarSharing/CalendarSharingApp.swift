//
//  CalendarSharingApp.swift
//  CalendarSharing
//
//  Created by Domantas Jocas on 13/11/2025.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth


class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
        
}

@main
struct CalendarSharingApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var isLoggedIn: Bool = false
    @StateObject var authVM = AuthenticationViewModel()
    @StateObject var currentUser = CurrentUser.shared

    var body: some Scene {
        WindowGroup {
          NavigationView {
            AuthenticatedView {
            } content: {
                HomeView()
                    .task {
                        await authVM.loadCurrentUserIfNeeded()
                    }.environmentObject(authVM)
                    .environmentObject(currentUser)
            }.environmentObject(authVM)
            .environmentObject(currentUser)
          }
        }
      }
}
