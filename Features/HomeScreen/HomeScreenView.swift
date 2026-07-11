//
//  HomeScreenView.swift
//  Hana
//
//  Created by Haruka on 2026/7/6.
//

import SwiftUI

struct HomeScreenView: View {
    
    var body: some View {
        TabView {
            Tab("Media", systemImage: "play.rectangle.on.rectangle.fill", content: { FileBrowserScreen(rootURL: try! FileStorage.getVideosDirectory()) })
            
            Tab("Settings", systemImage: "gearshape", content: { SettingsView() })
        }
        .tint(.primary)
    }
}

#Preview {
    HomeScreenView()
}
