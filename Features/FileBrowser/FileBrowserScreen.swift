//
//  FileBrowserScreen.swift
//  Hana
//
//  Created by Haruka on 2026/7/6.
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import OSLog

public struct FileBrowserScreen: View {
    private let rootURL: URL
    @Query(sort: \VideoHistory.modificationDate, order: .reverse) private var histories: [VideoHistory]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var userConfig = PersistedUserConfig.shared
    @State private var path = NavigationPath()
    @State private var showFileImporter: Bool = false
    @State private var refreshTrigger: UUID = UUID()
    @State private var selectedWebDAVSource: WebDavSource? = nil
    
    // we tried to use this to scroll back to leading when exiting from video.
    // However, there is several frame drop. Good job Apple.
//    @State private var horizontalScrollPosition = ScrollPosition(idType: UUID.self)
    
    public var body: some View {
        GeometryReader { geometry in
            NavigationStack(path: $path) {
                FileBrowserView(
                    currentURL: selectedWebDAVSource?.url ?? rootURL,
                    webDAVSource: selectedWebDAVSource,
                    refreshTrigger: refreshTrigger,
                    hasHeader: !histories.isEmpty
                ) {
                    historyScrollView(geometry: geometry)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                .id(refreshTrigger)
                .toolbar { toolbar }
                .onChange(of: selectedWebDAVSource) { _, _ in
                    refreshTrigger = UUID()
                }
                .onChange(of: scenePhase) { oldValue, newValue in
                    if oldValue == .background {
                        refreshTrigger = UUID()
                    }
                }
                .fileImporter(
                    isPresented: $showFileImporter,
                    allowedContentTypes: [.data, .folder],
                    onCompletion: onImportFiles
                )
                .navigationDestination(for: AnyFile.self) { anyFile in
                    let file = anyFile.file
                    if file.isDirectory {
                        FileBrowserView(currentURL: file.url, webDAVSource: selectedWebDAVSource, refreshTrigger: nil)
                    } else {
                        let item = VideoItem.getVideoItem(from: file.url, modelContext: modelContext)
                        VideoPlayerView(item: item)
                            .toolbarVisibility(.hidden, for: .tabBar)
                            .toolbarVisibility(.hidden, for: .automatic)
                            .tint(.accent)
                    }
                }
                .navigationDestination(for: VideoItem.self) { item in
                    // before being pushed here, the bookmark data has been resolved
                    VideoPlayerView(item: item)
                        .toolbarVisibility(.hidden, for: .tabBar)
                        .toolbarVisibility(.hidden, for: .automatic)
                        .tint(.accent)
                }
            }
        }
    }
    
    init(rootURL: URL) {
        self.rootURL = rootURL
    }
}

// MARK: - toolbar
extension FileBrowserScreen {
    @ToolbarContentBuilder
    var toolbar: some ToolbarContent {
        
        #if DEBUG
        ToolbarItem(placement: .topBarTrailing) {
            Menu("", systemImage: "externaldrive.connected.to.line.below") {
                Picker("", selection: $selectedWebDAVSource) {
                    Text("Local Files").tag(nil as WebDavSource?)
                    ForEach(userConfig.webDavSources, id: \.name) { webDAVSource in
                        if webDAVSource.isEnabled {
                            Text(webDAVSource.name).tag(webDAVSource)
                        }
                    }
                }
            }
        }
        #endif
        
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showFileImporter = true
            } label: {
                Image(systemName: "plus")
            }
        }
        
    }
}

// MARK: - Recent videos
extension FileBrowserScreen {
    @ViewBuilder
    func historyScrollView(geometry: GeometryProxy) -> some View {
        if !histories.isEmpty {
            let maxHeight = geometry.size.height / 4
            HistoryCollectionView(
                histories: histories,
                maxHeight: maxHeight,
                maxWidth: geometry.size.width * 0.72,
                onOpen: openHistory,
                onDelete: deleteHistory
            )
            .frame(height: HistoryCollectionView.preferredHeight(maxHeight: maxHeight))
        }
    }
    
    private func openHistory(_ history: VideoHistory) {
        var isStale = false
        guard let resolvedURL = try? URL(resolvingBookmarkData: history.urlBookmark, bookmarkDataIsStale: &isStale),
              !isStale else {
            modelContext.delete(history)
            withAnimation(.bouncy) {
                try? modelContext.save()
            }
            return
        }
        if resolvedURL != history.url {
            history.url = resolvedURL
        }
        path.append(history.toItem())
    }
    
    private func deleteHistory(_ history: VideoHistory) {
        withAnimation(.bouncy) {
            modelContext.delete(history)
        }
    }
    
}

// MARK: - helper methods for FileBrowserScreen
extension FileBrowserScreen {
    
    var supportedVideoType: [UTType] {
        var supportedTypes = ["mp4", "mkv", "mov", "avi", "m4v", "webm"].map { supportedTypeStr in
            UTType(filenameExtension: supportedTypeStr)!
        }
        supportedTypes.append(.folder)
        return supportedTypes
    }
    
    func onImportFiles(result: Result<URL, any Error>) -> Void {
        switch result {
        case .success(let file):
            let accessFlag = file.startAccessingSecurityScopedResource()
            guard accessFlag else {
                Logger.fileStorage.log("Failed to access files in \(file) when importing files to videos directory")
                return
            }
            let item = VideoItem.getVideoItem(from: file, modelContext: modelContext)
            path.append(item)
        case .failure(let error):
            Logger.fileStorage.log("Failed to import files to videos directory: \(error, privacy: .public)")
        }
    }
    
    
}
