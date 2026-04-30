//
//  ContentView.swift
//  MDE
//
//  Created by Billy on 29/03/2026.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        WorkspaceView(
            document: $appModel.document,
            settings: $appModel.settings,
            onOpenDroppedFile: appModel.openDroppedDocument(at:)
        )
        .onOpenURL { url in
            appModel.openDocument(at: url)
        }
        .alert(
            "Unable to complete action",
            isPresented: alertIsPresented,
            actions: {
                Button("OK") {
                    appModel.dismissAlert()
                }
            },
            message: {
                Text(appModel.alertMessage ?? "An unknown error occurred.")
            }
        )
    }

    private var alertIsPresented: Binding<Bool> {
        Binding(
            get: { appModel.alertMessage != nil },
            set: { isPresented in
                if !isPresented {
                    appModel.dismissAlert()
                }
            }
        )
    }
}
