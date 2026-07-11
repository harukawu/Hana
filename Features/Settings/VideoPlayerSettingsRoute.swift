//
//  SubtitlesSettingsRoute.swift
//  Hana
//
//  Created by Haruka on 2026/7/6.
//

import SwiftUI

enum VideoPlayerSettingsRoute: View, CaseIterable {
    case subtitles
    case mining
    
    var body: some View {
        switch self {
        case .subtitles:
            SubtitlesSettingsView()
        case .mining:
            MiningSettingsView()
        }
    }
    
    @ViewBuilder
    var label: some View {
        switch self {
        case .subtitles:
            Label("Subtitles", systemImage: "captions.bubble")
        case .mining:
            Label("Mining", systemImage: "hammer")
        }
    }
}

// MARK: - Mining settings
struct MiningSettingsView: View {
    @Environment(PersistedUserConfig.self) private var userConfig
    
    var body: some View {
        @Bindable var userConfig = userConfig
        
        Form {
            Section {
                Picker("Format", selection: $userConfig.imageOptions.format) {
                    Text("JPEG").tag(MediaExtractor.ImageFormat.jpeg)
                    Text("PNG").tag(MediaExtractor.ImageFormat.png)
                }
                
                Picker("Maximum Height", selection: $userConfig.imageOptions.maximumHeight) {
                    Text("Original").tag(Int?.none)
                    Text("480 px").tag(Int?.some(480))
                    Text("720 px").tag(Int?.some(720))
                    Text("1080 px").tag(Int?.some(1080))
                    Text("1440 px").tag(Int?.some(1440))
                }
                
                if userConfig.imageOptions.format == .jpeg {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("JPEG Quality")
                            Spacer()
                            Text("\(userConfig.imageOptions.jpegQuality)%")
                                .foregroundStyle(.secondary)
                        }
                        
                        Slider(
                            value: jpegQuality,
                            in: 0...100,
                            step: 5
                        )
                    }
                }
            } header: {
                Text("Image")
            } footer: {
                Text("Images are captured from the subtitle start time. Height limits preserve the video's aspect ratio.")
            }
            .hanaSettingsRow()
            
            Section {
                Stepper(value: $userConfig.audioOptions.bitrateKilobitsPerSecond, in: 8...320, step: 8) {
                    valueLabel(
                        title: "Bitrate",
                        value: "\(userConfig.audioOptions.bitrateKilobitsPerSecond) kbps"
                    )
                }
                
                Picker("Channels", selection: $userConfig.audioOptions.channelCount) {
                    Text("Mono").tag(1)
                    Text("Stereo").tag(2)
                }
                .pickerStyle(.segmented)
                
                Stepper(value: audioPaddingMilliseconds, in: 0...3_000, step: 50) {
                    valueLabel(
                        title: "Padding",
                        value: Self.formattedMilliseconds(audioPaddingMilliseconds.wrappedValue)
                    )
                }
            } header: {
                Text("Audio")
            } footer: {
                Text("Audio is exported as MP3. Padding adds time before and after the selected subtitle range.")
            }
            .hanaSettingsRow()
            
            Section {
                Button("Reset Mining Defaults", role: .destructive) {
                    userConfig.imageOptions = .init()
                    userConfig.audioOptions = .init()
                }
            }
            .hanaSettingsRow()
        }
        .hanaSettingsScreen()
        .navigationTitle("Mining")
    }
    
    private var jpegQuality: Binding<Double> {
        Binding {
            Double(userConfig.imageOptions.jpegQuality)
        } set: { newValue in
            userConfig.imageOptions.jpegQuality = Int(newValue)
        }
    }
    
    private var audioPaddingMilliseconds: Binding<Int> {
        Binding {
            Int(userConfig.audioOptions.padding / .milliseconds(1))
        } set: { newValue in
            userConfig.audioOptions.padding = .milliseconds(newValue)
        }
    }
    
    private func valueLabel(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
    
    private static func formattedMilliseconds(_ milliseconds: Int) -> String {
        if milliseconds >= 1_000, milliseconds.isMultiple(of: 1_000) {
            "\(milliseconds / 1_000) s"
        } else {
            "\(milliseconds) ms"
        }
    }
}

// MARK: - Subtitles settings
struct SubtitlesSettingsView: View {
    @State var userConfig = PersistedUserConfig.shared
    @State var showSubtitleServerDetailedSheet = false
    
    var body: some View {
        Form {
            Toggle(isOn: $userConfig.nativeSubtitleRendering) {
                VStack(alignment: .leading) {
                    Text("Native Subtitle Rendering")
                    
                    Text("Make subtitle tappable but remove subtitle style")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .hanaSettingsRow()
            
            if userConfig.nativeSubtitleRendering {
                Toggle(isOn: $userConfig.japaneseOnly) {
                    VStack(alignment: .leading) {
                        Text("Japanese Subtitles Only")
                        
                        Text("Subtitle cues of other languages will be removed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .hanaSettingsRow()
            }
            
            Section {
                TextField("Server URL", text: $userConfig.jimakuURL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                
                SecureField("Credential", text: $userConfig.jimakuKey)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } header: {
                Text("Subtitle Server")
            } footer: {
                Button {
                    showSubtitleServerDetailedSheet.toggle()
                } label: {
                    Text("Detail")
                        .font(.footnote)
                        .bold()
                }
            }
            .hanaSettingsRow()
        }
        .hanaSettingsScreen()
        .animation(.spring, value: userConfig.nativeSubtitleRendering)
        .navigationTitle("Subtitles")
        .sheet(isPresented: $showSubtitleServerDetailedSheet, content: { SubtitleServerDetailView() })
    }
}

struct SubtitleServerDetailView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(
                        "Hana connects only to the subtitle server you configure. "
                        + "The server must provide the compatible API below."
                    )
                } header: {
                    Text("Compatibility")
                }
                .hanaSettingsRow()
                
                Section("Connection") {
                    requirement(
                        title: "Base URL",
                        detail: "Enter an absolute HTTPS URL containing only the server origin, "
                            + "for example https://subtitles.example.com. Endpoint paths are added by Hana."
                    )
                    
                    requirement(
                        title: "Authorization",
                        detail: "Every API request includes the credential exactly as entered in the "
                            + "Authorization header. Hana does not add a Bearer prefix."
                    )
                }
                .hanaSettingsRow()
                
                Section("Required Endpoints") {
                    endpoint(
                        path: "/api/entries/search?query={title}",
                        detail: "Return HTTP 200 with a JSON array. Every entry must contain id as an "
                            + "integer, name as a string, and japanese_name as a string or null."
                    )
                    
                    endpoint(
                        path: "/api/entries/{id}/files",
                        detail: "Return HTTP 200 with a JSON array. Every file must contain name as a "
                            + "string and url as a valid URL. Hana currently supports SRT and ASS files."
                    )
                }
                .hanaSettingsRow()
                
                Section("Error Responses") {
                    Text("Hana recognizes 401 for an invalid credential and 429 for rate limiting.")
                    
                    Text(
                        "The files endpoint may also return 400 for an invalid ID or 404 when an entry "
                        + "is not found."
                    )
                    
                    Text(
                        "A 429 response may include x-ratelimit-reset-after so Hana can report when "
                        + "requests can resume."
                    )
                }
                .hanaSettingsRow()
            }
            .hanaSettingsScreen()
            .navigationTitle("Server Requirements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func requirement(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
    
    private func endpoint(path: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("GET")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            
            Text(path)
                .font(.subheadline.monospaced())
                .textSelection(.enabled)
            
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
