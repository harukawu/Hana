//
//  SubtitlesTableView.swift
//  Hana
//
//  Created by Haruka on 2026/7/6.
//

import UIKit
import SwiftUI

struct SubtitlesTableView: UIViewControllerRepresentable {
    @Binding var selectedCueIndices: Set<Int>
    let subtitles: [SubtitleCue]
    let highlightedIndex: Int?
    let onTap: ((TappableLabelCharacterHit, String) -> Void)?
    
    func makeUIViewController(context: Context) -> UISubtitlesTableViewController {
        return UISubtitlesTableViewController(subtitles: subtitles, selectedCueIndices: $selectedCueIndices, highlightedIndex: highlightedIndex, onTap: onTap)
    }
    
    func updateUIViewController(_ uiViewController: UISubtitlesTableViewController, context: Context) {}
}

final class UISubtitlesTableViewController: UIViewController {
    private enum Metrics {
        static let estimatedRowHeight: CGFloat = 112
        static let verticalContentInset: CGFloat = 10
        static let scrollIndicatorInset: CGFloat = 4
    }
    
    private static let reuseIdentifier = "UISubtitlesTableViewCell"
    
    private let tableView = UITableView(frame: .zero, style: .plain)
    
    private let subtitles: [SubtitleCue]
    @Binding var selectedCueIndices: Set<Int>
    private let highlightedIndex: Int?
    private let onTap: ((TappableLabelCharacterHit, String) -> Void)?
    private var hasPositionedHighlightedRow = false
    
    init(subtitles: [SubtitleCue], selectedCueIndices: Binding<Set<Int>>, highlightedIndex: Int?, onTap: ((TappableLabelCharacterHit, String) -> Void)? = nil) {
        self.subtitles = subtitles
        self._selectedCueIndices = selectedCueIndices
        self.highlightedIndex = highlightedIndex
        self.onTap = onTap
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        centerHighlightedRowIfNeeded()
    }
    
    private func setupTableView() {
        view.backgroundColor = .systemBackground
        
        tableView.register(UISubtitlesTableViewCell.self, forCellReuseIdentifier: Self.reuseIdentifier)
        tableView.dataSource = self
        tableView.allowsSelection = false
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = Metrics.estimatedRowHeight
        tableView.contentInset = UIEdgeInsets(
            top: Metrics.verticalContentInset,
            left: 0,
            bottom: Metrics.verticalContentInset,
            right: 0
        )
        tableView.verticalScrollIndicatorInsets = UIEdgeInsets(
            top: Metrics.scrollIndicatorInset,
            left: 0,
            bottom: Metrics.scrollIndicatorInset,
            right: 0
        )
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.keyboardDismissMode = .interactive
        
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    private func centerHighlightedRowIfNeeded() {
        guard !hasPositionedHighlightedRow,
              let highlightedIndex,
              subtitles.indices.contains(highlightedIndex),
              tableView.bounds.height > 0 else {
            return
        }
        hasPositionedHighlightedRow = true
        
        let indexPath = IndexPath(row: highlightedIndex, section: 0)
        
        // Make the target visible once so its self-sizing height is resolved, then
        // calculate the final offset using the measured row geometry.
        tableView.layoutIfNeeded()
        tableView.scrollToRow(at: indexPath, at: .middle, animated: false)
        tableView.layoutIfNeeded()
        
        let rowFrame = tableView.rectForRow(at: indexPath)
        let minimumOffset = -tableView.adjustedContentInset.top
        let maximumOffset = max(
            minimumOffset,
            tableView.contentSize.height
                - tableView.bounds.height
                + tableView.adjustedContentInset.bottom
        )
        let centeredOffset = rowFrame.midY - tableView.bounds.height / 2
        let clampedOffset = min(max(centeredOffset, minimumOffset), maximumOffset)
        
        tableView.setContentOffset(
            CGPoint(x: tableView.contentOffset.x, y: clampedOffset),
            animated: false
        )
    }
}

extension UISubtitlesTableViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return subtitles.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Self.reuseIdentifier, for: indexPath) as! UISubtitlesTableViewCell
        if let onTap {
            cell.setOnTap(onTap)
        }
        let currentIndex = indexPath.row
        let currentCue = subtitles[currentIndex]
        cell.setCue(currentCue)
        cell.setHighlight(enable: highlightedIndex == currentIndex)
        cell.setSelected(isSelected: selectedCueIndices.contains(currentIndex))
        cell.setSeparatorHidden(currentIndex == subtitles.indices.last)
        cell.setOnSelected { [weak self] isSelected in
            guard let self else {
                return
            }
            
            if isSelected {
                self.selectedCueIndices.insert(currentIndex)
            } else {
                self.selectedCueIndices.remove(currentIndex)
            }
        }
        return cell
    }
}
