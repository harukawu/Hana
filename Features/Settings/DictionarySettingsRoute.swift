//
//  DictionarySettingsRoute.swift
//  Hana
//
//  Created by Haruka on 2026/7/10.
//

import HoshiReader
import SwiftUI

enum DictionarySettingsRoute: Hashable, CaseIterable, View {
    case dictionaries
    case appearance
    case anki
    case advanced
    
    var body: some View {
        switch self {
        case .dictionaries:
            HoshiReader::DictionaryView()
        case .appearance:
            HoshiReader::HoshiAppearanceView()
        case .anki:
            HoshiReader::AnkiView()
        case .advanced:
            DictionaryAdvancedSettingsView()
        }
    }
    
    @ViewBuilder
    var label: some View {
        switch self {
        case .dictionaries:
            Label("Dictionaries", systemImage: "character.book.closed.ja")
        case .appearance:
            Label("Appearance", systemImage: "paintpalette")
        case .anki:
            Label("Anki", systemImage: "tray.full")
        case .advanced:
            Label("Advanced", systemImage: "gearshape.2")
        }
    }
}

enum DictionaryAdvancedSettingsRoute: CaseIterable, View {
    case dictAudio
    case ankiconnect
    case backup
    
    var body: some View {
        switch self {
        case .dictAudio:
            HoshiReader::AudioView()
        case .ankiconnect:
            HoshiReader::AnkiConnectView()
        case .backup:
            HoshiReader::HoshiBackupView()
        }
    }
    
    @ViewBuilder
    var label: some View {
        switch self {
        case .dictAudio:
            Label("Audio", systemImage: "speaker.wave.2")
        case .ankiconnect:
            Label("AnkiConnect", systemImage: "app.connected.to.app.below.fill")
        case .backup:
            Label("Backup", systemImage: "externaldrive")
        }
    }
}

struct DictionaryAdvancedSettingsView: View {
    var body: some View {
        List {
            ForEach(DictionaryAdvancedSettingsRoute.allCases, id: \.self) { route in
                Section {
                    NavigationLink(destination: { route }, label: { route.label })
                }
                .hanaSettingsRow()
            }
        }
        .navigationTitle("Advanced")
        .hanaSettingsScreen()
    }
}
