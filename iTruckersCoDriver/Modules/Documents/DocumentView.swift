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
    @State private var showReceiptScanner = false

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
            ZStack {
                Theme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Category filter chips
                    categoryFilter
                        .padding(.vertical, 12)

                    List {
                        ForEach(filteredDocs) { doc in
                            documentRow(doc)
                                .listRowBackground(Color.white.opacity(0.05))
                                .listRowSeparatorTint(Color.white.opacity(0.1))
                        }
                    }
                    .listStyle(.plain)
                    .searchable(text: $searchText, prompt: "Search documents")
                }
            }
            .navigationTitle("Documents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showReceiptScanner = true } label: {
                        Image(systemName: "doc.viewfinder.fill")
                            .foregroundColor(Theme.primary)
                    }
                }
            }
            .sheet(isPresented: $showReceiptScanner) {
                ReceiptScannerSheet()
            }
        }
        .colorScheme(.dark)
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
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
    }

    private func documentRow(_ doc: DriverDocument) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Theme.primary.opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: doc.category.icon)
                    .foregroundColor(Theme.primary)
                    .font(.system(size: 16, weight: .bold))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(doc.name)
                    .font(Theme.Typography.body())
                    .fontWeight(.bold)
                Text(doc.category.rawValue)
                    .font(Theme.Typography.caption())
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
            
            ShareLink(item: doc.name) {
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding(.vertical, 8)
    }

    private func filterChip(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(Theme.Typography.caption())
                .fontWeight(isSelected ? .bold : .medium)
                .foregroundColor(isSelected ? .white : Theme.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Theme.primary : Color.white.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.clear : Color.white.opacity(0.1), lineWidth: 1)
                )
        }
    }
}
#endif
