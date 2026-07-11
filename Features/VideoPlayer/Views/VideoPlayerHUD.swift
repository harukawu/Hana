//
//  VideoPlayerHUD.swift
//  Hana
//
//  Created by Haruka on 2026/7/6.
//

import SwiftUI

struct VideoPlayerHUD: View {
    let state: VideoPlayerHUDState
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: state.systemImage)
                .font(.title3.weight(.semibold))
                .frame(width: 26)
            
            Text(state.title)
                .font(.headline.monospacedDigit())
            
//            if let fraction = state.fraction {
//                ProgressView(value: Double(fraction))
//                    .tint(.white)
//                    .frame(width: 150)
//            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.black.opacity(0.2), in: .rect(cornerRadius: 24))
        .background(.ultraThinMaterial.opacity(0.3), in: .rect(cornerRadius: 24))
    }
}
