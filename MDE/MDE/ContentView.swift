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
            editorEngine: appModel.editorEngine,
            previewEngine: appModel.previewEngine
        )
    }
}
