//
//  View+.swift
//  Hana
//
//  Created by Haruka on 2026/7/6.
//

import SwiftUI

struct ConditionalNavigationTitle: ViewModifier {
    let title: String
    let condition: Bool
    
    func body(content: Content) -> some View {
        if condition {
            content
                .navigationTitle(title)
        } else {
            content
        }
    }
}

extension View {
    func navigationTitle(_ title: String, if condition: Bool) -> ModifiedContent<Self, ConditionalNavigationTitle> {
        modifier(ConditionalNavigationTitle(title: title, condition: condition))
    }
}

struct LightSchemePreference: ViewModifier {
    let preferLightScheme: Bool?
    
    func body(content: Content) -> some View {
        if let preferLightScheme {
            content
                .preferredColorScheme(preferLightScheme ? .light : .dark)
        } else {
            content
        }
    }
}

extension View {
    func preferLightScheme(_ preference: Bool?) -> some View {
        modifier(LightSchemePreference(preferLightScheme: preference))
    }
}
