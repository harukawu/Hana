//
//  VideoPlayerAdvancedSettingsPlaceholder.swift
//  Hana
//
//  Created by Haruka on 2026/7/6.
//

import SwiftUI

struct VideoPlayerAdvancedSettingsPlaceholder: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black
                .ignoresSafeArea()
            
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
            .padding(28)
        }
    }
}
