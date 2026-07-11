//
//  HistoryTileUIKitView.swift
//  Hana
//

import SwiftUI
import UIKit

@MainActor
final class HistoryCollectionViewCell: UICollectionViewCell {
    static let reuseIdentifier = "HistoryCollectionViewCell"

    private let tileView = HistoryTileContentView()
    private var representedID: UUID?
    private var imageHeight: CGFloat = 0

    var contextMenuPreviewView: UIView {
        tileView.contextMenuPreviewView
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(tileView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        tileView.frame = contentView.bounds
        tileView.imageHeight = imageHeight
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        representedID = nil
        tileView.prepareForReuse()
    }

    func configure(item: HistoryCollectionItem, image: UIImage?, imageHeight: CGFloat) {
        representedID = item.id
        self.imageHeight = imageHeight
        tileView.configure(item: item, image: image, imageHeight: imageHeight)

        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = item.title
        accessibilityValue = String(localized: "Watched \(Int((item.progress * 100).rounded())) percent")
    }

    func setImage(_ image: UIImage, for id: UUID) {
        guard representedID == id else { return }
        tileView.image = image
    }
}

@MainActor
final class HistoryTileContentView: UIView {
    static let cornerRadius: CGFloat = 15
    static let progressBarHeight: CGFloat = 4
    static let titleSpacing: CGFloat = 4
    static let titleFont: UIFont = {
        let baseFont = UIFont.systemFont(ofSize: 12, weight: .bold)
        return UIFontMetrics(forTextStyle: .caption1).scaledFont(for: baseFont)
    }()

    private let thumbnailView = UIView()
    private let imageView = UIImageView()
    private let progressView = HistoryProgressView()
    private let titleLabel = UILabel()
    private let playImageView = UIImageView()

    var contextMenuPreviewView: UIView {
        thumbnailView
    }

    var imageHeight: CGFloat = 0 {
        didSet {
            setNeedsLayout()
        }
    }

    var image: UIImage? {
        get { imageView.image }
        set { imageView.image = newValue }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        thumbnailView.backgroundColor = .secondarySystemBackground
        thumbnailView.clipsToBounds = true
        thumbnailView.layer.cornerRadius = Self.cornerRadius
        thumbnailView.layer.cornerCurve = .continuous

        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true

        titleLabel.font = Self.titleFont
        titleLabel.textColor = .label
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.numberOfLines = 1
        titleLabel.adjustsFontForContentSizeCategory = true

        let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        playImageView.image = UIImage(systemName: "play.fill", withConfiguration: symbolConfiguration)
        playImageView.tintColor = .white
        playImageView.contentMode = .center

        addSubview(thumbnailView)
        thumbnailView.addSubview(imageView)
        thumbnailView.addSubview(playImageView)
        thumbnailView.addSubview(progressView)
        addSubview(titleLabel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        thumbnailView.frame = CGRect(x: 0, y: 0, width: bounds.width, height: imageHeight)
        imageView.frame = thumbnailView.bounds
        progressView.frame = CGRect(
            x: 0,
            y: max(0, imageHeight - Self.progressBarHeight),
            width: bounds.width,
            height: Self.progressBarHeight
        )

        let indicatorSize = CGSize(width: 44, height: 44)
        playImageView.frame = CGRect(
            x: (bounds.width - indicatorSize.width) / 2 + 1,
            y: (imageHeight - indicatorSize.height) / 2,
            width: indicatorSize.width,
            height: indicatorSize.height
        )

        let titleY = imageHeight + Self.titleSpacing
        titleLabel.frame = CGRect(
            x: 0,
            y: titleY,
            width: bounds.width,
            height: max(0, bounds.height - titleY)
        )
    }

    func configure(item: HistoryCollectionItem, image: UIImage?, imageHeight: CGFloat) {
        self.imageHeight = imageHeight
        self.image = image
        titleLabel.text = item.title
        progressView.progress = item.progress
    }

    func prepareForReuse() {
        image = nil
        titleLabel.text = nil
        progressView.progress = 0
    }
}

@MainActor
private final class HistoryProgressView: UIView {
    private let gradientLayer = CAGradientLayer()

    var progress: CGFloat = 0 {
        didSet {
            progress = min(max(progress, 0), 1)
            setNeedsLayout()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        gradientLayer.colors = [
            UIColor(HanaPalette.ruby).cgColor,
            UIColor(HanaPalette.coral).cgColor,
        ]
        layer.addSublayer(gradientLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = CGRect(
            x: 0,
            y: 0,
            width: bounds.width * progress,
            height: bounds.height
        )
    }
}

@MainActor
final class HistoryThumbnailPreviewViewController: UIViewController {
    private let tileView = HistoryTileContentView()
    private let imageHeight: CGFloat
    private let previewSize: CGSize

    init(
        item: HistoryCollectionItem,
        image: UIImage?,
        imageHeight: CGFloat,
        previewSize: CGSize
    ) {
        self.imageHeight = imageHeight
        self.previewSize = previewSize
        super.init(nibName: nil, bundle: nil)
        tileView.configure(item: item, image: image, imageHeight: imageHeight)
        tileView.clipsToBounds = true
        preferredContentSize = previewSize
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.addSubview(tileView)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tileView.frame = CGRect(origin: .zero, size: previewSize)
        tileView.imageHeight = imageHeight
    }
}
