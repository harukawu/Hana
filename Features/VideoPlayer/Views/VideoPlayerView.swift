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
    private let userConfig: UserConfig

    @State private var player: Player
    @State private var viewModel: VideoPlayerViewModel
    @State private var hudModel: VideoPlayerHUDModel
    @State private var controlsVisibilityModel: VideoPlayerControlsVisibilityModel
    @State private var subtitleState: SubtitleState
    @State private var isPlayingBeforeLookup = true
    @State private var pipController: PiPController?
    @State private var isGestureTutorialPresented = false
    
    @Environment(\.dismiss) private var dismiss
    
    @Environment(\.modelContext) private var modelContext
    
    @Environment(\.scenePhase) private var scenePhase
    
    private var currentCueIndex: Int? { viewModel.currentCueIndex }
    
    init(
        item: VideoItem,
        userConfig: UserConfig
    ) {
        let player = Player()
        let hudModel = VideoPlayerHUDModel()
        let visibilityModel = VideoPlayerControlsVisibilityModel()
        let subtitleState = SubtitleState()
        let viewModel = VideoPlayerViewModel(
            item: item,
            userConfig: userConfig,
            player: player,
            hudModel: hudModel,
            controlsVisibilityModel: visibilityModel,
            subtitleState: subtitleState
        )
        self.userConfig = userConfig
        self.hudModel = hudModel
        self.player = player
        self.viewModel = viewModel
        self.controlsVisibilityModel = visibilityModel
        self.subtitleState = subtitleState
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
        .preferLightScheme(userConfig.playbackTheme.preferLightScheme)
        .interfaceOrientation(.landscape)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .fileImporter(isPresented: $viewModel.showExternalSubtitleImporter, allowedContentTypes: [.plainText, .data]) { result in
            let session = viewModel.playbackSession
            Task {
                // this function is aware of cancellation
                await viewModel.importSubtitle(
                    result,
                    securityScoped: true,
                    expectedSession: session
                )
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
            await viewModel.runPlaybackSession(modelContext: modelContext)
        }
        .onChange(of: scenePhase, { oldValue, newValue in
            viewModel.onScenePhaseChange(from: oldValue, to: newValue, modelContext: modelContext)
        })
        .onChange(of: player.currentTime, { _, currentTime in
            viewModel.refreshNowPlayingInfo(currentTime: currentTime)
        })
        .onAppear {
            viewModel.activateSystemMediaManager()
        }
        .onDisappear {
            viewModel.onPlayerViewDisappear(modelContext: modelContext)
        }
        .onChange(of: player.isPlaying, { _, isPlaying in
            viewModel.refreshNowPlayingInfo(currentTime: player.currentTime, force: true)
            
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
        if let selectedSubtitleTrackIndex = subtitleState.selectedSubtitleTrackIndex,
           let currentCueIndex,
           userConfig.nativeSubtitleRendering,
           subtitleState.hiddenSubtitleTrackIndex == nil {
            VideoSubtitleView(
                cueIndex: currentCueIndex,
                subtitles: subtitleState.nativeSubtitles[selectedSubtitleTrackIndex],
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
                subtitleState: subtitleState,
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
            let session = viewModel.playbackSession
            Task {
                let localURL = try await JimakuManager.downloadSubtitle(from: jimakuFile)
                await viewModel.importSubtitle(
                    .success(localURL),
                    securityScoped: false,
                    expectedSession: session
                )
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
        if let selectedSubtitleTrackIndex = subtitleState.selectedSubtitleTrackIndex,
           selectedSubtitleTrackIndex < subtitleState.nativeSubtitles.count {
            SubtitlesFullScreenView(
                videoTitle: viewModel.item.displayTitle,
                videoURL: viewModel.item.url,
                subtitles: subtitleState.nativeSubtitles[selectedSubtitleTrackIndex],
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
