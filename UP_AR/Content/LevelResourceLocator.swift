//
//  LevelResourceLocator.swift
//  UP_AR (UniPlace)
//
//  Resolves level files in the app bundle. Prefers an ASTC-compiled `.reality` sibling over the raw
//  `.usdz` named in the manifest (the optimize script ships textured layers only as `.reality`), so
//  the manifest never has to be touched. Tries the preserved `Content/TestLevel` subdirectory first,
//  then a flat-bundle fallback, so it works regardless of how Xcode lays the resources out.
//

import Foundation

struct LevelResourceLocator {
    /// Bundle subdirectory the explicit `Content/TestLevel` folder lands in (its last path component).
    let subdirectory: String
    private let bundle: Bundle

    init(subdirectory: String = "TestLevel", bundle: Bundle = .main) {
        self.subdirectory = subdirectory
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
    func loadMaterialConfig(named name: String) throws -> MaterialConfig { try decode(name) }

    private func decode<T: Decodable>(_ name: String) throws -> T {
        guard let url = lookup(base: name, ext: "json") else {
            throw LocatorError.missing("\(name).json")
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func lookup(base: String, ext: String) -> URL? {
        bundle.url(forResource: base, withExtension: ext, subdirectory: subdirectory)
            ?? bundle.url(forResource: base, withExtension: ext)
    }
}
