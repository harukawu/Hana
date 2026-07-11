//
//  JimakuSearchView.swift
//  Hana
//
//  Created by Haruka on 2026/7/6.
//

import SwiftUI

fileprivate enum JimakuSearchViewError: LocalizedError {
    case unsupportedSubtitle
    
    var errorDescription: String? {
        switch self {
        case .unsupportedSubtitle:
            return "Current Subtitle is not supported"
        }
    }
}

struct JimakuSearchView: View {
    let supportedSubtitles: [String] = ["srt", "ass"]
    let initialQuery: String?
    let onFileSelected: (URL) -> Void
    
    @State private var searchQuery = ""
    @State private var searchResults: [JimakuSearchResult] = []
    @State private var subtitleFiles: [JimakuSubtitleFile] = []
    @State private var selectedResult: JimakuSearchResult?
    @State private var isSearching = false
    @State private var isLoadingFiles = false
    @State private var errorMessage: String?
    @State private var showAlert: Bool = false
    @State private var alertError: JimakuSearchViewError? = nil
    
    @Environment(PersistedUserConfig.self) private var userConfig
    @Environment(\.dismiss) private var dismiss
    
    init(initialQuery: String?, onFileSelected: @escaping (URL) -> Void) {
        self._searchQuery = State(wrappedValue: initialQuery ?? "")
        self.initialQuery = initialQuery
        self.onFileSelected = onFileSelected
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if let selected = selectedResult {
                    filesListContent(for: selected)
                } else {
                    searchContent
                }
            }
            .navigationTitle(selectedResult?.displayName ?? "Subtitles", if: selectedResult == nil)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if selectedResult != nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            withAnimation {
                                selectedResult = nil
                                subtitleFiles = []
                                errorMessage = nil
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Results")
                            }
                        }
                    }
                }
            }
        }
        .onAppear(perform: performSearch)
        .alert(isPresented: $showAlert, error: alertError, actions: {
            Button("OK") { alertError = nil}
        })
    }
}

// MARK: - Search

extension JimakuSearchView {
    
    private var searchContent: some View {
        Group {
            if isSearching {
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                EmptyStateView(
                    icon: "exclamationmark.triangle.fill",
                    iconColor: .orange,
                    title: "Search Failed",
                    subtitle: errorMessage
                )
            } else if !searchResults.isEmpty {
                searchResultsList
            } else {
                EmptyStateView(
                    icon: "doc.questionmark.fill",
                    iconColor: .secondary,
                    title: "No Files Found",
                    subtitle: "No subtitle files available for this entry"
                )
            }
        }
        .searchable(
            text: $searchQuery,
            placement: .toolbar,
            prompt: "Subtitle title"
        )
        .searchToolbarBehavior(.minimize)
        .onSubmit(of: .search) {
            performSearch()
        }
    }
    
    private var searchResultsList: some View {
        List {
            ForEach(searchResults) { (result: JimakuSearchResult) in
                Button {
                    selectResult(result)
                } label: {
                    searchResultRow(result)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    private func searchResultRow(_ result: JimakuSearchResult) -> some View {
        HStack(spacing: 14) {
            resultIcon
            
            VStack(alignment: .leading, spacing: 2) {
                Text(result.displayName)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                
                if let jaName = result.jaName, jaName != result.name {
                    Text(result.name)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
    }
    
    @ViewBuilder
    private var resultIcon: some View {
        Image(systemName: "folder.fill")
            .font(.system(size: 22, weight: .medium))
            .foregroundStyle(.blue)
            .frame(width: 40, height: 40)
    }
}

// MARK: - Files List

extension JimakuSearchView {
    
    private func filesListContent(for result: JimakuSearchResult) -> some View {
        Group {
            if isLoadingFiles {
                ProgressView()
                    .controlSize(.large)
            } else if let errorMessage {
                EmptyStateView(
                    icon: "exclamationmark.triangle.fill",
                    iconColor: .orange,
                    title: "Unable to Load",
                    subtitle: errorMessage
                )
            } else if subtitleFiles.isEmpty {
                EmptyStateView(
                    icon: "doc.questionmark.fill",
                    iconColor: .secondary,
                    title: "No Files Found",
                    subtitle: "No subtitle files available for this entry"
                )
            } else {
                filesList
            }
        }
    }
    
    private var filesList: some View {
        List {
            ForEach(subtitleFiles) { (file: JimakuSubtitleFile) in
                Button {
                    if supportedSubtitles.contains(where: {$0 == file.url.pathExtension.lowercased()}) {
                        onFileSelected(file.url)
                        dismiss()
                    } else {
                        showAlert = true
                        alertError = JimakuSearchViewError.unsupportedSubtitle
                    }
                } label: {
                    fileRow(file)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    private func fileRow(_ file: JimakuSubtitleFile) -> some View {
        HStack(spacing: 14) {
            fileIcon(for: file)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name.deletingPathExtension)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
//                    .lineLimit(2)

                let ext = file.url.pathExtension.uppercased()
                if !ext.isEmpty {
                    Text(ext)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.tertiarySystemFill), in: Capsule())
                }
            }
            
            Spacer()
            
            Image(systemName: "arrow.down.circle")
                .font(.body.weight(.medium))
                .foregroundStyle(Color.accentColor)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
    }
    
    @ViewBuilder
    private func fileIcon(for file: JimakuSubtitleFile) -> some View {
        let ext = file.url.pathExtension.lowercased()
        let iconName: String = switch ext {
        case "srt", "ass", "vtt": "captions.bubble.fill"
        default: "doc.text.fill"
        }
        let iconColor: Color = switch ext {
        case "srt", "ass", "vtt": .orange
        default: .gray
        }
        
        Image(systemName: iconName)
            .font(.system(size: 22, weight: .medium))
            .foregroundStyle(iconColor)
            .frame(width: 40, height: 40)
    }
}

// MARK: - Actions

extension JimakuSearchView {
    
    private func performSearch() {
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        isSearching = true
        errorMessage = nil
        searchResults = []
        
        Task {
            do {
                let jimakuManager = try JimakuManager(endpoint: userConfig.jimakuURL, apiKey: userConfig.jimakuKey)
                let results = try await jimakuManager.search(title: query)
                searchResults = results
            } catch {
                errorMessage = error.localizedDescription
            }
            isSearching = false
        }
    }
    
    private static let subtitleExtensions: Set<String> = ["ass", "srt", "ssa", "vtt", "sup"]
    
    private func sortFiles(_ files: [JimakuSubtitleFile]) -> [JimakuSubtitleFile] {
        files.sorted { a, b in
            let aExt = a.url.pathExtension.lowercased()
            let bExt = b.url.pathExtension.lowercased()
            let aIsSrt = aExt == "srt"
            let bIsSrt = bExt == "srt"
            if aIsSrt && !bIsSrt { return true }
            if !aIsSrt && bIsSrt { return false }
            let aIsSub = Self.subtitleExtensions.contains(aExt)
            let bIsSub = Self.subtitleExtensions.contains(bExt)
            if aIsSub && !bIsSub { return true }
            if !aIsSub && bIsSub { return false }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
    }
    
    private func selectResult(_ result: JimakuSearchResult) {
        selectedResult = result
        isLoadingFiles = true
        errorMessage = nil
        subtitleFiles = []
        
        Task {
            do {
                let jimakuManager = try JimakuManager(endpoint: userConfig.jimakuURL, apiKey: userConfig.jimakuKey)
                let files = try await jimakuManager.getFilesList(of: result.id)
                subtitleFiles = sortFiles(files)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoadingFiles = false
        }
    }
}

// MARK: - Helpers

private extension String {
    var deletingPathExtension: String {
        guard let dotIndex = lastIndex(of: ".") else { return self }
        return String(self[startIndex..<dotIndex])
    }
}
