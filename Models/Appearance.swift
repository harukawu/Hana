//
//  Appearance.swift
//  Hana
//
//  Created by Haruka on 2026/7/20.
//

import Foundation

enum Themes: Codable, CaseIterable {
    case system
    case light
    case dark
    
    var title: String {
        switch self {
        case .light:
            String(localized: "Light")
        case .dark:
            String(localized: "Dark")
        case .system:
            String(localized: "System")
        }
    }
    
    var preferLightScheme: Bool? {
        switch self {
        case .system:
            nil
        case .light:
            true
        case .dark:
            false
        }
    }
}
