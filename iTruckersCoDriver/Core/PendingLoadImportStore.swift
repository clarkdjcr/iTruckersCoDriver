//
//  PendingLoadImportStore.swift
//  iTruckersCoDriver
//
//  Hand-off point between LoadShareExtension and the main app. The extension
//  writes shared text/images here; the app reads, parses, and clears them.
//  Must be added to BOTH the iTruckersCoDriver and LoadShareExtension target
//  memberships in Xcode (File Inspector > Target Membership) since it lives
//  outside the extension's own synchronized folder.
//

import Foundation

struct PendingLoadImport: Codable, Identifiable {
    let id: UUID
    let receivedAt: Date
    var text: String?
    var imageFileName: String?
}

enum PendingLoadImportStore {
    static let appGroupID = "group.clarkdjcr.iTruckersCoDriver"
    private static let folderName = "PendingLoadImports"

    private static func containerURL() -> URL? {
        guard let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return nil
        }
        let folder = base.appendingPathComponent(folderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// Called by the Share Extension when the driver shares text and/or an image.
    static func enqueue(text: String?, imageData: Data?) {
        guard let folder = containerURL() else { return }
        let id = UUID()
        var imageFileName: String?

        if let imageData {
            let fileName = "\(id.uuidString).jpg"
            if (try? imageData.write(to: folder.appendingPathComponent(fileName))) != nil {
                imageFileName = fileName
            }
        }

        let pending = PendingLoadImport(id: id, receivedAt: Date(), text: text, imageFileName: imageFileName)
        guard let data = try? JSONEncoder().encode(pending) else { return }
        try? data.write(to: folder.appendingPathComponent("\(id.uuidString).json"))
    }

    /// Called by the app to fetch anything waiting to be reviewed, oldest first.
    static func pending() -> [PendingLoadImport] {
        guard let folder = containerURL(),
              let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else {
            return []
        }
        let decoder = JSONDecoder()
        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> PendingLoadImport? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(PendingLoadImport.self, from: data)
            }
            .sorted { $0.receivedAt < $1.receivedAt }
    }

    /// Loads the shared image bytes for a pending import, if it has one.
    static func imageData(for pending: PendingLoadImport) -> Data? {
        guard let fileName = pending.imageFileName, let folder = containerURL() else { return nil }
        return try? Data(contentsOf: folder.appendingPathComponent(fileName))
    }

    /// Deletes a pending import's files after it has been reviewed (saved or dismissed).
    static func remove(_ id: UUID) {
        guard let folder = containerURL() else { return }
        let fm = FileManager.default
        try? fm.removeItem(at: folder.appendingPathComponent("\(id.uuidString).json"))
        if let files = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) {
            for file in files where file.deletingPathExtension().lastPathComponent == id.uuidString {
                try? fm.removeItem(at: file)
            }
        }
    }
}
