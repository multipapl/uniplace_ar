//
//  LoadingView.swift
//  UP_AR (UniPlace)
//
//  First screen while the AR shell is mounted and RealityKit warms up.
//

import SwiftUI
import UIKit

struct LoadingView: View {
    var body: some View {
        ZStack {
            GalleryLoadingBackground()

            VStack {
                Spacer()
                ChromePanel {
                    VStack(spacing: 16) {
                        Text("UniPlace")
                            .font(.system(size: 34, weight: .semibold))
                        ProgressView()
                            .tint(.black)
                        Text("Loading scene")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.black.opacity(0.56))
                    }
                    .foregroundStyle(.black)
                    .frame(width: 230)
                }
                Spacer()
                    .frame(maxHeight: 96)
            }
            .padding(.horizontal, 18)
        }
    }
}

private struct GalleryLoadingBackground: View {
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .blur(radius: 1.4, opaque: true)
                        .scaleEffect(1.01)
                        .clipped()
                } else {
                    BlurredCoverBackground(imageName: "loading_screen", blurRadius: 3, dimOpacity: 0)
                }

                Color.black.opacity(0.42)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .onAppear {
            chooseImage()
        }
    }

    private func chooseImage() {
        guard let url = GalleryLibrary.stills().randomElement() else {
            image = nil
            return
        }
        image = UIImage(contentsOfFile: url.path)
    }
}
