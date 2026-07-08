//
//  RateConfirmationScannerSheet.swift
//  iTruckersCoDriver
//
//  Camera/photo → OCR → pre-filled LoadOpportunity confirmation.
//  Uses DocumentProcessor (Vision) for text extraction.
//

import SwiftUI
import SwiftData
import PhotosUI

#if os(iOS)
import UIKit

// MARK: - UIImagePickerController wrapper

private struct RateConImagePicker: UIViewControllerRepresentable {
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

// MARK: - Rate Confirmation Scanner Sheet

struct RateConfirmationScannerSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Called with the newly created LoadOpportunity right before the sheet dismisses.
    var onSave: (LoadOpportunity) -> Void

    // Source selection
    @State private var showCamera = false
    @State private var libraryItem: PhotosPickerItem?

    // Processing
    @State private var isProcessing = false
    @State private var processingError: String?

    // Parsed fields (editable)
    @State private var loadNumber: String
    @State private var brokerName: String
    @State private var origin: String
    @State private var destination: String
    @State private var pickupDate: Date
    @State private var deliveryDate: Date
    @State private var rate: String
    @State private var showConfirmation: Bool

    // Set when opened from a pending Share Extension import, so Save can clear it from the queue.
    private let importID: UUID?

    /// Camera/photo capture entry point — shows the source picker first.
    init(onSave: @escaping (LoadOpportunity) -> Void = { _ in }) {
        self.onSave = onSave
        self.importID = nil
        _loadNumber = State(initialValue: "")
        _brokerName = State(initialValue: "")
        _origin = State(initialValue: "")
        _destination = State(initialValue: "")
        _pickupDate = State(initialValue: Date())
        _deliveryDate = State(initialValue: Date())
        _rate = State(initialValue: "")
        _showConfirmation = State(initialValue: false)
    }

    /// Pre-filled entry point for a queued Share Extension import — skips straight to the confirmation form.
    init(prefilled: RateConfirmationData, importID: UUID? = nil, onSave: @escaping (LoadOpportunity) -> Void = { _ in }) {
        self.onSave = onSave
        self.importID = importID
        _loadNumber = State(initialValue: prefilled.loadNumber ?? "")
        _brokerName = State(initialValue: prefilled.brokerName ?? "")
        _origin = State(initialValue: prefilled.origin ?? "")
        _destination = State(initialValue: prefilled.destination ?? "")
        _pickupDate = State(initialValue: prefilled.pickupDate ?? Date())
        _deliveryDate = State(initialValue: prefilled.deliveryDate ?? Date())
        _rate = State(initialValue: prefilled.rate.map { String(format: "%.2f", $0) } ?? "")
        _showConfirmation = State(initialValue: true)
    }

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
            .navigationTitle(showConfirmation ? "Confirm Load" : "Scan Rate Con")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if showConfirmation {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { saveLoad() }
                            .disabled(destination.isEmpty && loadNumber.isEmpty)
                    }
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            RateConImagePicker(sourceType: .camera) { image in
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

            Text("Scan a rate confirmation to start a load plan.")
                .font(Theme.Typography.body())
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if isProcessing {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(Theme.primary)
                    Text("Reading rate confirmation…")
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
            Section("Extracted from rate con — edit as needed") {
                HStack {
                    Text("Load #")
                    Spacer()
                    TextField("Optional", text: $loadNumber)
                        .multilineTextAlignment(.trailing)
                }
                HStack {
                    Text("Broker")
                    Spacer()
                    TextField("Optional", text: $brokerName)
                        .multilineTextAlignment(.trailing)
                }
                HStack {
                    Text("Origin")
                    Spacer()
                    TextField("City, ST", text: $origin)
                        .multilineTextAlignment(.trailing)
                }
                HStack {
                    Text("Destination")
                    Spacer()
                    TextField("City, ST", text: $destination)
                        .multilineTextAlignment(.trailing)
                }
                DatePicker("Pickup", selection: $pickupDate)
                DatePicker("Delivery", selection: $deliveryDate)
                HStack {
                    Text("Rate ($)")
                    Spacer()
                    TextField("0.00", text: $rate)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            }
            .listRowBackground(Color.white.opacity(0.07))

            Section {
                Button("Scan Another Rate Con") {
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
                let parsed = DocumentProcessor.shared.parseRateConfirmation(from: ocr)

                await MainActor.run {
                    if let l = parsed.loadNumber { loadNumber = l }
                    if let b = parsed.brokerName { brokerName = b }
                    if let o = parsed.origin { origin = o }
                    if let d = parsed.destination { destination = d }
                    if let pu = parsed.pickupDate { pickupDate = pu }
                    if let del = parsed.deliveryDate { deliveryDate = del }
                    if let r = parsed.rate { rate = String(format: "%.2f", r) }
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

    // MARK: - Save

    private func saveLoad() {
        let opportunity = LoadOpportunity()
        opportunity.loadNumber = loadNumber
        opportunity.brokerName = brokerName
        opportunity.origin = origin
        opportunity.destination = destination
        opportunity.pickupDate = pickupDate
        opportunity.deliveryDate = deliveryDate
        opportunity.linehaulRate = Double(rate) ?? 0
        opportunity.appointmentTime = pickupDate
        opportunity.arrivalTime = pickupDate
        opportunity.dockStartTime = pickupDate
        opportunity.departureTime = pickupDate

        modelContext.insert(opportunity)
        try? modelContext.save()
        if let importID {
            PendingLoadImportStore.remove(importID)
        }
        onSave(opportunity)
        dismiss()
    }

    private func resetForNewScan() {
        loadNumber = ""
        brokerName = ""
        origin = ""
        destination = ""
        pickupDate = Date()
        deliveryDate = Date()
        rate = ""
        processingError = nil
        showConfirmation = false
        libraryItem = nil
    }
}
#endif
