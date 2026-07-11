//
//  VideoPlayerControls.swift
//  Hana
//
//  Created by Haruka on 2026/7/6.
//

import SwiftUI
import SwiftVLC
import UIKit
import AVKit

struct VideoPlayerControls: View {
    let player: Player
    @Bindable var viewModel: VideoPlayerViewModel
    let bookmarks: [VideoPlayerBookmark]
    let dismiss: DismissAction
    let onUserInteraction: @MainActor () -> Void
    let onSubComponentOpened: @MainActor () -> Void
    let onSubComponentClosed: @MainActor () -> Void
    let togglePip: () -> Void
    let onGestureTutorialRequested: @MainActor () -> Void
    let onBookmarkSelected: @MainActor (VideoPlayerBookmark) -> Void
    let onBookmarkDeleted: @MainActor (VideoPlayerBookmark) -> Void
    
    @State private var scrubPosition: Double?
    @State private var selectedBookmarkID: VideoPlayerBookmark.ID?
    @Environment(PersistedUserConfig.self) private var userConfig
    
    private let playbackRates: [Float] = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
    private let subtitleDelayStep = 100
    private var sortedBookmarks: [VideoPlayerBookmark] {
        bookmarks.sorted { $0.position < $1.position }
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 0)
                bottomBar
            }
            
            transportControls
            
            if let errorMessage = viewModel.playbackErrorMessage {
                errorBanner(errorMessage)
                    .padding(.horizontal, 34)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(.white)
        .onChange(of: bookmarks) { _, bookmarks in
            guard let selectedBookmarkID,
                  !bookmarks.contains(where: { $0.id == selectedBookmarkID }) else {
                return
            }
            self.selectedBookmarkID = nil
        }
    }
    
    // MARK: top
    private var topBar: some View {
        HStack(alignment: .top) {
            HStack(spacing: PlayerControlMetrics.compactControlSpacing) {
                PlayerCompactIconButton(
                    systemName: "xmark"
                ) {
                    onUserInteraction()
                    dismiss()
                }
                                    
                topBarControls
            }
            
            Spacer(minLength: 0)
            
            subtitleDelayControls
        }
        .padding(4)
        .padding(.horizontal, 28)
        .padding(.top, 22)
    }
    
    @ViewBuilder
    private var topBarControls: some View {
        
        let gestureTutorialButton = PlayerCompactIconButton(
            systemName: "hand.tap.fill",
            appliesGlassEffect: false
        ) {
            onUserInteraction()
            onGestureTutorialRequested()
        }
        
        HStack(spacing: 0) {
            gestureTutorialButton
            
            contentModeMenu
        }
        .opacity(0.01)
        .allowsHitTesting(false)
        .playerCompactGlassCapsule(interactive: false)
        .overlay {
            HStack(spacing: 0) {
                gestureTutorialButton
                
                contentModeMenu
            }
        }
    }
    
    private var contentModeMenu: some View {
        VideoPlayerMenu(
            systemName: viewModel.contentMode.systemImage,
            onMenuOpened: onSubComponentOpened,
            onMenuClosed: onSubComponentClosed,
            makeMenu: {
                UIMenu(
                    title: "Content Mode",
                    image: UIImage(systemName: viewModel.contentMode.systemImage),
                    options: .singleSelection,
                    children: VideoContentMode.allCases.map { mode in
                        UIAction(
                            title: mode.title,
                            image: UIImage(systemName: mode.systemImage),
                            state: viewModel.contentMode == mode ? .on : .off,
                        ) { _ in
                            viewModel.setContentMode(mode)
                            onUserInteraction()
                        }
                    }
                )
            }
        )
        .frame(
            width: PlayerControlMetrics.minimumHitTargetSize,
            height: PlayerControlMetrics.minimumHitTargetSize
        )
        .contentShape(Rectangle())
    }
    
    private var subtitleDelayControls: some View {
        HStack(spacing: 0) {
            PlayerCompactIconButton(
                systemName: "chevron.backward",
                appliesGlassEffect: false
            ) {
                onUserInteraction()
                viewModel.showLastSubtitleNow()
            }
            
            PlayerCompactIconButton(
                systemName: "minus",
                appliesGlassEffect: false
            ) {
                onUserInteraction()
                viewModel.stepSubtitleDelay(by: .milliseconds(-subtitleDelayStep))
            }
            
            PlayerCompactIconButton(
                systemName: "arrow.counterclockwise",
                appliesGlassEffect: false
            ) {
                onUserInteraction()
                viewModel.setSubtitleDelay(.zero)
            }
            
            PlayerCompactIconButton(
                systemName: "plus",
                appliesGlassEffect: false
            ) {
                onUserInteraction()
                viewModel.stepSubtitleDelay(by: .milliseconds(subtitleDelayStep))
            }
            
            PlayerCompactIconButton(
                systemName: "chevron.forward",
                appliesGlassEffect: false
            ) {
                onUserInteraction()
                viewModel.showNextSubtitleNow()
            }
        }
        .playerCompactGlassCapsule()
    }
    
    // MARK: middle
    private var transportControls: some View {
        HStack(spacing: PlayerControlMetrics.transportSpacing) {
            PlayerIconButton(
                systemName: "gobackward.10",
                controlSize: PlayerControlMetrics.transportControlSize,
                symbolSize: PlayerControlMetrics.transportSymbolSize,
                isDisabled: !player.isSeekable
            ) {
                onUserInteraction()
                viewModel.seek(by: .seconds(-10))
            }
            
            PlayerIconButton(
                systemName: player.isPlaying ? "pause.fill" : "play.fill",
                controlSize: PlayerControlMetrics.primaryTransportControlSize,
                symbolSize: PlayerControlMetrics.primaryTransportSymbolSize
            ) {
                onUserInteraction()
                viewModel.togglePlayPause()
            }
            
            PlayerIconButton(
                systemName: "goforward.10",
                controlSize: PlayerControlMetrics.transportControlSize,
                symbolSize: PlayerControlMetrics.transportSymbolSize,
                isDisabled: !player.isSeekable
            ) {
                onUserInteraction()
                viewModel.seek(by: .seconds(10))
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
    }
    
    // MARK: Bottom
    private var bottomBar: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .bottom, spacing: 18) {
                Text(viewModel.item.displayTitle)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .shadow(radius: 8)
                
                Spacer(minLength: 16)
                
                bottomMenus
            }
            
            progressRow
        }
        .padding(.horizontal, 30)
        .padding(.bottom, 8)
    }
    
    @ViewBuilder
    private var bottomMenus: some View {
        // The underlying view: provide a liquid glass container for the menus. Overlay: user interaction
        // This is a known bug from the release of iOS 26. Good job Apple
        
//        let pipButton = PlayerCompactIconButton(
//            systemName: "pip",
//            appliesGlassEffect: false
//        ) {
//            onUserInteraction()
//            togglePip()
//        }

        HStack(spacing: 0) {
            settingsMenu
//            pipButton
            routePickerButton
            queueMenu
        }
        .opacity(0.01)
        .allowsHitTesting(false)
        .playerCompactGlassCapsule(interactive: false)
        .overlay {
            HStack(spacing: 0) {
                settingsMenu
//                pipButton
                routePickerButton
                queueMenu
            }
        }
    }
    
    private var settingsMenu: some View {
        VideoPlayerMenu(
            systemName: "gearshape.fill",
            onMenuOpened: onSubComponentOpened,
            onMenuClosed: onSubComponentClosed,
            makeMenu: {
                var externalSubtitlesMenuChildren = [
                    UIAction(
                        title: "Import",
                        image: UIImage(systemName: "doc.badge.plus")
                    ) { _ in
                        if player.isPlaying { viewModel.togglePlayPause() }
                        viewModel.showExternalSubtitleImporter.toggle()
                    }
                ]
                if !userConfig.jimakuURL.isEmpty {
                    externalSubtitlesMenuChildren.append(
                        UIAction(
                            title: "Subtitle Server",
                            image: UIImage(systemName: "character.bubble.ja")
                        ) { _ in
                            viewModel.showJimakuSearchView.toggle()
                        }
                    )
                }
                let externalSubtitlesMenu = UIMenu(
                    title: "External Subtitles",
                    image: UIImage(systemName: "square.and.arrow.down.on.square"),
                    children: externalSubtitlesMenuChildren
                )
                
                let playbackSpeedMenu = UIMenu(
                    title: "Playback Speed",
                    image: UIImage(systemName: "gauge.with.dots.needle.67percent"),
                    options: .singleSelection,
                    children: playbackRates.map { rate in
                        UIAction(
                            title: VideoPlayerFormatters.playbackRate(rate),
                            state: player.rate == rate ? .on : .off
                        ) { _ in
                            viewModel.setPlaybackRate(rate)
                            onUserInteraction()
                        }
                    }
                )
                
                let audioTracksMenu = UIMenu(
                    title: "Audio Tracks",
                    image: UIImage(systemName: "music.note"),
                    options: .singleSelection,
                    children: [
                        UIAction(
                            title: "Off",
                            state: player.selectedAudioTrack == nil ? .on : .off
                        ) { _ in
                            player.selectedAudioTrack = nil
                        }
                    ] + player.audioTracks.map { track in
                        UIAction(
                            title: track.name,
                            state: player.selectedAudioTrack == track ? .on : .off
                        ) { _ in
                            player.selectedAudioTrack = track
                        }
                    }
                )
                
                let subtitlesMenu = UIMenu(
                    title: "Subtitles",
                    image: UIImage(systemName: "captions.bubble"),
                    options: .singleSelection,
                    children: [
                        UIAction(
                            title: "Off",
                            state: viewModel.selectedSubtitleTrackIndex == nil ? .on : .off
                        ) { _ in
                            viewModel.selectedSubtitleTrackIndex = nil
                        }
                    ] + player.subtitleTracks.enumerated().map { index, track in
                        UIAction(
                            title: track.name,
                            state: viewModel.selectedSubtitleTrackIndex == index ? .on : .off
                        ) { _ in
                            viewModel.selectedSubtitleTrackIndex = index
                        }
                    }
                )
                
                let playbackOptions = UIMenu(
                    title: "",
                    options: .displayInline,
                    children: [playbackSpeedMenu, audioTracksMenu, subtitlesMenu]
                )

                return UIMenu(children: [externalSubtitlesMenu, playbackOptions])
            }
        )
        .frame(
            width: PlayerControlMetrics.minimumHitTargetSize,
            height: PlayerControlMetrics.minimumHitTargetSize
        )
        .contentShape(Rectangle())
    }
    
    private var routePickerButton: some View {
        AVRoutePickerButton(
            onUserInteraction: onUserInteraction,
            onPickerOpened: onSubComponentOpened,
            onPickerClosed: onSubComponentClosed
        )
        .frame(
            width: PlayerControlMetrics.minimumHitTargetSize,
            height: PlayerControlMetrics.minimumHitTargetSize
        )
        .contentShape(Rectangle())
    }
    
    private var queueMenu: some View {
        VideoPlayerMenu(
            systemName: "list.bullet.rectangle",
            onMenuOpened: onSubComponentOpened,
            onMenuClosed: onSubComponentClosed,
            makeMenu: {
                let emptyLabel = UIAction(title: "Queue is empty", attributes: .disabled, handler: { _ in })
                
                return UIMenu(
                    title: "Playback Queue",
                    options: .singleSelection,
                    children: viewModel.itemsFromSameDirectories.isEmpty ? [emptyLabel] : viewModel.itemsFromSameDirectories.map { item in
                        UIAction(
                            title: item.displayTitle,
                            // we should not use viewModel.item == item. `videModel.item` can be not the same as the one in `videModel.itemsFromSameDirectories` with the same URL.
                            // This can happen when: 1. the first time user open the file. the `id` of the item with the same URL in `itemsFromSameDirectories` are different. Because current time are not yet persisted.
                            // Also when resuming from background, `viewModel.item` is updated, while `itemsFromSameDirectories` is not updated
                            state: viewModel.item.url == item.url ? .on : .off,
                        ) { _ in
                            viewModel.item = item
                        }
                    }
                )
            }
        )
        .frame(
            width: PlayerControlMetrics.minimumHitTargetSize,
            height: PlayerControlMetrics.minimumHitTargetSize
        )
        .contentShape(Rectangle())
    }
    
    private var progressRow: some View {
        VStack(spacing: 3) {
            progressSliderWithBookmarks
            
            HStack {
                Text(VideoPlayerFormatters.time(player.currentTime))
                Spacer()
                Text(VideoPlayerFormatters.remaining(
                    currentTime: player.currentTime,
                    duration: player.duration
                ))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.white.opacity(0.78))
        }
    }
    
    private var progressSliderWithBookmarks: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            
            ZStack(alignment: .leading) {
                PlayerProgressSlider(
                    value: Binding(
                        get: { scrubPosition ?? player.position },
                        set: { newValue in
                            scrubPosition = newValue
                            onUserInteraction()
                        }
                    ),
                    isEnabled: player.isSeekable,
                    onEditingChanged: { isEditing in
                        onUserInteraction()
                        if isEditing {
                            selectedBookmarkID = nil
                        }
                        guard !isEditing, let scrubPosition else { return }
                        viewModel.seek(to: scrubPosition)
                        self.scrubPosition = nil
                    }
                )
                .frame(height: PlayerControlMetrics.progressSliderHeight)
                
                ForEach(sortedBookmarks) { bookmark in
                    PlayerBookmarkMarkerButton(
                        bookmark: bookmark,
                        isSelected: bookmark.id == selectedBookmarkID
                    ) {
                        selectedBookmarkID = bookmark.id
                        scrubPosition = nil
                        onBookmarkSelected(bookmark)
                    }
                    .position(
                        x: markerX(for: bookmark.position, width: width),
                        y: PlayerControlMetrics.progressSliderHeight / 2
                    )
                }
                
                if let selectedBookmark {
                    PlayerBookmarkCallout(
                        bookmark: selectedBookmark,
                        onDelete: {
                            selectedBookmarkID = nil
                            onBookmarkDeleted(selectedBookmark)
                        }
                    )
                    .position(
                        x: calloutX(for: selectedBookmark.position, width: width),
                        y: -PlayerControlMetrics.bookmarkCalloutYOffset
                    )
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
                    .zIndex(1)
                }
            }
            .animation(.easeOut(duration: 0.16), value: selectedBookmarkID)
            .animation(.easeOut(duration: 0.16), value: bookmarks)
        }
        .frame(height: PlayerControlMetrics.progressSliderHeight)
    }
    
    private var selectedBookmark: VideoPlayerBookmark? {
        guard let selectedBookmarkID else { return nil }
        return bookmarks.first { $0.id == selectedBookmarkID }
    }
    
    private func markerX(for position: Double, width: CGFloat) -> CGFloat {
        let markerRadius = PlayerControlMetrics.bookmarkMarkerHitSize / 2
        return min(max(CGFloat(position) * width, markerRadius), width - markerRadius)
    }
    
    private func calloutX(for position: Double, width: CGFloat) -> CGFloat {
        let margin = PlayerControlMetrics.bookmarkCalloutTotalWidth / 2
        return min(max(CGFloat(position) * width, margin), width - margin)
    }
    
    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(.callout)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .glassEffect(.regular, in: .rect(cornerRadius: 18))
    }
}

// MARK: - Slider
private struct PlayerProgressSlider: UIViewRepresentable {
    @Binding var value: Double
    let isEnabled: Bool
    let onEditingChanged: @MainActor (Bool) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> UISlider {
        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.isContinuous = true
        slider.sliderStyle = .thumbless
        slider.minimumTrackTintColor = .white
        slider.maximumTrackTintColor = .white.withAlphaComponent(0.28)
        slider.addTarget(
            context.coordinator,
            action: #selector(Coordinator.valueChanged(_:)),
            for: .valueChanged
        )
        slider.addTarget(
            context.coordinator,
            action: #selector(Coordinator.editingBegan(_:)),
            for: .touchDown
        )
        slider.addTarget(
            context.coordinator,
            action: #selector(Coordinator.editingEnded(_:)),
            for: [.touchUpInside, .touchUpOutside, .touchCancel]
        )
        return slider
    }
    
    func updateUIView(_ slider: UISlider, context: Context) {
        context.coordinator.parent = self
        slider.isEnabled = isEnabled
        
        guard !slider.isTracking else { return }
        slider.value = Float(min(max(value, 0), 1))
    }
    
    @MainActor
    final class Coordinator: NSObject {
        var parent: PlayerProgressSlider
        
        init(_ parent: PlayerProgressSlider) {
            self.parent = parent
        }
        
        @objc
        func valueChanged(_ slider: UISlider) {
            parent.value = Double(slider.value)
        }
        
        @objc
        func editingBegan(_ slider: UISlider) {
            parent.onEditingChanged(true)
        }
        
        @objc
        func editingEnded(_ slider: UISlider) {
            parent.onEditingChanged(false)
        }
    }
}

// MARK: - AVRoutePickerButton
private struct AVRoutePickerButton: UIViewRepresentable {
    let onUserInteraction: @MainActor @Sendable () -> Void
    let onPickerOpened: @MainActor @Sendable () -> Void
    let onPickerClosed: @MainActor @Sendable () -> Void
    
    init(
        onUserInteraction: @MainActor @Sendable @escaping () -> Void,
        onPickerOpened: @MainActor @Sendable @escaping () -> Void,
        onPickerClosed: @MainActor @Sendable @escaping () -> Void
    ) {
        self.onUserInteraction = onUserInteraction
        self.onPickerOpened = onPickerOpened
        self.onPickerClosed = onPickerClosed
    }
    
    func makeUIView(context: Context) -> AVRoutePickerView {
        let pickerView = AVRoutePickerView()
        pickerView.delegate = context.coordinator
//        pickerView.activeTintColor = .accent
        pickerView.prioritizesVideoDevices = true
        if let button = pickerView.subviews.first(where: { $0 is UIButton }) as? UIButton {
            var configuration = UIButton.Configuration.plain()
            configuration.contentInsets = .zero
            configuration.baseForegroundColor = .white
            configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(
                pointSize: PlayerControlMetrics.compactControlSymbolSize,
                weight: .semibold,
                scale: .medium
            )
            configuration.image = UIImage(systemName: "airplay.video")
//            button.imageView = nil // impossible
//            // cannot remove it. We can remove the backing CALayer
            if let layers = button.layer.sublayers {
                for layer in layers {
                    layer.removeFromSuperlayer()
                }
            }
            button.configuration = configuration
            button.contentHorizontalAlignment = .center
            button.contentVerticalAlignment = .center
        }
        return pickerView
    }
    
    func updateUIView(_ button: AVRoutePickerView, context: Context) {
        context.coordinator.parent = self
    }
    
    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: AVRoutePickerView,
        context: Context
    ) -> CGSize? {
        CGSize(
            width: PlayerControlMetrics.compactControlVisualSize,
            height: PlayerControlMetrics.compactControlVisualSize
        )
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, AVRoutePickerViewDelegate {
        var parent: AVRoutePickerButton
        
        init(parent: AVRoutePickerButton) {
            self.parent = parent
        }
        
        func routePickerViewWillBeginPresentingRoutes(_ routePickerView: AVRoutePickerView) {
            let parent = parent
            MainActor.assumeIsolated {
                parent.onPickerOpened()
            }
        }
        
        func routePickerViewDidEndPresentingRoutes(_ routePickerView: AVRoutePickerView) {
            let parent = parent
            MainActor.assumeIsolated {
                parent.onPickerClosed()
            }
        }
    }
}

// MARK: - Bookmark
private struct PlayerBookmarkMarkerButton: View {
    let bookmark: VideoPlayerBookmark
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Rectangle()
                    .fill(.clear)
                
                Capsule()
                    .fill(isSelected ? .yellow : .white)
                    .frame(
                        width: PlayerControlMetrics.bookmarkMarkerWidth,
                        height: PlayerControlMetrics.bookmarkMarkerHeight
                    )
                    .shadow(color: .black.opacity(0.5), radius: 5)
            }
            .frame(
                width: PlayerControlMetrics.bookmarkMarkerHitSize,
                height: PlayerControlMetrics.bookmarkMarkerHitSize
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct PlayerBookmarkCallout: View {
    let bookmark: VideoPlayerBookmark
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "bookmark.fill")
                .font(.subheadline.weight(.semibold))
            
            Text(VideoPlayerFormatters.time(bookmark.time))
                .font(.subheadline.monospacedDigit().weight(.semibold))
            
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(
                        width: PlayerControlMetrics.bookmarkCalloutButtonSize,
                        height: PlayerControlMetrics.bookmarkCalloutButtonSize
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
        }
        .frame(width: PlayerControlMetrics.bookmarkCalloutContentWidth)
        .padding(.horizontal, PlayerControlMetrics.bookmarkCalloutHorizontalPadding)
        .padding(.vertical, 7)
        .foregroundStyle(.white)
        .glassEffect(
            .clear.interactive().tint(.black.opacity(0.12)),
            in: .rect(cornerRadius: 17)
        )
    }
}

// MARK: - Basic elements

private struct VideoPlayerMenu: UIViewRepresentable {
    let systemName: String
    let onMenuOpened: @MainActor @Sendable () -> Void
    let onMenuClosed: @MainActor @Sendable () -> Void
    let makeMenu: () -> UIMenu
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIView(context: Context) -> VideoPlayerMenuButton {
        let button = VideoPlayerMenuButton(frame: .zero)
        let coordinator = context.coordinator
        button.menu = UIMenu(
            children: [
                UIDeferredMenuElement.uncached { completion in
                    completion(coordinator.makeMenu().children)
                }
            ]
        )
        return button
    }
    
    func updateUIView(_ button: VideoPlayerMenuButton, context: Context) {
        context.coordinator.parent = self
        button.onMenuOpened = onMenuOpened
        button.onMenuClosed = onMenuClosed
        var configuration = UIButton.Configuration.plain()
        configuration.baseForegroundColor = .white
        configuration.contentInsets = .zero
        configuration.indicator = .none
        configuration.image = UIImage(systemName: systemName)
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(
            pointSize: PlayerControlMetrics.compactControlSymbolSize,
            weight: .semibold,
            scale: .medium
        )
        button.configuration = configuration
        button.contentHorizontalAlignment = .center
        button.contentVerticalAlignment = .center
        button.showsMenuAsPrimaryAction = true
        button.preferredMenuElementOrder = .fixed
    }
    
    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: VideoPlayerMenuButton,
        context: Context
    ) -> CGSize? {
        CGSize(
            width: PlayerControlMetrics.compactControlVisualSize,
            height: PlayerControlMetrics.compactControlVisualSize
        )
    }
    
    @MainActor
    final class Coordinator {
        var parent: VideoPlayerMenu
        
        init(parent: VideoPlayerMenu) {
            self.parent = parent
        }
        
        func makeMenu() -> UIMenu {
            parent.makeMenu()
        }
    }
}

@MainActor
private final class VideoPlayerMenuButton: UIButton {
    var onMenuOpened: @MainActor @Sendable () -> Void = {}
    var onMenuClosed: @MainActor @Sendable () -> Void = {}
    
    override func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        willDisplayMenuFor configuration: UIContextMenuConfiguration,
        animator: (any UIContextMenuInteractionAnimating)?
    ) {
        super.contextMenuInteraction(
            interaction,
            willDisplayMenuFor: configuration,
            animator: animator
        )
        onMenuOpened()
    }
    
    override func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        willEndFor configuration: UIContextMenuConfiguration,
        animator: (any UIContextMenuInteractionAnimating)?
    ) {
        super.contextMenuInteraction(
            interaction,
            willEndFor: configuration,
            animator: animator
        )
        onMenuClosed()
    }
}

private struct PlayerIconButton: View {
    let systemName: String
    var controlSize: CGFloat = PlayerControlMetrics.minimumHitTargetSize
    var symbolSize: CGFloat = PlayerControlMetrics.standardSymbolSize
    var isDisabled = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: symbolSize, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: controlSize, height: controlSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
    }
}

private struct PlayerCompactIconButton: View {
    let systemName: String
    var appliesGlassEffect = true
    let action: () -> Void
    
    @ViewBuilder
    var body: some View {
        if appliesGlassEffect {
            button
                .glassEffect(.clear.interactive().tint(.black.opacity(0.12)), in: .circle)
        } else {
            button
        }
    }
    
    private var button: some View {
        Button(action: action) {
            PlayerCompactControlLabel(systemName: systemName)
                .frame(
                    width: PlayerControlMetrics.minimumHitTargetSize,
                    height: PlayerControlMetrics.minimumHitTargetSize
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct PlayerCompactControlLabel: View {
    let systemName: String
    
    var body: some View {
        Image(systemName: systemName)
            .font(
                .system(
                    size: PlayerControlMetrics.compactControlSymbolSize,
                    weight: .semibold
                )
            )
            .frame(
                width: PlayerControlMetrics.compactControlVisualSize,
                height: PlayerControlMetrics.compactControlVisualSize
            )
    }
}

private extension View {
    func playerCompactGlassCapsule(
        interactive: Bool = true,
        inset: CGFloat = PlayerControlMetrics.compactGlassInset
    ) -> some View {
        glassEffect(
            .clear.interactive(interactive).tint(.black.opacity(0.12)),
            in: Capsule().inset(by: inset)
        )
    }
}

// MARK: - Metrics
private enum PlayerControlMetrics {
    static let minimumHitTargetSize: CGFloat = 44
    static let standardSymbolSize: CGFloat = 20
    
    static let compactControlVisualSize: CGFloat = 40
    static let compactControlSymbolSize: CGFloat = 17
    static let compactControlSpacing: CGFloat = 8
    static var compactGlassInset: CGFloat {
        (minimumHitTargetSize - compactControlVisualSize) / 2
    }
    
    static let transportControlSize: CGFloat = 60
    static let transportSymbolSize: CGFloat = 27
    static let primaryTransportControlSize: CGFloat = 68
    static let primaryTransportSymbolSize: CGFloat = 34
    static let transportSpacing: CGFloat = 30
    static let progressSliderHeight: CGFloat = 32
    static let bookmarkMarkerWidth: CGFloat = 4
    static let bookmarkMarkerHeight: CGFloat = 18
    static let bookmarkMarkerHitSize: CGFloat = 30
    static let bookmarkCalloutContentWidth: CGFloat = 124
    static let bookmarkCalloutHorizontalPadding: CGFloat = 10
    static var bookmarkCalloutTotalWidth: CGFloat {
        bookmarkCalloutContentWidth + bookmarkCalloutHorizontalPadding * 2
    }
    static let bookmarkCalloutButtonSize: CGFloat = 30
    static let bookmarkCalloutYOffset: CGFloat = 24
}
