//
//  SettingsStyle.swift
//  Hana
//
//  Created by Haruka on 2026/7/10.
//

import SwiftUI

extension View {
    func hanaSettingsScreen() -> some View {
        modifier(HanaSettingsScreenModifier())
    }

    func hanaSettingsRow() -> some View {
        listRowBackground(
            Rectangle()
                .fill(.ultraThinMaterial.opacity(0.7))
        )
    }
}

private struct HanaSettingsScreenModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(HanaPalette.background(for: colorScheme))
            .tint(HanaPalette.controlTint)
    }
}
