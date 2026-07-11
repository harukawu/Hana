//
//  Duration+.swift
//  Hana
//
//  Created by Haruka on 2026/7/6.
//

extension Duration {
    func toSeconds() -> Double {
        self / .seconds(1)
    }
}
