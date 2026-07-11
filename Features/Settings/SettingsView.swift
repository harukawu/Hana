//
//  SettingsView.swift
//  Hana
//
//  Created by Haruka on 2026/7/6.
//

import SwiftUI

enum AppSettingsRoute: Hashable, CaseIterable, View {
    case about
    
    var body: some View {
        switch self {
        case .about:
            AboutView()
        }
    }
    
    @ViewBuilder
    var label: some View {
        switch self {
        case .about:
            Label("About", systemImage: "info.circle")
        }
    }
}

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(DictionarySettingsRoute.allCases, id: \.self) { route in
                        NavigationLink(value: route, label: { route.label })
                    }
                } header: {
                    Text("Dictionaries")
                }
                .hanaSettingsRow()
                
                Section {
                    ForEach(VideoPlayerSettingsRoute.allCases,id: \.self) { route in
                        NavigationLink(value: route, label: { route.label })
                    }
                } header: {
                    Text("Video Player")
                }
                .hanaSettingsRow()
                
                #if DEBUG
                Section {
                    ForEach(WebStorageSettingsRoute.allCases, id: \.self) { route in
                        NavigationLink(value: route, label: { route.label })
                    }
                } header: {
                    Text("Web Storage")
                }
                .hanaSettingsRow()
                #endif
                
                Section {
                    ForEach(AppSettingsRoute.allCases, id: \.self) { route in
                        NavigationLink(value: route, label: { route.label })
                    }
                }
                .hanaSettingsRow()
            }
            .listStyle(.insetGrouped)
            .hanaSettingsScreen()
            .navigationTitle("Settings")
            .navigationDestination(for: DictionarySettingsRoute.self, destination: { $0 })
            .navigationDestination(for: WebStorageSettingsRoute.self, destination: { $0 })
            .navigationDestination(for: VideoPlayerSettingsRoute.self, destination: { $0 })
            .navigationDestination(for: AppSettingsRoute.self, destination: { $0 })
        }
    }
}

#Preview {
    SettingsView()
}
