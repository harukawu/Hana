//
//  UIScreen+.swift
//  Hana
//
//  Created by Haruka on 2026/7/6.
//

import UIKit

extension UIScreen {
    static var keyScreen: UIScreen? {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen
    }
}

