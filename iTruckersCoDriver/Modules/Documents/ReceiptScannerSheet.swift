//
//  ReceiptScannerSheet.swift
//  iTruckersCoDriver
//
//  Camera/photo → OCR → pre-filled FuelRecord confirmation.
//  Uses DocumentProcessor (Vision) for text extraction.
//

import SwiftUI
import SwiftData
import PhotosUI

#if os(iOS)
import UIKit

// MARK: - UIImagePickerController wrapper

private struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    var onPick: (UIImage) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(sourceType)
            ? sourceType : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onPick: (UIImage) -> Void
        init(onPick: @escaping (UIImage) -> Void) { self.onPick = onPick }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { onPick(image) }
            picker.dismiss(animated: true)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Receipt Scanner Sheet

struct ReceiptScannerSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Source selection
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var libraryItem: PhotosPickerItem?

    // Processing
    @State private var isProcessing = false
    @State private var processingError: String?

    // Parsed fields (editable)
    @State private var gallons = ""
    @State private var totalPrice = ""
    @State private var pricePerGallon = ""
    @State private var stateCode = ""
    @State private var stationName = ""
    @State private var showConfirmation = false

    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()

                if showConfirmation {
                    confirmationForm
                } else {
                    sourcePickerView
                }
            }
            .navigationTitle(showConfirmation ? "Confirm Fuel Record" : "Scan Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if showConfirmation {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { saveRecord() }
                            .disabled(gallons.isEmpty)
                    }
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            ImagePicker(sourceType: .camera) { image in
                showCamera = false
                processImage(image)
            }
        }
        .onChange(of: libraryItem) {
            if let item = libraryItem {
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        processImage(image)
                    }
                }
            }
        }
    }

    // MARK: - Source picker

    private var sourcePickerView: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "doc.viewfinder.fill")
                .font(.system(size: 72))
                .foregroundStyle(Theme.primaryGradient)

            Text("Scan a fuel receipt to auto-fill your fuel log.")
                .font(Theme.Typography.body())
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if isProcessing {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(Theme.primary)
                    Text("Reading receipt…")
                        .font(Theme.Typography.caption())
                        .foregroundColor(Theme.textSecondary)
                }
            } else {
                VStack(spacing: 16) {
                    Button {
                        showCamera = true
                    } label: {
                        Label("Take Photo", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.primaryGradient)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                    }

                    PhotosPicker(selection: $libraryItem, matching: .images) {
                        Label("Choose from Library", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .foregroundColor(Theme.primary)
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Theme.primary.opacity(0.4), lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, 32)
            }

            if let error = processingError {
                Text(error)
                    .font(Theme.Typography.caption())
                    .foregroundColor(Theme.accent)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
    }

    // MARK: - Confirmation form

    private var confirmationForm: some View {
        Form {
            Section("Extracted from receipt — edit as needed") {
                HStack {
                    Text("Gallons")
                    Spacer()
                    TextField("0.0", text: $gallons)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                HStack {
                    Text("Total ($)")
                    Spacer()
                    TextField("0.00", text: $totalPrice)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: totalPrice) { recalcPPG() }
                        .onChange(of: gallons) { recalcPPG() }
                }
                HStack {
                    Text("Price/Gallon")
                    Spacer()
                    TextField("0.000", text: $pricePerGallon)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            }
            .listRowBackground(Color.white.opacity(0.07))

            Section("Details") {
                HStack {
                    Text("State")
                    Spacer()
                    TextField("TX", text: $stateCode)
                        .textInputAutocapitalization(.characters)
                        .multilineTextAlignment(.trailing)
                }
                HStack {
                    Text("Station")
                    Spacer()
                    TextField("Optional", text: $stationName)
                        .multilineTextAlignment(.trailing)
                }
            }
            .listRowBackground(Color.white.opacity(0.07))

            Section {
                Button("Scan Another Receipt") {
                    resetForNewScan()
                }
                .foregroundColor(Theme.primary)
            }
            .listRowBackground(Color.white.opacity(0.07))
        }
        .scrollContentBackground(.hidden)
    }

    // MARK: - Processing

    private func processImage(_ image: UIImage) {
        guard let cgImage = image.cgImage else {
            processingError = "Couldn't read the image."
            return
        }
        isProcessing = true
        processingError = nil

        Task {
            do {
                let ocr = try await DocumentProcessor.shared.extractText(from: cgImage)
                let parsed = DocumentProcessor.shared.parseReceipt(from: ocr)

                await MainActor.run {
                    if let g = parsed.gallons { gallons = String(format: "%.3f", g) }
                    if let p = parsed.totalPrice { totalPrice = String(format: "%.2f", p) }
                    if let s = parsed.state { stateCode = s }
                    recalcPPG()
                    isProcessing = false
                    showConfirmation = true
                }
            } catch {
                await MainActor.run {
                    processingError = "OCR failed: \(error.localizedDescription)"
                    isProcessing = false
                    showConfirmation = true  // still let the user fill in manually
                }
            }
        }
    }

    private func recalcPPG() {
        guard let g = Double(gallons), g > 0,
              let t = Double(totalPrice), t > 0 else { return }
        pricePerGallon = String(format: "%.3f", t / g)
    }

    // MARK: - Save

    private func saveRecord() {
        let g = Double(gallons) ?? 0
        let ppg = Double(pricePerGallon) ?? 0

        let record = FuelRecord(
            driverID: appState.driverID,
            gallons: g,
            pricePerGallon: ppg,
            stateCode: stateCode.uppercased(),
            stationName: stationName
        )
        modelContext.insert(record)
        try? modelContext.save()
        dismiss()
    }

    private func resetForNewScan() {
        gallons = ""
        totalPrice = ""
        pricePerGallon = ""
        stateCode = ""
        stationName = ""
        processingError = nil
        showConfirmation = false
        libraryItem = nil
    }
}
#endif
