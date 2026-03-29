//
//  MDEApp.swift
//  MDE
//
//  Created by Billy on 29/03/2026.
//

import SwiftUI

@main
struct MDEApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appModel)
        }
        .commands {
            AppCommands(appModel: appModel)
        }
    }
}
