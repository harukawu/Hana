//
//  UISubtitlesTableViewCell.swift
//  Hana
//
//  Created by Haruka on 2026/7/6.
//

import UIKit

// MARK: - Cell
final class UISubtitlesTableViewCell: UITableViewCell {
    private enum Metrics {
        static let contentInset: CGFloat = 18
        static let metadataSpacing: CGFloat = 8
        static let textBottomInset: CGFloat = 12
        static let highlightWidth: CGFloat = 3
        static let highlightHeight: CGFloat = 32
        static let buttonSize: CGFloat = 44
        static let separatorHeight: CGFloat = 0.5
    }
    
    private var onSelected: ((Bool) -> Void)?
    private var selectionStatus = false
    private var highlightsCurrentCue = false
    
    private let cardView = UIView()
    private let highlightView = UIView()
    private let separatorView = UIView()
    private let selectionButton = UIButton(configuration: .plain())
    private let subtitleTextLabel = UITappableLabel()
    private let timestampBadge = UISubtitleCellTimeStampBadge()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        subtitleTextLabel.onCharacterTap = nil
        onSelected = nil
        setHighlight(enable: false)
        setSelected(isSelected: false)
    }
    
    override func tintColorDidChange() {
        super.tintColorDidChange()
        updateAppearance()
    }
    
    private func setup() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none
        
        highlightView.backgroundColor = tintColor
        highlightView.layer.cornerCurve = .continuous
        highlightView.layer.cornerRadius = Metrics.highlightWidth / 2
        separatorView.backgroundColor = UIColor.separator.withAlphaComponent(0.18)
        
        subtitleTextLabel.numberOfLines = 0
        subtitleTextLabel.lineBreakMode = .byWordWrapping
        
        timestampBadge.imageView.contentMode = .scaleAspectFit
        timestampBadge.imageView.tintColor = .secondaryLabel
        timestampBadge.imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
            textStyle: .caption2,
            scale: .small
        )
        timestampBadge.timeRangeLabel.font = .monospacedDigitSystemFont(
            ofSize: UIFont.preferredFont(forTextStyle: .caption2).pointSize,
            weight: .semibold
        )
        timestampBadge.timeRangeLabel.textColor = .secondaryLabel

        selectionButton.isPointerInteractionEnabled = true
        selectionButton.addTarget(self, action: #selector(self.toggleSelection), for: .touchUpInside)
        
        contentView.addSubview(cardView)
        cardView.addSubview(highlightView)
        cardView.addSubview(separatorView)
        cardView.addSubview(subtitleTextLabel)
        cardView.addSubview(timestampBadge)
        cardView.addSubview(selectionButton)
        
        cardView.translatesAutoresizingMaskIntoConstraints = false
        highlightView.translatesAutoresizingMaskIntoConstraints = false
        separatorView.translatesAutoresizingMaskIntoConstraints = false
        subtitleTextLabel.translatesAutoresizingMaskIntoConstraints = false
        timestampBadge.translatesAutoresizingMaskIntoConstraints = false
        selectionButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            highlightView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            highlightView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            highlightView.widthAnchor.constraint(equalToConstant: Metrics.highlightWidth),
            highlightView.heightAnchor.constraint(equalToConstant: Metrics.highlightHeight),
            
            timestampBadge.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: Metrics.contentInset),
            timestampBadge.trailingAnchor.constraint(lessThanOrEqualTo: selectionButton.leadingAnchor, constant: -Metrics.metadataSpacing),
            timestampBadge.centerYAnchor.constraint(equalTo: selectionButton.centerYAnchor),
            
            subtitleTextLabel.leadingAnchor.constraint(equalTo: timestampBadge.leadingAnchor),
            subtitleTextLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -Metrics.contentInset),
            subtitleTextLabel.topAnchor.constraint(equalTo: selectionButton.bottomAnchor),
            subtitleTextLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -Metrics.textBottomInset),
            
            selectionButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            selectionButton.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 2),
            selectionButton.widthAnchor.constraint(equalToConstant: Metrics.buttonSize),
            selectionButton.heightAnchor.constraint(equalToConstant: Metrics.buttonSize),
            
            separatorView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: Metrics.contentInset),
            separatorView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -Metrics.contentInset),
            separatorView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor),
            separatorView.heightAnchor.constraint(equalToConstant: Metrics.separatorHeight)
        ])
        
        updateAppearance()
    }
    
    @objc
    private func toggleSelection() {
        selectionStatus.toggle()
        updateSelectionButton(animated: true)
        onSelected?(selectionStatus)
    }
    
    func setOnTap(_ onCharacterTap: @escaping ((TappableLabelCharacterHit, String) -> Void)) {
        subtitleTextLabel.onCharacterTap = onCharacterTap
    }
    
    func setCue(_ cue: borrowing SubtitleCue) {
        subtitleTextLabel.text = cue.text
        timestampBadge.setCue(cue)
    }
    
    func setHighlight(enable: Bool) {
        highlightsCurrentCue = enable
        updateAppearance()
    }
    
    func setSelected(isSelected: Bool) {
        selectionStatus = isSelected
        updateSelectionButton(animated: false)
    }
    
    func setOnSelected(_ onSelected: @escaping ((Bool) -> Void)) {
        self.onSelected = onSelected
    }
    
    func setSeparatorHidden(_ isHidden: Bool) {
        separatorView.isHidden = isHidden
    }
    
    private func updateAppearance() {
        highlightView.isHidden = !highlightsCurrentCue
        highlightView.backgroundColor = tintColor
        timestampBadge.imageView.tintColor = highlightsCurrentCue ? tintColor : .secondaryLabel
        timestampBadge.timeRangeLabel.textColor = highlightsCurrentCue ? tintColor : .secondaryLabel
        cardView.backgroundColor = .clear
        cardView.layer.borderWidth = 0
        cardView.layer.borderColor = nil
    }
    
    private func updateSelectionButton(animated: Bool) {
        let updates = {
            var configuration = UIButton.Configuration.plain()
            configuration.image = UIImage(
                systemName: self.selectionStatus ? "star.fill" : "star"
            )
            configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(
                pointSize: 15,
                weight: .medium
            )
            configuration.contentInsets = .zero
            configuration.baseForegroundColor = self.selectionStatus
                ? self.tintColor
                : .tertiaryLabel
            self.selectionButton.configuration = configuration
        }
        
        guard animated else {
            updates()
            return
        }
        
        UIView.transition(
            with: selectionButton,
            duration: 0.18,
            options: [.transitionCrossDissolve, .allowUserInteraction],
            animations: updates
        )
    }
}


// MARK: - Timestamp View
class UISubtitleCellTimeStampBadge: UIView {
    let imageView: UIImageView
    let timeRangeLabel: UILabel
    
    required init?(coder: NSCoder) {
        fatalError()
    }
    
    init() {
        self.imageView = UIImageView()
        self.timeRangeLabel = UILabel()
        super.init(frame: .zero)
        
        setup()
    }
    
    func setCue(_ cue: borrowing SubtitleCue) {
        timeRangeLabel.text = Self.formatTimeRange(start: cue.startTime, end: cue.endTime)
    }
    
    private func setup() {
        let image = UIImage(systemName: "clock")!
        imageView.image = image
        
        self.addSubview(imageView)
        self.addSubview(timeRangeLabel)
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        timeRangeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            timeRangeLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 10),
            timeRangeLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            timeRangeLabel.topAnchor.constraint(equalTo: topAnchor),
            timeRangeLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
            imageView.heightAnchor.constraint(equalTo: timeRangeLabel.heightAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    
    private static func formatTimeRange(start: Duration, end: Duration) -> String {
        "\(formatTime(start)) → \(formatTime(end))"
    }
    
    private static func formatTime(_ time: Duration) -> String {
        let timeInSeconds = time.toSeconds()
        
        let hours = Int(timeInSeconds) / 3600
        let minutes = (Int(timeInSeconds) % 3600) / 60
        let seconds = Int(timeInSeconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}
