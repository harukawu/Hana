//
//  HistoryCollectionView.swift
//  Hana
//

import SwiftUI
import UIKit

struct HistoryCollectionView: UIViewRepresentable {
    let histories: [VideoHistory]
    let maxHeight: CGFloat
    let maxWidth: CGFloat
    let onOpen: @MainActor (VideoHistory) -> Void
    let onDelete: @MainActor (VideoHistory) -> Void

    static func preferredHeight(maxHeight: CGFloat) -> CGFloat {
        imageHeight(maxHeight: maxHeight)
            + HistoryTileContentView.titleSpacing
            + ceil(HistoryTileContentView.titleFont.lineHeight)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            maxHeight: maxHeight,
            maxWidth: maxWidth,
            onOpen: onOpen,
            onDelete: onDelete
        )
    }

    func makeUIView(context: Context) -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 8
        layout.minimumInteritemSpacing = 8
        layout.sectionInset = .zero

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        collectionView.scrollIndicatorInsets = collectionView.contentInset
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.alwaysBounceHorizontal = false
        collectionView.delegate = context.coordinator
        collectionView.prefetchDataSource = context.coordinator
        collectionView.register(
            HistoryCollectionViewCell.self,
            forCellWithReuseIdentifier: HistoryCollectionViewCell.reuseIdentifier
        )
        context.coordinator.connect(to: collectionView)
        return collectionView
    }

    func updateUIView(_ collectionView: UICollectionView, context: Context) {
        context.coordinator.update(
            histories: histories,
            maxHeight: maxHeight,
            maxWidth: maxWidth,
            onOpen: onOpen,
            onDelete: onDelete,
            in: collectionView
        )
    }

    static func dismantleUIView(_ collectionView: UICollectionView, coordinator: Coordinator) {
        coordinator.cancelImagePreparation()
    }

    private static func imageHeight(maxHeight: CGFloat) -> CGFloat {
        max(44, maxHeight - 20)
    }

    @MainActor
    final class Coordinator: NSObject, UICollectionViewDelegateFlowLayout, UICollectionViewDataSourcePrefetching {
        private enum Section: Hashable {
            case main
        }

        private var dataSource: UICollectionViewDiffableDataSource<Section, UUID>?
        private var itemsByID: [UUID: HistoryCollectionItem] = [:]
        private var historiesByID: [UUID: VideoHistory] = [:]
        private var displayedIDs: [UUID] = []
        private var hasAppliedInitialSnapshot = false
        private var maxHeight: CGFloat
        private var maxWidth: CGFloat
        private var onOpen: @MainActor (VideoHistory) -> Void
        private var onDelete: @MainActor (VideoHistory) -> Void
        private let imageCache = FullResolutionHistoryImageCache()
        private var imagePreparationTasks: [UUID: Task<Void, Never>] = [:]
        private var imagePreparationRevisions: [UUID: Date] = [:]

        init(
            maxHeight: CGFloat,
            maxWidth: CGFloat,
            onOpen: @escaping @MainActor (VideoHistory) -> Void,
            onDelete: @escaping @MainActor (VideoHistory) -> Void
        ) {
            self.maxHeight = maxHeight
            self.maxWidth = maxWidth
            self.onOpen = onOpen
            self.onDelete = onDelete
        }

        func connect(to collectionView: UICollectionView) {
            dataSource = UICollectionViewDiffableDataSource<Section, UUID>(
                collectionView: collectionView
            ) { [weak self] collectionView, indexPath, id in
                guard
                    let self,
                    let item = self.itemsByID[id],
                    let cell = collectionView.dequeueReusableCell(
                        withReuseIdentifier: HistoryCollectionViewCell.reuseIdentifier,
                        for: indexPath
                    ) as? HistoryCollectionViewCell
                else {
                    return nil
                }

                let image = self.imageCache.image(for: id, revision: item.revision)
                    ?? self.imageCache.latestImage(for: id)
                cell.configure(
                    item: item,
                    image: image,
                    imageHeight: Self.imageHeight(maxHeight: self.maxHeight)
                )
                self.prepareImageIfNeeded(for: item, in: collectionView)
                return cell
            }
        }

        func update(
            histories: [VideoHistory],
            maxHeight: CGFloat,
            maxWidth: CGFloat,
            onOpen: @escaping @MainActor (VideoHistory) -> Void,
            onDelete: @escaping @MainActor (VideoHistory) -> Void,
            in collectionView: UICollectionView
        ) {
            self.onOpen = onOpen
            self.onDelete = onDelete

            let layoutChanged = self.maxHeight != maxHeight || self.maxWidth != maxWidth
            self.maxHeight = maxHeight
            self.maxWidth = maxWidth

            let oldItems = itemsByID
            let newIDs = histories.map(\.id)
            let liveIDs = Set(newIDs)
            var changedIDs: [UUID] = []
            var newItems: [UUID: HistoryCollectionItem] = [:]

            historiesByID = Dictionary(uniqueKeysWithValues: histories.map { ($0.id, $0) })
            for history in histories {
                if let existing = oldItems[history.id], existing.revision == history.modificationDate {
                    newItems[history.id] = existing
                } else {
                    newItems[history.id] = HistoryCollectionItem(history: history)
                    changedIDs.append(history.id)
                }
            }
            itemsByID = newItems

            for removedID in Set(oldItems.keys).subtracting(liveIDs) {
                imagePreparationTasks.removeValue(forKey: removedID)?.cancel()
                imagePreparationRevisions.removeValue(forKey: removedID)
                imageCache.removeImage(for: removedID)
            }

            if layoutChanged {
                collectionView.collectionViewLayout.invalidateLayout()
                changedIDs = newIDs
            }

            let orderChanged = displayedIDs != newIDs
            let shouldApplySnapshot = !hasAppliedInitialSnapshot || orderChanged || !changedIDs.isEmpty
            guard shouldApplySnapshot, let dataSource else { return }

            var snapshot = NSDiffableDataSourceSnapshot<Section, UUID>()
            snapshot.appendSections([.main])
            snapshot.appendItems(newIDs, toSection: .main)

            let existingIDs = Set(displayedIDs)
            let reconfigurableIDs = changedIDs.filter { existingIDs.contains($0) && liveIDs.contains($0) }
            if !reconfigurableIDs.isEmpty {
                snapshot.reconfigureItems(reconfigurableIDs)
            }

            let animateMove = hasAppliedInitialSnapshot && orderChanged
            displayedIDs = newIDs
            hasAppliedInitialSnapshot = true
            dataSource.apply(snapshot, animatingDifferences: animateMove)
        }

        func cancelImagePreparation() {
            imagePreparationTasks.values.forEach { $0.cancel() }
            imagePreparationTasks.removeAll()
            imagePreparationRevisions.removeAll()
        }

        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            collectionView.deselectItem(at: indexPath, animated: false)
            guard
                let id = dataSource?.itemIdentifier(for: indexPath),
                let history = historiesByID[id]
            else {
                return
            }
            onOpen(history)
        }

        func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
            for indexPath in indexPaths {
                guard
                    let id = dataSource?.itemIdentifier(for: indexPath),
                    let item = itemsByID[id]
                else {
                    continue
                }
                prepareImageIfNeeded(for: item, in: collectionView)
            }
        }

        func collectionView(
            _ collectionView: UICollectionView,
            layout collectionViewLayout: UICollectionViewLayout,
            sizeForItemAt indexPath: IndexPath
        ) -> CGSize {
            guard
                let id = dataSource?.itemIdentifier(for: indexPath),
                let item = itemsByID[id]
            else {
                return .zero
            }

            return CGSize(
                width: Self.itemWidth(
                    imageSize: item.imageSize,
                    maxHeight: maxHeight,
                    maxWidth: maxWidth
                ),
                height: HistoryCollectionView.preferredHeight(maxHeight: maxHeight)
            )
        }

        func collectionView(
            _ collectionView: UICollectionView,
            contextMenuConfigurationForItemsAt indexPaths: [IndexPath],
            point: CGPoint
        ) -> UIContextMenuConfiguration? {
            guard
                let indexPath = indexPaths.first,
                let id = dataSource?.itemIdentifier(for: indexPath),
                let item = itemsByID[id],
                let cell = collectionView.cellForItem(at: indexPath) as? HistoryCollectionViewCell
            else {
                return nil
            }

            let thumbnailView = cell.contextMenuPreviewView
            let thumbnailFrame = thumbnailView.convert(thumbnailView.bounds, to: collectionView)
            guard thumbnailFrame.contains(point) else { return nil }

            return UIContextMenuConfiguration(
                identifier: id as NSUUID,
                previewProvider: { [weak self] in
                    guard let self else { return nil }
                    let image = self.imageCache.image(for: id, revision: item.revision)
                        ?? self.imageCache.latestImage(for: id)
                        ?? UIImage(data: item.thumbnailData)
                    let imageHeight = Self.imageHeight(maxHeight: self.maxHeight)
                    let previewSize = CGSize(
                        width: Self.itemWidth(
                            imageSize: item.imageSize,
                            maxHeight: self.maxHeight,
                            maxWidth: self.maxWidth
                        ),
                        height: imageHeight
                    )
                    return HistoryThumbnailPreviewViewController(
                        item: item,
                        image: image,
                        imageHeight: imageHeight,
                        previewSize: previewSize
                    )
                },
                actionProvider: { [weak self] _ in
                    let deleteAction = UIAction(
                        title: String(localized: "Delete"),
                        image: UIImage(systemName: "trash"),
                        attributes: .destructive
                    ) { [weak self] _ in
                        guard let self, let history = self.historiesByID[id] else { return }
                        self.onDelete(history)
                    }
                    return UIMenu(children: [deleteAction])
                }
            )
        }

        func collectionView(
            _ collectionView: UICollectionView,
            contextMenuConfiguration: UIContextMenuConfiguration,
            highlightPreviewForItemAt indexPath: IndexPath
        ) -> UITargetedPreview? {
            targetedPreview(in: collectionView, at: indexPath)
        }

        func collectionView(
            _ collectionView: UICollectionView,
            contextMenuConfiguration: UIContextMenuConfiguration,
            dismissalPreviewForItemAt indexPath: IndexPath
        ) -> UITargetedPreview? {
            targetedPreview(in: collectionView, at: indexPath)
        }

        private func targetedPreview(
            in collectionView: UICollectionView,
            at indexPath: IndexPath
        ) -> UITargetedPreview? {
            guard
                let cell = collectionView.cellForItem(at: indexPath) as? HistoryCollectionViewCell
            else {
                return nil
            }

            let thumbnailView = cell.contextMenuPreviewView
            let parameters = UIPreviewParameters()
            parameters.backgroundColor = .clear
            parameters.visiblePath = UIBezierPath(
                roundedRect: thumbnailView.bounds,
                cornerRadius: HistoryTileContentView.cornerRadius
            )
            return UITargetedPreview(view: thumbnailView, parameters: parameters)
        }

        private func prepareImageIfNeeded(
            for item: HistoryCollectionItem,
            in collectionView: UICollectionView
        ) {
            if imageCache.image(for: item.id, revision: item.revision) != nil {
                return
            }
            if imagePreparationRevisions[item.id] == item.revision {
                return
            }

            imagePreparationTasks[item.id]?.cancel()
            imagePreparationRevisions[item.id] = item.revision

            let id = item.id
            let revision = item.revision
            let thumbnailData = item.thumbnailData
            imagePreparationTasks[id] = Task { [weak self, weak collectionView] in
                guard let sourceImage = UIImage(data: thumbnailData) else { return }
                let preparedImage = await sourceImage.byPreparingForDisplay() ?? sourceImage
                guard !Task.isCancelled, let self else { return }
                guard self.itemsByID[id]?.revision == revision else { return }

                self.imageCache.store(preparedImage, for: id, revision: revision)
                self.imagePreparationTasks.removeValue(forKey: id)
                self.imagePreparationRevisions.removeValue(forKey: id)

                guard
                    let collectionView,
                    let indexPath = self.dataSource?.indexPath(for: id),
                    let cell = collectionView.cellForItem(at: indexPath) as? HistoryCollectionViewCell
                else {
                    return
                }
                cell.setImage(preparedImage, for: id)
            }
        }

        private static func imageHeight(maxHeight: CGFloat) -> CGFloat {
            HistoryCollectionView.imageHeight(maxHeight: maxHeight)
        }

        private static func itemWidth(
            imageSize: CGSize,
            maxHeight: CGFloat,
            maxWidth: CGFloat
        ) -> CGFloat {
            let height = imageHeight(maxHeight: maxHeight)
            let aspectRatio: CGFloat
            if imageSize.height > 0 {
                aspectRatio = imageSize.width / imageSize.height
            } else {
                aspectRatio = 16.0 / 9.0
            }

            let clampedAspectRatio = min(max(aspectRatio, 1), 2)
            return min(max(height * clampedAspectRatio, 96), max(maxWidth, 96))
        }
    }
}

struct HistoryCollectionItem {
    let id: UUID
    let revision: Date
    let title: String
    let progress: CGFloat
    let thumbnailData: Data
    let imageSize: CGSize

    @MainActor
    init(history: VideoHistory) {
        id = history.id
        revision = history.modificationDate
        title = history.displayTitle
        thumbnailData = history.thumbnailData
        imageSize = UIImage(data: history.thumbnailData)?.size ?? .zero

        if history.position.isFinite {
            progress = CGFloat(min(max(history.position, 0), 1))
        } else {
            progress = 0
        }
    }
}

@MainActor
private final class FullResolutionHistoryImageCache {
    private let images = NSCache<NSUUID, UIImage>()
    private var revisions: [UUID: Date] = [:]

    init() {
        images.countLimit = 20
        images.totalCostLimit = 96 * 1_024 * 1_024
    }

    func image(for id: UUID, revision: Date) -> UIImage? {
        guard revisions[id] == revision else { return nil }
        return images.object(forKey: id as NSUUID)
    }

    func latestImage(for id: UUID) -> UIImage? {
        images.object(forKey: id as NSUUID)
    }

    func store(_ image: UIImage, for id: UUID, revision: Date) {
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let cost = Int(pixelWidth * pixelHeight * 4)
        images.setObject(image, forKey: id as NSUUID, cost: cost)
        revisions[id] = revision
    }

    func removeImage(for id: UUID) {
        images.removeObject(forKey: id as NSUUID)
        revisions.removeValue(forKey: id)
    }
}
