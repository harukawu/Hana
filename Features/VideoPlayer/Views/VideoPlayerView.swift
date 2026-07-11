//
//  VideoPlayerView.swift
//  Hana
//
//  Created by Haruka on 2026/7/6.
//

import SwiftUI
import SwiftData
import SwiftVLC
import UIKit
import UniformTypeIdentifiers
import OSLog

struct VideoPlayerView: View {
    @State private var player: Player
    @State private var viewModel: VideoPlayerViewModel
    @State private var hudModel: VideoPlayerHUDModel
    @State private var controlsVisibilityModel: VideoPlayerControlsVisibilityModel
    @State private var isPlayingBeforeLookup = true
    @State private var pipController: PiPController?
    @State private var isGestureTutorialPresented = false
    
    @Environment(PersistedUserConfig.self) private var userConfig
    @Environment(\.dismiss) private var dismiss
    
    @Environment(\.modelContext) private var modelContext
    
    @Environment(\.scenePhase) private var scenePhase
    
    private var currentCueIndex: Int? { viewModel.currentCueIndex }
    
    init(item: VideoItem) {
        let player = Player()
        let hudModel = VideoPlayerHUDModel()
        let visibilityModel = VideoPlayerControlsVisibilityModel()
        let viewModel = VideoPlayerViewModel(
            item: item,
            player: player,
            hudModel: hudModel,
            controlsVisibilityModel: visibilityModel
        )
        self.hudModel = hudModel
        self.player = player
        self.viewModel = viewModel
        self.controlsVisibilityModel = visibilityModel
    }
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
//            PiPVideoView(player, controller: $pipController, startsAutomaticallyFromInline: false)
            VideoView(player)
                .allowsHitTesting(false)
                .opacity(controlsVisibilityModel.isVisible || isGestureTutorialPresented ? 0.8 : 1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
            
            videoGestureSurface
            
            subtitleView
            
            controls
            
            if let hudState = hudModel.hudState {
                VStack {
                    VideoPlayerHUD(state: hudState)
                        .transition(.scale(scale: 0.94).combined(with: .opacity))
                        .padding(.top, 26)
                    Spacer()
                }
                .animation(.easeOut(duration: 0.16), value: hudState)
            }

            if isGestureTutorialPresented {
                VideoPlayerGestureTutorialOverlay(onDismiss: hideGestureTutorial)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
                    .zIndex(1)
            }
            
            VolumeObserverView { newVolume in
                hudModel.showVolume(value: newVolume)
            }
            .opacity(0.01)
            .allowsHitTesting(false)
        }
        .interfaceOrientation(.landscape)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .fileImporter(isPresented: $viewModel.showExternalSubtitleImporter, allowedContentTypes: [.plainText, .data]) { result in
            Task {
                await viewModel.handleSubtitleImportResult(result, securityScoped: true)
            }
        }
        .onChange(of: viewModel.item, { oldItem, newItem in
            // when resume from background. id is unchanged while playback data are updated. We've persisted manually
            if oldItem.id != newItem.id {
                viewModel.persistVideoItem(oldItem, modelContext: modelContext)
                viewModel.resetSubtitleRuntimeStateForPlaybackSession()
                viewModel.playbackSession = .init(itemID: newItem.id)
            }
        })
        .task(id: viewModel.playbackSession) {
            if viewModel.isSuspendedForBackground {
                await viewModel.runAfterPlayStart {
                    // clear suspended states only after player starts again.
                    // This is to avoid the case where user comes from background and then dismiss video player view
                    viewModel.playbackSnapshotBeforeSuspended = nil
                    viewModel.isSuspendedForBackground = false
                }
            } else {
                if let persistenceTask = viewModel.persistenceTasks[viewModel.item.url] {
                    await persistenceTask.value
                }
                viewModel.startPlayback()
            }
        }
        .task(id: viewModel.playbackSession) {
            await viewModel.prepareSubtitleTrackAfterPlayStart()
        }
        .task(id: viewModel.playbackSession) {
            await viewModel.restorePlaybackDataFromHistory()
        }
        .task(id: viewModel.item.id) {
            // This needs to be rerun after item changed since after the persistence of last item, in memory items are stale
            await viewModel.loadItemsFromSameDirectories(modelContext: modelContext)
        }
        .onChange(of: scenePhase, { oldValue, newValue in
            viewModel.onScenePhaseChange(from: oldValue, to: newValue, modelContext: modelContext)
        })
        .onDisappear {
            viewModel.persistVideoItem(viewModel.item, modelContext: modelContext)
            viewModel.stopPlayback()
        }
        .onChange(of: player.isPlaying, { _, isPlaying in
            if isPlaying {
                controlsVisibilityModel.scheduleAutoHide()
            } else {
                controlsVisibilityModel.cancelAutoHide()
            }
        })
        .sheet(isPresented: $viewModel.showJimakuSearchView) { jimakuSearchView }
        .sheet(isPresented: $viewModel.showSubtitlesFullscreenView) { subtitlesFullscreenView }
        .fullScreenCover(isPresented: $viewModel.isAdvancedSettingsPresented) {
            VideoPlayerAdvancedSettingsPlaceholder()
        }
    }
}

// MARK: - Subviews
extension VideoPlayerView {
    private var videoGestureSurface: some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .ignoresSafeArea()
            .videoPlayerGesture(
                onSingleTap: viewModel.handleSingleTap,
                onDoubleTap: viewModel.handleDoubleTap(in:),
                onTwoFingersTap: viewModel.handleTwoFingersTap,
                onThreeFingersTap: viewModel.handleThreeFingersTap,
                onLeftPanBegan: viewModel.handleLeftPanBegan,
                onLeftPanChanged: viewModel.handleLeftPanChanged(relativeYTranslation:),
                onLeftPanEnded: viewModel.handleLeftPanEnded,
                onRightSwipe: viewModel.handleRightSwipe,
                onCheckMark: viewModel.handleCheckMarkBookmark
            )
    }
    
    @ViewBuilder
    var subtitleView: some View {
        if let selectedSubtitleTrackIndex = viewModel.selectedSubtitleTrackIndex,
           let currentCueIndex,
           userConfig.nativeSubtitleRendering,
           viewModel.hiddenSubtitleTrackIndex == nil {
            VideoSubtitleView(
                cueIndex: currentCueIndex,
                subtitles: viewModel.nativeSubtitles[selectedSubtitleTrackIndex],
                subtitleDelay: viewModel.subtitleDelay,
                videoURL: viewModel.item.url,
                videoTitle: viewModel.item.displayTitle,
                selectedAudioTrackIndex: viewModel.selectedAudioTrackIndex,
                onLookupVisibilityChanged: { isVisible in
                    let isPlaying = player.isPlaying
                    if isVisible {
                        isPlayingBeforeLookup = isPlaying
                        if isPlaying {
                            viewModel.togglePlayPause()
                        }
                    } else if !isVisible && isPlayingBeforeLookup {
                        viewModel.togglePlayPause()
                    }
                    if !isVisible {
                        viewModel.isAnkiMining = isVisible
                    }
                },
                onMiningStart: {
                    viewModel.isAnkiMining = true
                }
            )
        }
    }
    
    @ViewBuilder
    var controls: some View {
        if controlsVisibilityModel.isVisible {
            VideoPlayerControls(
                player: player,
                viewModel: viewModel,
                bookmarks: viewModel.bookmarks,
                dismiss: dismiss,
                onUserInteraction: {
                    controlsVisibilityModel.show(allowingAutoHide: player.isPlaying)
                },
                onSubComponentOpened: {
                    controlsVisibilityModel.suspendAutoHide()
                },
                onSubComponentClosed: {
                    controlsVisibilityModel.resumeAutoHide(allowingAutoHide: player.isPlaying)
                },
                togglePip: {
                    if let pipController {
                        pipController.toggle()
                    }
                },
                onGestureTutorialRequested: showGestureTutorial,
                onBookmarkSelected: viewModel.handleBookmarkSelected(_:),
                onBookmarkDeleted: viewModel.handleBookmarkDeleted(_:)
            )
            .transition(.opacity)
        }
    }
    
    var jimakuSearchView: some View {
        JimakuSearchView(initialQuery: viewModel.item.displayTitle) { jimakuFile in
            Task {
                let localURL = try await JimakuManager.downloadSubtitle(from: jimakuFile)
                await viewModel.handleSubtitleImportResult(.success(localURL), securityScoped: false)
            }
        }
        .onAppear {
            if player.isPlaying {
                viewModel.togglePlayPause()
            }
        }
        .onDisappear {
            viewModel.togglePlayPause()
        }
    }
    
    @ViewBuilder
    var subtitlesFullscreenView: some View {
        if let selectedSubtitleTrackIndex = viewModel.selectedSubtitleTrackIndex,
           selectedSubtitleTrackIndex < viewModel.nativeSubtitles.count {
            SubtitlesFullScreenView(
                videoTitle: viewModel.item.displayTitle,
                videoURL: viewModel.item.url,
                subtitles: viewModel.nativeSubtitles[selectedSubtitleTrackIndex],
                subtitleDelay: viewModel.subtitleDelay,
                initialRequest: nil,
                highlightedIndex: currentCueIndex ?? viewModel.lastKnownCueIndex,
                selectedAudioTrackIndex: viewModel.selectedAudioTrackIndex,
                onMiningStart: {
                    viewModel.isAnkiMining = true
                }
            )
            .onAppear {
                if player.isPlaying {
                    viewModel.togglePlayPause()
                }
            }
            .onDisappear {
                viewModel.togglePlayPause()
                viewModel.isAnkiMining = false
            }
        }
    }
}

// MARK: - Gesture Tutorial
extension VideoPlayerView {
    @MainActor
    private func showGestureTutorial() {
        withAnimation(.easeOut(duration: 0.2)) {
            if player.isPlaying {
                viewModel.togglePlayPause()
            }
            controlsVisibilityModel.hide()
            isGestureTutorialPresented = true
        }
    }

    @MainActor
    private func hideGestureTutorial() {
        withAnimation(.easeOut(duration: 0.16)) {
            isGestureTutorialPresented = false
        }
    }
}
