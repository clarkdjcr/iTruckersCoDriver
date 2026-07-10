//
//  ShareViewController.swift
//  LoadShareExtension
//
//  Created by Donald Clark on 7/7/26.
//

import UIKit
import Social
import UniformTypeIdentifiers

class ShareViewController: SLComposeServiceViewController {

    override func isContentValid() -> Bool {
        return true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        placeholder = "Notes about this load (optional)"
    }

    override func didSelectPost() {
        let text = contentText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        let imageProvider = items
            .compactMap { $0.attachments }
            .flatMap { $0 }
            .first { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }

        guard let imageProvider else {
            finish(text: text, imageData: nil)
            return
        }

        imageProvider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] data, _ in
            self?.finish(text: text, imageData: data)
        }
    }

    private func finish(text: String?, imageData: Data?) {
        let hasText = !(text?.isEmpty ?? true)
        if hasText || imageData != nil {
            enqueuePendingLoad(text: hasText ? text : nil, imageData: imageData)
        }
        DispatchQueue.main.async { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }

    private struct PendingLoadPayload: Codable {
        let id: UUID
        let receivedAt: Date
        let text: String?
        let imageFileName: String?
    }

    private func enqueuePendingLoad(text: String?, imageData: Data?) {
        let appGroupID = "group.clarkdjcr.iTruckersCoDriver"
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else { return }

        let folder = container.appendingPathComponent("PendingLoadImports", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let id = UUID()
        var imageFileName: String?
        if let imageData {
            let fileName = "\(id.uuidString).jpg"
            if (try? imageData.write(to: folder.appendingPathComponent(fileName))) != nil {
                imageFileName = fileName
            }
        }

        let payload = PendingLoadPayload(
            id: id,
            receivedAt: Date(),
            text: text,
            imageFileName: imageFileName
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: folder.appendingPathComponent("\(id.uuidString).json"))
    }

    override func configurationItems() -> [Any]! {
        return []
    }

}
