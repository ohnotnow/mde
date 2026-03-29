//
//  MDEApp.swift
//  MDE
//
//  Created by Billy on 29/03/2026.
//

import SwiftUI

@main
struct MDEApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appModel)
                .task {
                    appDelegate.appModel = appModel
                }
        }
        .commands {
            AppCommands(appModel: appModel)
        }

        Settings {
            SettingsView()
                .environmentObject(appModel)
        }
    }
}
