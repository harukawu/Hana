//
//  WebStorageSettingsRoute.swift
//  Hana
//
//  Created by Haruka on 2026/7/6.
//

import SwiftUI

enum WebStorageSettingsRoute: CaseIterable, View {
    case webDav
    
    var body: some View {
        switch self {
        case .webDav:
            WebDAVSettingsView()
        }
    }
    
    @ViewBuilder
    var label: some View {
        Label("WebDAV", systemImage: "externaldrive.connected.to.line.below")
    }
}


struct WebDAVSettingsView: View {
    @State var userConfig = PersistedUserConfig.shared
    
    @State var webDavName: String = ""
    @State var webDavPath: String = ""
    @State var webDavUserName: String = ""
    @State var webDavPassword: String = ""
    @State var showAlert: Bool = false
    @State var addWebDAVError: WebDAVError? = nil
    
    var body: some View {
        Form {
            if !userConfig.webDavSources.isEmpty {
                Section("WebDav Sources") {
                    ForEach(Array(userConfig.webDavSources.enumerated()), id: \.offset) { index, source in
                        Toggle(isOn: Binding(get: {
                            source.isEnabled
                        }, set: { newValue in
                            userConfig.webDavSources[index].isEnabled = newValue
                        })) {
                            VStack(alignment: .leading) {
                                Text(source.name)
                                    .lineLimit(1)
                                    .contentTransition(.identity)
                                Text(source.url.absoluteString)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .contentTransition(.identity)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        userConfig.webDavSources.remove(atOffsets: indexSet)
                    }
                    .onMove { indexSet, newIndex in
                        userConfig.webDavSources.move(fromOffsets: indexSet, toOffset: newIndex)
                    }
                }
                .hanaSettingsRow()
            }
            
            Section("Add WebDav Sources") {
                TextField("Display Name", text: $webDavName)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                TextField("URL: https://", text: $webDavPath)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                TextField("UserName", text: $webDavUserName)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                HStack {
                    TextField("Password", text: $webDavPassword)
                    Spacer()
                    Button {
                        do {
                            try addWebdavSource()
                        } catch {
                            showAlert = true
                            addWebDAVError = error as? WebDAVError
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(webDavPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || webDavName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .buttonStyle(.plain)
                }
            }
            .hanaSettingsRow()
        }
        .hanaSettingsScreen()
    }
    
    private func addWebdavSource() throws {
        let webDavName = webDavName.trimmingCharacters(in: .whitespacesAndNewlines)
        let webDavPath = webDavPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let webDavURL = URL(string: webDavPath) else {
            throw WebDAVError.invalidPath(webDavPath)
        }
        if webDavName.isEmpty || webDavPath.isEmpty {
            throw WebDAVError.invalidWebDAV
        }
        let newSource = WebDavSource(name: webDavName, url: webDavURL, username: webDavUserName, password: webDavPassword, isEnabled: true)
        withAnimation {
            userConfig.webDavSources.append(newSource)
        }
        resetWebdavInput()
    }
    
    private func resetWebdavInput() {
        webDavName = ""
        webDavPath = ""
        webDavUserName = ""
        webDavPassword = ""
    }
}
