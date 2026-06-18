//
//  LevelResourceLocator.swift
//  UP_AR (UniPlace)
//
//  Resolves level files in the app bundle. Prefers an ASTC-compiled `.reality` sibling over the raw
//  `.usdz` named in the manifest (the optimize script ships textured layers only as `.reality`), so the
//  manifest never has to be touched. Content is split into per-scene subfolders (`Shared`, `Floor`,
//  `Terrace`); layer file names are globally unique (LO_/TR_ prefixes), so we just search every content
//  subfolder and fall back to a flat bundle lookup — no scene→folder mapping needed.
//

import Foundation

struct LevelResourceLocator {
    /// Bundle subdirectories searched in order; the optimizer's content folders.
    let subdirectories: [String]
    private let bundle: Bundle

    init(subdirectories: [String] = ["Shared", "Floor", "Terrace", "ProbesTextures"], bundle: Bundle = .main) {
        self.subdirectories = subdirectories
        self.bundle = bundle
    }

    enum LocatorError: LocalizedError {
        case missing(String)
        var errorDescription: String? {
            switch self {
            case .missing(let name): return "missing bundled resource: \(name)"
            }
        }
    }

    /// Resolve a layer file, preferring a compiled `.reality` over the manifest's `.usdz`.
    func resolve(_ name: String) throws -> URL {
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension.lowercased()
        let candidates = (ext == "usdz") ? ["reality", "usdz"] : [ext]
        for candidate in candidates {
            if let url = lookup(base: base, ext: candidate) { return url }
        }
        throw LocatorError.missing(name)
    }

    func loadManifest(named name: String) throws -> LevelManifest { try decode(name) }

    private func decode<T: Decodable>(_ name: String) throws -> T {
        guard let url = lookup(base: name, ext: "json") else {
            throw LocatorError.missing("\(name).json")
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// Search each content subfolder, then the flat bundle root.
    private func lookup(base: String, ext: String) -> URL? {
        for subdirectory in subdirectories {
            if let url = bundle.url(forResource: base, withExtension: ext, subdirectory: subdirectory) {
                return url
            }
        }
        return bundle.url(forResource: base, withExtension: ext)
    }
}
