//
//  View+Orientation.swift
//  Hana
//
//  Created by Haruka on 2026/7/6.
//

import SwiftUI

private struct InterfaceOrientationModifier: ViewModifier {
    let orientation: UIInterfaceOrientationMask
    let restore: UIInterfaceOrientationMask
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                Self.set(orientation)
            }
            .onDisappear {
                Self.set(restore)
            }
    }
    
    static func set(_ mask: UIInterfaceOrientationMask) {
        AppDelegate.orientationMask = mask
        
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else { return }
        
        scene.keyWindow?
            .rootViewController?
            .setNeedsUpdateOfSupportedInterfaceOrientations()
        
        let preferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: mask)

        scene.requestGeometryUpdate(preferences) { error in
            print("Orientation request failed:", error)
        }
    }
}

extension View {
    func interfaceOrientation(
        _ orientation: UIInterfaceOrientationMask,
        restoreTo restore: UIInterfaceOrientationMask = .portrait
    ) -> some View {
        modifier(
            InterfaceOrientationModifier(
                orientation: orientation,
                restore: restore
            )
        )
    }
}
