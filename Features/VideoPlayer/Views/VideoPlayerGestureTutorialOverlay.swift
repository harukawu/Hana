//
//  VideoPlayerGestureTutorialOverlay.swift
//  Hana
//
//  Created by Haruka on 2026/7/9.
//

import SwiftUI

struct VideoPlayerGestureTutorialOverlay: View {
    let onDismiss: @MainActor () -> Void

    private let leftItems: [VideoPlayerGestureTutorialItem] = [
        .init(
            systemImage: "gobackward",
            title: "Double tap",
            detail: "Previous subtitle or -10s"
        ),
        .init(
            systemImage: "sun.max.fill",
            title: "Swipe vertically",
            detail: "Screen brightness"
        )
    ]

    private let centerItems: [VideoPlayerGestureTutorialItem] = [
        .init(
            systemImage: "hand.tap.fill",
            title: "Tap",
            detail: "Show or hide controls"
        ),
        .init(
            systemImage: "playpause.fill",
            title: "Two-finger tap",
            detail: "Play or pause"
        ),
        .init(
            systemImage: "captions.bubble.fill",
            title: "Three-finger tap",
            detail: "Hide or show subtitles"
        )
    ]

    private let rightItems: [VideoPlayerGestureTutorialItem] = [
        .init(
            systemImage: "goforward",
            title: "Double tap",
            detail: "Next subtitle or +10s"
        ),
        .init(
            systemImage: "arrow.up",
            title: "Swipe up",
            detail: "Subtitle list"
        ),
        .init(
            systemImage: "checkmark",
            title: "Draw a check",
            detail: "Add bookmark"
        )
    ]

    var body: some View {
        GeometryReader { proxy in
            let isCompact = proxy.size.width < VideoPlayerGestureTutorialMetrics.compactWidth
            let maxWidth = min(
                max(proxy.size.width - VideoPlayerGestureTutorialMetrics.horizontalMargin, 280),
                VideoPlayerGestureTutorialMetrics.maxContentWidth
            )

            ZStack {
                Color.clear
                    .ignoresSafeArea()
                    .contentShape(.rect)
                    .onTapGesture(perform: onDismiss)

                VStack(spacing: VideoPlayerGestureTutorialMetrics.sectionSpacing) {
                    header

                    if isCompact {
                        VStack(spacing: VideoPlayerGestureTutorialMetrics.panelSpacing) {
                            tutorialPanels
                        }
                    } else {
                        HStack(alignment: .top, spacing: VideoPlayerGestureTutorialMetrics.panelSpacing) {
                            tutorialPanels
                        }
                    }
                }
                .frame(maxWidth: maxWidth)
                .padding(.horizontal, 28)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .foregroundStyle(.white)
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Gestures")
                    .font(.system(.headline, design: .rounded).weight(.semibold))

                Text("Quick controls while watching")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 38, height: 38)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .videoPlayerTutorialMaterial(in: .circle)
        }
        .padding(.leading, 18)
        .padding(.trailing, 10)
        .padding(.vertical, 10)
        .videoPlayerTutorialMaterial(in: .rect(cornerRadius: 22))
    }

    @ViewBuilder
    private var tutorialPanels: some View {
        VideoPlayerGestureTutorialPanel(
            title: "Left side",
            systemImage: "rectangle.leadinghalf.inset.filled",
            items: leftItems
        )

        VideoPlayerGestureTutorialPanel(
            title: "Center",
            systemImage: "rectangle.inset.filled",
            items: centerItems
        )

        VideoPlayerGestureTutorialPanel(
            title: "Right side",
            systemImage: "rectangle.trailinghalf.inset.filled",
            items: rightItems
        )
    }
}

private struct VideoPlayerGestureTutorialPanel: View {
    let title: String
    let systemImage: String
    let items: [VideoPlayerGestureTutorialItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
            } icon: {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
            }
            .labelStyle(.titleAndIcon)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(items) { item in
                    VideoPlayerGestureTutorialRow(item: item)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(16)
        .videoPlayerTutorialMaterial(in: .rect(cornerRadius: 20))
    }
}

private struct VideoPlayerGestureTutorialRow: View {
    let item: VideoPlayerGestureTutorialItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: item.systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct VideoPlayerGestureTutorialItem: Identifiable {
    let systemImage: String
    let title: String
    let detail: String

    var id: String { "\(systemImage)-\(title)-\(detail)" }
}

private enum VideoPlayerGestureTutorialMetrics {
    static let compactWidth: CGFloat = 720
    static let horizontalMargin: CGFloat = 56
    static let maxContentWidth: CGFloat = 860
    static let sectionSpacing: CGFloat = 14
    static let panelSpacing: CGFloat = 12
}

private extension View {
    func videoPlayerTutorialMaterial<S: Shape>(in shape: S) -> some View {
        background(.black.opacity(0.5), in: shape)
            .background(.ultraThinMaterial.opacity(0.3), in: shape)
    }
}
