//
//  VolumeObserverView.swift
//  Hana
//
//  Created by Haruka on 2026/7/10.
//

import MediaPlayer
import SwiftUI

struct VolumeObserverView: UIViewRepresentable {
    let onVolumeChange: ((Float) -> Void)?
    
    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView()
        if let slider = view.subviews.first(where: { $0 is UISlider }) as? UISlider {
            slider.addTarget(
                context.coordinator,
                action: #selector(Coordinator.handleVolumeChange(sender:forEvent:)),
                for: .valueChanged
            )
        }
        return view
    }
    
    func updateUIView(_ uiView: MPVolumeView, context: Context) {
        context.coordinator.parent = self
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    @MainActor
    class Coordinator {
        var parent: VolumeObserverView
        var initiated = false
        
        init(parent: VolumeObserverView) {
            self.parent = parent
        }
        
        @objc
        func handleVolumeChange(sender: UISlider, forEvent event: UIEvent) {
            if initiated {
                parent.onVolumeChange?(sender.value)
            } else {
                initiated = true
            }
        }
    }
}
