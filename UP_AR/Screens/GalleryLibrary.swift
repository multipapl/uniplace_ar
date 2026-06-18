//
//  GalleryLibrary.swift
//  UP_AR (UniPlace)
//
//  Lightweight access to bundled presentation media copied from the AVP gallery.
//

import Foundation

struct GalleryMediaItem: Identifiable, Equatable {
    enum Kind {
        case image
        case video
    }

    let url: URL
    let kind: Kind

    var id: String { url.path }

    var title: String {
        url.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}

enum GalleryLibrary {
    private static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "webp"]
    private static let videoExtensions: Set<String> = ["mp4", "mov", "m4v"]

    static func items(bundle: Bundle = .main) -> [GalleryMediaItem] {
        mediaURLs(bundle: bundle).compactMap { url in
            let ext = url.pathExtension.lowercased()
            if imageExtensions.contains(ext) {
                return GalleryMediaItem(url: url, kind: .image)
            }
            if videoExtensions.contains(ext) {
                return GalleryMediaItem(url: url, kind: .video)
            }
            return nil
        }
    }

    static func stills(bundle: Bundle = .main) -> [URL] {
        items(bundle: bundle)
            .filter { $0.kind == .image }
            .map(\.url)
    }

    private static func mediaURLs(bundle: Bundle) -> [URL] {
        guard let root = galleryRootURL(bundle: bundle),
              let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
              ) else {
            return []
        }

        return enumerator
            .compactMap { $0 as? URL }
            .filter { url in
                let ext = url.pathExtension.lowercased()
                return imageExtensions.contains(ext) || videoExtensions.contains(ext)
            }
            .sorted {
                $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
            }
    }

    private static func galleryRootURL(bundle: Bundle) -> URL? {
        guard let resourceURL = bundle.resourceURL else { return nil }
        let galleryURL = resourceURL.appendingPathComponent("Gallery", isDirectory: true)
        guard FileManager.default.fileExists(atPath: galleryURL.path) else { return nil }
        return galleryURL
    }
}
