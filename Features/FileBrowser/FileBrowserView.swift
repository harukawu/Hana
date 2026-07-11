//
//  FileBrowserView.swift
//  Hana
//
//  Created by Haruka on 2026/7/6.
//

import SwiftUI
import MarqueeText
import OSLog

public struct FileBrowserView<Header: View>: View {
    private let currentURL: URL
    private let webDAVSource: WebDavSource?
    private var refreshTrigger: UUID? = nil
    private let header: Header
    private let hasHeader: Bool
    @State private var headerHeight: CGFloat = 0
    @State private var loadingFiles: Bool = false
    @State private var currentFiles: [any File] = []
    @State private var loadFileError: (any Error)? = nil
    @State private var webDAVError: WebDAVError? = nil
    @State private var showWebDAVError: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    
    public var body: some View {
        GeometryReader { geometry in
            List {
                if hasHeader {
                    Section {
                        header
                            .onGeometryChange(for: CGFloat.self) { proxy in
                                proxy.size.height
                            } action: { height in
                                headerHeight = height
                            }
                            .listRowInsets(.horizontal, 0)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    } header: {
                        sectionHeader(
                            title: "Continue Watching",
                            systemImage: "clock.arrow.circlepath"
                        )
                    }
                    .listSectionSeparator(.hidden)
                }

                if shouldShowLoadState {
                    loadStateView
                        .frame(maxWidth: .infinity)
                        .frame(height: max(0, geometry.size.height - visibleHeaderHeight))
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .allowsHitTesting(false)
                } else {
                    Section {
                        ForEach(Array(currentFiles.enumerated()), id: \.element.id) { index, file in
                            NavigationLink(value: AnyFile(file: file)) {
                                FileRowView(file: file)
                            }
                            .buttonStyle(.plain)
                            .deleteDisabled(webDAVSource != nil)
                            .listRowBackground(fileRowBackground(at: index))
                            .listRowInsets(EdgeInsets(top: 0, leading: 28, bottom: 0, trailing: 28))
                        }
                        .onDelete(perform: deleteFiles(from:))
                    } header: {
                        sectionHeader(
                            title: "Files",
                            systemImage: "folder.fill",
                            trailingText: "\(currentFiles.count)"
                        )
                    }
                    .listSectionSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .listSectionSpacing(24)
            .scrollContentBackground(.hidden)
            .background(browserBackground)
        }
        .id(refreshTrigger)
        .alert(isPresented: $showWebDAVError, error: webDAVError, actions: {
            Button("OK") {
                webDAVError = nil
            }
        })
        .navigationTitle(currentURL.lastPathComponent)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadFiles()
        }
    }
    
    private var shouldShowLoadState: Bool {
        loadingFiles || loadFileError != nil || currentFiles.isEmpty
    }
    
    private var visibleHeaderHeight: CGFloat {
        hasHeader ? headerHeight : 0
    }

    private var browserBackground: some View {
        HanaPalette.background(for: colorScheme)
    }

    private func fileRowBackground(at index: Int) -> some View {
        let cornerRadius: CGFloat = 22
        let isFirst = index == currentFiles.startIndex
        let isLast = index == currentFiles.index(before: currentFiles.endIndex)

        return UnevenRoundedRectangle(
            topLeadingRadius: isFirst ? cornerRadius : 0,
            bottomLeadingRadius: isLast ? cornerRadius : 0,
            bottomTrailingRadius: isLast ? cornerRadius : 0,
            topTrailingRadius: isFirst ? cornerRadius : 0,
            style: .continuous
        )
        .fill(.thinMaterial)
        .padding(.horizontal, 16)
    }

    private func sectionHeader(
        title: LocalizedStringKey,
        systemImage: String,
        trailingText: String? = nil
    ) -> some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            if let trailingText {
                Text(trailingText)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .textCase(nil)
    }
    
    @ViewBuilder
    private var loadStateView: some View {
        if loadingFiles {
            ProgressView()
                .controlSize(.large)
        } else if let loadFileError {
            EmptyStateView(
                icon: "exclamationmark.triangle.fill",
                iconColor: .orange,
                title: "Unable to Load",
                subtitle: loadFileError.localizedDescription
            )
        } else if currentFiles.isEmpty {
            EmptyStateView(
                icon: "folder.badge.plus",
                iconColor: .secondary,
                title: "No Files Yet",
                subtitle: "Add video files in File app or import to get started"
            )
        }
    }
    
    private func loadFiles() {
        if currentURL.isFileURL {
            do {
                let fileURLs = try FileManager.default.contentsOfDirectory(
                    at: currentURL,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: .skipsHiddenFiles
                )
                let files = fileURLs.map { fileURL in
                    LocalFile(url: fileURL, disPlayName: fileURL.lastPathComponent, isDirectory: fileURL.isDirectory())
                }
                let sortedFiles = sortFiles(files)
                currentFiles = sortedFiles
            } catch {
                loadFileError = error
            }
        } else {
            guard let webDAVSource = webDAVSource else {
                return
            }
            Task {
                do {
                    loadingFiles = true
                    defer {
                        loadingFiles = false
                    }
                    let webDAVManager = WebDavManager(source: webDAVSource)
                    let webDAVFiles = try await webDAVManager.getWebdavFiles(from: currentURL)
                    let sortedFiles = sortFiles(webDAVFiles)
                    currentFiles = sortedFiles
                } catch let error as WebDAVError {
                    webDAVError = error
                    showWebDAVError = true
                } catch {
                    Logger.webDav.error("Uncaught WebDAV error: \(error, privacy: .public)")
                }
            }
        }
    }
    
    private func sortFiles(_ files: [any File]) -> [any File] {
        files.sorted { file1, file2 in
            if file1.isDirectory && !file2.isDirectory { return true }
            if !file1.isDirectory && file2.isDirectory { return false }
            return file1.disPlayName.localizedStandardCompare(file2.disPlayName) == .orderedAscending
        }
    }
    
    private func deleteFiles(from indexSet: IndexSet) {
        indexSet.forEach { index in
            let file = currentFiles[index]
            do {
                try FileManager.default.removeItem(at: file.url)
            } catch {
                Logger.fileStorage.log("Failed to delete file at \(file.url)")
            }
            loadFiles()
        }
    }
    
    init(
        currentURL: URL,
        webDAVSource: WebDavSource?,
        refreshTrigger: UUID?,
        hasHeader: Bool = true,
        @ViewBuilder header: () -> Header
    ) {
        self.currentURL = currentURL
        self.webDAVSource = webDAVSource
        self.refreshTrigger = refreshTrigger
        self.header = header()
        self.hasHeader = hasHeader
    }
}

extension FileBrowserView where Header == EmptyView {
    init(currentURL: URL, webDAVSource: WebDavSource?, refreshTrigger: UUID?) {
        self.init(
            currentURL: currentURL,
            webDAVSource: webDAVSource,
            refreshTrigger: refreshTrigger,
            hasHeader: false
        ) {
            EmptyView()
        }
    }
}

// MARK: - File Row View

public struct FileRowView: View {
    let file: any File
    @Environment(\.colorScheme) private var colorScheme
    
    private var iconName: String {
        if file.isDirectory { return "folder.fill" }
        let ext = file.url.pathExtension.lowercased()
        switch ext {
        case "mp4", "mkv", "mov", "avi", "m4v", "webm":
            return "play.rectangle.fill"
        case "srt", "ass", "vtt":
            return "captions.bubble.fill"
        default:
            return "doc.fill"
        }
    }
    
    private var iconColor: Color {
        if file.isDirectory { return HanaPalette.butterYellow }

        switch file.url.pathExtension.lowercased() {
        case "mp4", "mkv", "mov", "avi", "m4v", "webm":
            return HanaPalette.powderBlue
        case "srt", "ass", "vtt":
            return HanaPalette.lavender
        default:
            return HanaPalette.dustyBlue
        }
    }

    private var isPlayableVideo: Bool {
        switch file.url.pathExtension.lowercased() {
        case "mp4", "mkv", "mov", "avi", "m4v", "webm":
            true
        default:
            false
        }
    }

    private var title: String {
        file.url.deletingPathExtension().lastPathComponent
    }

    private var metadata: String {
        if file.isDirectory {
            return "Folder"
        }

        let fileExtension = file.url.pathExtension.uppercased()
        if isPlayableVideo {
            return fileExtension.isEmpty ? "Video" : "\(fileExtension) video"
        }
        return fileExtension.isEmpty ? "File" : fileExtension
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            fileIcon
            
            VStack(alignment: .leading, spacing: 4) {
                MarqueeText(title, duration: 6, delay: 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                
                Text(metadata)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .contentShape(.rect)
    }
    
    @ViewBuilder
    private var fileIcon: some View {
        Image(systemName: iconName)
            .font(.system(size: 19, weight: .semibold))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(iconColor)
            .frame(width: 46, height: 46)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(iconColor.opacity(colorScheme == .dark ? 0.22 : 0.13))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(.white.opacity(colorScheme == .dark ? 0.16 : 0.46), lineWidth: 0.8)
                    }
            }
            .shadow(color: iconColor.opacity(0.10), radius: 4, y: 2)
    }
}

// MARK: - Empty State View

public struct EmptyStateView: View {
    let icon: String
    var iconColor: Color = .secondary
    let title: String
    let subtitle: String
    
    public var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            emptyStateIcon
            
            VStack(spacing: 6) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var emptyStateIcon: some View {
        Image(systemName: icon)
            .font(.system(size: 32, weight: .medium))
            .foregroundStyle(iconColor)
            .frame(width: 80, height: 80)
            .background {
                Circle()
                    .fill(iconColor.opacity(0.12))
            }
    }
}
