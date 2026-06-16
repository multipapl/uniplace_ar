//
//  BlurredCoverBackground.swift
//  UP_AR (UniPlace)
//
//  Shared full-screen image background for shell screens.
//

import SwiftUI
import UIKit

struct BlurredCoverBackground: View {
    let imageName: String
    var blurRadius: CGFloat = 5
    var dimOpacity: Double = 0.34

    private var image: UIImage? {
        UIImage.contentUIImage(named: imageName)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .blur(radius: blurRadius, opaque: true)
                        .scaleEffect(1.04)
                } else {
                    LinearGradient(colors: [.black, Color(white: 0.1)],
                                   startPoint: .top,
                                   endPoint: .bottom)
                }

                Color.black.opacity(dimOpacity)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
    }
}

private extension UIImage {
    static func contentUIImage(named imageName: String) -> UIImage? {
        guard let url = Bundle.main.url(forResource: imageName,
                                        withExtension: "jpg",
                                        subdirectory: "UI") else {
            return nil
        }

        return UIImage(contentsOfFile: url.path)
    }
}
