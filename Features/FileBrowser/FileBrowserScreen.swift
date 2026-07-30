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
    @Query private var miningHistories: [MiningHistory]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(UserConfig.self) private var userConfig
    @Environment(MiningHistoryCoordinator.self) private var miningHistoryCoordinator
    @State private var path = NavigationPath()
    @State private var showFileImporter: Bool = false
    @State private var refreshTrigger: UUID = UUID()
    @State private var selectedWebDAVSource: WebDavSource? = nil

    @State private var showVideoHistoryUnavailableAlert = false
    @State private var unavailableVideoHistory: VideoHistory? = nil

    @State private var showMiningHistoryAlert = false

    // we tried to use this to scroll back to leading when exiting from video.
    // However, there is several frame drop. Good job Apple.
//    @State private var horizontalScrollPosition = ScrollPosition(idType: UUID.self)

    public var body: some View {
        @Bindable var miningHistoryCoordinator = miningHistoryCoordinator

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
                .task {
                    try? clearHistories()
                    try? clearCaches()
                    try? await resolveMismatchedURLs()
                }
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
                        VideoPlayerView(item: item, userConfig: userConfig)
                            .toolbarVisibility(.hidden, for: .tabBar)
                            .toolbarVisibility(.hidden, for: .automatic)
                            .tint(.accent)
                    }
                }
                .navigationDestination(for: VideoItem.self) { item in
                    // before being pushed here, the bookmark data has been resolved
                    VideoPlayerView(item: item, userConfig: userConfig)
                        .toolbarVisibility(.hidden, for: .tabBar)
                        .toolbarVisibility(.hidden, for: .automatic)
                        .tint(.accent)
                }
                .alert(
                    "Error",
                    isPresented: $showVideoHistoryUnavailableAlert,
                    actions: {
                        Button("Cancel", role: .cancel) {
                            unavailableVideoHistory = nil
                        }

                        Button("Delete", role: .destructive) {
                            if let unavailableVideoHistory {
                                deleteHistory(unavailableVideoHistory)
                            }
                            unavailableVideoHistory = nil
                        }
                    },
                    message: {
                        if let unavailableVideoHistory {
                            Text("Video \(unavailableVideoHistory.displayTitle) is moved or deleted.")
                        } else {
                            Text("Current video is moved or deleted.")
                        }
                    }
                )
                .alert(
                    "Mining",
                    isPresented: $miningHistoryCoordinator.isPendingAlertPresented,
                    actions: {
                        Button("Cancel", role: .cancel) {}

                        Button("Delete", role: .destructive) {
                            miningHistoryCoordinator.deletePending(in: modelContext)
                        }

                        Button("Retry", role: .confirm) {
                            miningHistoryCoordinator.retryPending(in: modelContext)
                        }
                        .buttonStyle(.borderedProminent)
                    },
                    message: {
                        Text("There is a pending mining history which might fail to be added to Anki")
                    }
                )
                .alert(
                    "Error",
                    isPresented: $miningHistoryCoordinator.isErrorAlertPresented,
                    actions: {
                        Button("Cancel", role: .cancel) {
                            miningHistoryCoordinator.dismissError()
                        }

                        if miningHistoryCoordinator.unavailableHistoryID != nil {
                            Button("Delete", role: .destructive) {
                                miningHistoryCoordinator.deleteUnavailable(in: modelContext)
                            }

                            Button("Retry", role: .confirm) {
                                miningHistoryCoordinator.retryUnavailable(in: modelContext)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    },
                    message: {
                        Text(miningHistoryCoordinator.errorMessage)
                    }
                )
                .alert("Mining", isPresented: $showMiningHistoryAlert) {
                    Button("Cancel", role: .cancel) {}

                    Button("Delete", role: .destructive) {
                        miningHistoryCoordinator.deleteAll(in: modelContext)
                    }

                    Button("Add", role: .confirm) {
                        miningHistoryCoordinator.startNext(in: modelContext)
                    }
                    .buttonStyle(.borderedProminent)
                } message: {
                    Text("There are \(miningHistories.count) mining histories not added to Anki.")
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

        if !miningHistories.isEmpty {
            ToolbarItem(placement: .topBarLeading) {
                Button("Mining History", systemImage: "tray.full") {
                    showMiningHistoryAlert.toggle()
                }
                .labelStyle(.iconOnly)
                .badge(miningHistories.count)
            }
        }

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
            showVideoHistoryUnavailableAlert = true
            unavailableVideoHistory = history
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
            try? modelContext.save()
        }
    }

}

// MARK: - SwiftData
extension FileBrowserScreen {
    private var `7daysAgo`: Date {
        Date.now.addingTimeInterval(-7 * 24 * 3600)
    }

    private func clearHistories() throws {
        let `7daysAgo` = `7daysAgo`
        let predicate = #Predicate<VideoHistory> { history in
            history.modificationDate < `7daysAgo`
        }
        let descriptor = FetchDescriptor(predicate: predicate)
        let hitories = try modelContext.fetch(descriptor)
        hitories.forEach { history in
            modelContext.delete(history)
        }
        try modelContext.save()
    }

    private func clearCaches() throws {
        let `7daysAgo` = `7daysAgo`
        let predicate = #Predicate<SubtitleCache> { cache in
            cache.modificationDate < `7daysAgo`
        }
        let descriptor = FetchDescriptor(predicate: predicate)
        let caches = try modelContext.fetch(descriptor)
        caches.forEach { cache in
            modelContext.delete(cache)
        }
        try modelContext.save()
    }

    func resolveMismatchedURLs() async throws {
        let predicate = #Predicate<VideoHistory> { _ in true }
        let descriptor = FetchDescriptor(predicate: predicate)
        let hitories = try modelContext.fetch(descriptor)
        let historyDict = Dictionary(zip(hitories.map(\.id), hitories), uniquingKeysWith: { old, new in new })
        let bookmarkDict = Dictionary(zip(hitories.map(\.id), hitories.map(\.urlBookmark)), uniquingKeysWith: { old, new in new })
        await withTaskGroup(of: (UUID, URL)?.self) { group in
            for (id, bookmark) in bookmarkDict {
                group.addTask {
                    var isStale = false
                    guard let resolvedURL = try? URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale),
                          !isStale else {
                        return nil
                    }
                    return (id, resolvedURL)
                }
            }
            for await result in group {
                guard let result else { return }
                let (id, newURL) = result
                guard let currentHistory = historyDict[id] else { return }
                if newURL != currentHistory.url {
                    currentHistory.url = newURL
                }
            }
        }
        try modelContext.save()
    }
}

// MARK: - helper methods for FileBrowserScreen
extension FileBrowserScreen {

    var supportedVideoType: [UTType] {
        var supportedTypes = VideoFileSupport.knownVideoExtensions.sorted().compactMap { fileExtension in
            UTType(filenameExtension: fileExtension)
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
