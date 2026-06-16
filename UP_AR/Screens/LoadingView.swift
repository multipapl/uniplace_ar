//
//  LoadingView.swift
//  UP_AR (UniPlace)
//
//  First screen while the AR shell is mounted and RealityKit warms up.
//

import SwiftUI

struct LoadingView: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [.black, Color(white: 0.1)],
                           startPoint: .top,
                           endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Text("UniPlace")
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                ProgressView()
                    .tint(.white)
            }
            .foregroundStyle(.white)
        }
    }
}
