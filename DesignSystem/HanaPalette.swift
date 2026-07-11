//
//  HanaPalette.swift
//  Hana
//
//  Created by Haruka on 2026/7/10.
//

import SwiftUI

enum HanaPalette {
    static let butterYellow = Color(red: 0.89, green: 0.73, blue: 0.36)
    static let powderBlue = Color(red: 0.42, green: 0.64, blue: 0.80)
    static let lavender = Color(red: 0.58, green: 0.50, blue: 0.76)
    static let dustyBlue = Color(red: 0.49, green: 0.56, blue: 0.66)
    static let controlTint = Color(red: 0.48, green: 0.28, blue: 0.31)

    static let ruby = Color(red: 0.91, green: 0.20, blue: 0.29)
    static let coral = Color(red: 0.97, green: 0.38, blue: 0.29)
    private static let blush = Color(red: 0.98, green: 0.66, blue: 0.73)
    private static let plum = Color(red: 0.61, green: 0.29, blue: 0.55)

    static var progressGradient: LinearGradient {
        LinearGradient(
            colors: [ruby, coral],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static func background(for colorScheme: ColorScheme) -> some View {
        ZStack {
            if colorScheme == .dark {
                Color(red: 0.065, green: 0.035, blue: 0.045)

                RadialGradient(
                    colors: [ruby.opacity(0.22), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 440
                )

                RadialGradient(
                    colors: [plum.opacity(0.13), .clear],
                    center: .bottomTrailing,
                    startRadius: 0,
                    endRadius: 560
                )
            } else {
                Color(red: 0.985, green: 0.975, blue: 0.97)

                RadialGradient(
                    colors: [blush.opacity(0.34), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 470
                )

                RadialGradient(
                    colors: [coral.opacity(0.16), .clear],
                    center: .bottomTrailing,
                    startRadius: 0,
                    endRadius: 590
                )

                RadialGradient(
                    colors: [.white.opacity(0.72), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 360
                )
            }
        }
        .ignoresSafeArea()
    }
}
