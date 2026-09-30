//
//  GradientLoader.swift
//  MarketBrief
//
//  Created by Henry Forrest on 30/09/2026.
//

import SwiftUI

// MARK: - Gradient Loader

/// The animated ring shown while a request is in flight.
struct GradientLoader: View {
    @State private var animate = false
    
    var body: some View {
        Circle()
            .trim(from: 0.15, to: 1)
            .stroke(
                AngularGradient(
                    gradient: Gradient(colors: [.blue, .purple, .pink, .blue]),
                    center: .center
                ),
                style: StrokeStyle(lineWidth: 10, lineCap: .round)
            )
            .frame(width: 60, height: 60)
            .rotationEffect(.degrees(animate ? 360 : 0))
            .animation(.linear(duration: 1.4).repeatForever(autoreverses: false), value: animate)
            .onAppear { animate = true }
    }
}
