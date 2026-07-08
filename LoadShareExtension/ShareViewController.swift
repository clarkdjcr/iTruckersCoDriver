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
            PendingLoadImportStore.enqueue(text: hasText ? text : nil, imageData: imageData)
        }
        DispatchQueue.main.async { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }

    override func configurationItems() -> [Any]! {
        return []
    }

}
