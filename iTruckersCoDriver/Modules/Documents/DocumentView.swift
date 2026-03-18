//
//  DocumentView.swift
//  iTruckersCoDriver
//
//  iOS: Browse, search, and share driver documents (IFTA forms,
//  BOL templates, log sheets, permits).
//

import SwiftUI

#if os(iOS)
struct DocumentView: View {
    @StateObject private var repository = DocumentRepository()
    @State private var selectedCategory: DriverDocument.DocumentCategory? = nil
    @State private var searchText = ""

    private var filteredDocs: [DriverDocument] {
        var result = repository.documents
        if let cat = selectedCategory { result = result.filter { $0.category == cat } }
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return result
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Category filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterChip("All", isSelected: selectedCategory == nil) {
                            selectedCategory = nil
                        }
                        ForEach(DriverDocument.DocumentCategory.allCases, id: \.self) { cat in
                            filterChip(cat.rawValue, isSelected: selectedCategory == cat) {
                                selectedCategory = selectedCategory == cat ? nil : cat
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)

                List(filteredDocs) { doc in
                    documentRow(doc)
                }
                .listStyle(.insetGrouped)
                .searchable(text: $searchText, prompt: "Search documents")
            }
            .navigationTitle("Documents")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func documentRow(_ doc: DriverDocument) -> some View {
        HStack {
            Image(systemName: doc.category.icon)
                .foregroundColor(.blue)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(doc.name).fontWeight(.medium)
                Text(doc.category.rawValue).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            // Share the document name as text (full PDF delivery via CloudKit future phase)
            ShareLink(item: doc.name) {
                Image(systemName: "square.and.arrow.up").foregroundColor(.blue)
            }
        }
        .padding(.vertical, 2)
    }

    private func filterChip(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.secondary.opacity(0.2))
                .cornerRadius(16)
        }
    }
}
#endif
