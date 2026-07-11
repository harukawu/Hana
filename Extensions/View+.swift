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
