//
//  VideoContentMode.swift
//  Hana
//
//  Created by Haruka on 2026/7/6.
//

import SwiftVLC

enum VideoContentMode: String, CaseIterable, Identifiable, Sendable {
    case fit
    case fill
    case ratio16x9
    case ratio4x3
    case ratio1x1
    case ratio21x9
    
    var id: Self { self }
    
    var title: String {
        switch self {
        case .fit:
            "Fit"
        case .fill:
            "Fill"
        case .ratio16x9:
            "16:9"
        case .ratio4x3:
            "4:3"
        case .ratio1x1:
            "1:1"
        case .ratio21x9:
            "21:9"
        }
    }
    
    var systemImage: String {
        switch self {
        case .fit:
            "arrow.up.left.and.arrow.down.right"
        case .fill:
            "arrow.down.right.and.arrow.up.left"
        case .ratio16x9, .ratio4x3, .ratio1x1, .ratio21x9:
            "aspectratio"
        }
    }
    
    var aspectRatio: AspectRatio {
        switch self {
        case .fit:
            .default
        case .fill:
            .fill
        case .ratio16x9:
            .ratio(16, 9)
        case .ratio4x3:
            .ratio(4, 3)
        case .ratio1x1:
            .ratio(1, 1)
        case .ratio21x9:
            .ratio(21, 9)
        }
    }
}
