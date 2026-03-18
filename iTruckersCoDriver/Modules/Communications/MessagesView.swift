//
//  MessagesView.swift
//  iTruckersCoDriver
//
//  Created by Donald Clark on 3/7/26.
//

import SwiftUI
import SwiftData
import MapKit

#if os(iOS)
struct MessagesView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var driverState: DriverState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DispatchMessage.timestamp, order: .forward) private var allMessages: [DispatchMessage]
    @Query(sort: \CommunicationLog.timestamp, order: .reverse) private var allCommLogs: [CommunicationLog]
    @Query(sort: \DeliveryContact.createdAt, order: .reverse) private var allContacts: [DeliveryContact]

    private var messages: [DispatchMessage] {
        allMessages.filter { $0.driverID == appState.driverID }
    }
    private var myCommLogs: [CommunicationLog] {
        allCommLogs.filter { $0.driverID == appState.driverID }
    }
    private var myContacts: [DeliveryContact] {
        allContacts.filter { $0.driverID == appState.driverID }
    }

    @State private var newMessageText = ""
    @State private var selectedTab = 0
    @State private var showAddContact = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("Section", selection: $selectedTab) {
                    Text("Dispatch").tag(0)
                    Text("Contacts").tag(1)
                    Text("Comm Log").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal).padding(.top, 8)

                switch selectedTab {
                case 0: dispatchTab
                case 1: contactsTab
                default: commLogTab
                }
            }
            .navigationTitle("Dispatch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Sample Message", systemImage: "plus") { addSampleDispatchMessage() }
                        Button("Add Contact", systemImage: "person.badge.plus") { showAddContact = true }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
            .sheet(isPresented: $showAddContact) { AddDeliveryContactView() }
        }
        .onAppear { updateUnreadCount() }
    }

    // MARK: - Dispatch Tab

    private var dispatchTab: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if messages.isEmpty { emptyDispatchView }
                        ForEach(messages) { message in
                            messageBubble(message)
                                .id(message.id)
                                .onAppear {
                                    if !message.isRead && !message.isFromDriver {
                                        message.isRead = true
                                        try? modelContext.save()
                                        updateUnreadCount()
                                    }
                                }
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) {
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            Divider()
            HStack(spacing: 10) {
                TextField("Message dispatch...", text: $newMessageText, axis: .vertical)
                    .lineLimit(1...4).padding(10)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(20).focused($isInputFocused)
                Button { sendMessage() } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(newMessageText.isEmpty ? .gray : .blue)
                }
                .disabled(newMessageText.isEmpty)
            }
            .padding()
        }
    }

    // MARK: - Contacts Tab

    private var contactsTab: some View {
        Group {
            if myContacts.isEmpty {
                ContentUnavailableView(
                    "No Contacts",
                    systemImage: "person.2",
                    description: Text("Add delivery contacts for quick ETA updates and communication logs.")
                )
            } else {
                List(myContacts) { contact in
                    contactRow(contact)
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    private func contactRow(_ contact: DeliveryContact) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading) {
                    Text(contact.contactName).fontWeight(.semibold)
                    if !contact.company.isEmpty {
                        Text(contact.company).font(.caption).foregroundColor(.secondary)
                    }
                }
                Spacer()
                if !contact.associatedLoadNumber.isEmpty {
                    Text(contact.associatedLoadNumber)
                        .font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.blue.opacity(0.15)).cornerRadius(4)
                }
            }
            HStack(spacing: 16) {
                if !contact.phone.isEmpty {
                    Link(destination: URL(string: "tel:\(contact.phone.filter { $0.isNumber })")!) {
                        Label(contact.phone, systemImage: "phone.fill").font(.caption)
                    }
                }
                if !contact.email.isEmpty {
                    Link(destination: URL(string: "mailto:\(contact.email)")!) {
                        Label(contact.email, systemImage: "envelope.fill").font(.caption)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Communication Log Tab

    private var commLogTab: some View {
        Group {
            if myCommLogs.isEmpty {
                ContentUnavailableView(
                    "No Communications Logged",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Customer communications will appear here when logged via voice or manually.")
                )
            } else {
                List(myCommLogs) { log in
                    commLogRow(log)
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    private func commLogRow(_ log: CommunicationLog) -> some View {
        HStack(spacing: 12) {
            Image(systemName: log.isOutbound ? "arrow.up.right" : "arrow.down.left")
                .foregroundColor(log.isOutbound ? .blue : .green)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(log.contactName).fontWeight(.medium)
                    if !log.loadNumber.isEmpty {
                        Text("· \(log.loadNumber)").font(.caption).foregroundColor(.secondary)
                    }
                }
                Text(log.content).font(.caption).foregroundColor(.secondary).lineLimit(2)
                Text(log.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2).foregroundColor(.secondary)
            }
            Spacer()
            if log.confirmed {
                Image(systemName: "checkmark.circle.fill").foregroundColor(.green).font(.caption)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Message bubble

    private func messageBubble(_ message: DispatchMessage) -> some View {
        HStack {
            if message.isFromDriver { Spacer(minLength: 40) }
            VStack(alignment: message.isFromDriver ? .trailing : .leading, spacing: 4) {
                if !message.isFromDriver {
                    Text("Dispatch").font(.caption2).foregroundColor(.secondary)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(message.content).font(.body)
                    if message.hasDeliveryInfo { deliveryInfoCard(message) }
                    Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundColor(message.isFromDriver ? .white.opacity(0.7) : .secondary)
                }
                .padding(12)
                .background(message.isFromDriver ? Color.blue : Color(uiColor: .secondarySystemBackground))
                .foregroundColor(message.isFromDriver ? .white : .primary)
                .cornerRadius(16)
            }
            if !message.isFromDriver { Spacer(minLength: 40) }
        }
    }

    private func deliveryInfoCard(_ message: DispatchMessage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if !message.loadNumber.isEmpty {
                Label(message.loadNumber, systemImage: "doc.text.fill").font(.caption)
            }
            if !message.deliveryAddress.isEmpty {
                Button {
                    let encoded = message.deliveryAddress.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    if let url = URL(string: "maps://?daddr=\(encoded)") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label(message.deliveryAddress, systemImage: "map.fill").font(.caption)
                }
            }
        }
        .padding(8).background(Color.white.opacity(0.2)).cornerRadius(8)
    }

    private var emptyDispatchView: some View {
        VStack(spacing: 12) {
            Image(systemName: "message.fill").font(.system(size: 48)).foregroundColor(.gray)
            Text("No messages yet").font(.headline).foregroundColor(.secondary)
            Text("Messages from dispatch will appear here.")
                .font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.top, 80)
    }

    // MARK: - Actions

    private func sendMessage() {
        guard !newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let message = DispatchMessage(sender: "driver", content: newMessageText, driverID: appState.driverID)
        modelContext.insert(message)
        try? modelContext.save()
        newMessageText = ""
        isInputFocused = false
    }

    private func updateUnreadCount() {
        driverState.unreadMessageCount = messages.filter { !$0.isRead && !$0.isFromDriver }.count
    }

    private func addSampleDispatchMessage() {
        let samples = [
            DispatchMessage(
                sender: "dispatch", content: "New load available. Pickup at distribution center, delivery to Phoenix AZ.",
                driverID: appState.driverID, deliveryAddress: "4747 S 40th St, Phoenix, AZ 85040",
                loadNumber: "Load #TX-48821"
            ),
            DispatchMessage(
                sender: "dispatch", content: "Receiver confirmed delivery window: 0600-1000 tomorrow. ETA still good?",
                driverID: appState.driverID
            ),
            DispatchMessage(
                sender: "dispatch", content: "Heads up: I-40 westbound has construction delays near Amarillo. Consider I-20 alternate.",
                driverID: appState.driverID
            )
        ]
        let sample = samples.randomElement()!
        modelContext.insert(sample)
        try? modelContext.save()
        updateUnreadCount()
    }
}

// MARK: - Add Delivery Contact Sheet

struct AddDeliveryContactView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var company = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var address = ""
    @State private var loadNumber = ""
    @State private var preferredMethod = "phone"

    var body: some View {
        NavigationView {
            Form {
                Section("Contact Info") {
                    TextField("Name", text: $name)
                    TextField("Company", text: $company)
                    TextField("Phone", text: $phone).keyboardType(.phonePad)
                    TextField("Email", text: $email).keyboardType(.emailAddress).autocorrectionDisabled()
                }
                Section("Load") {
                    TextField("Load Number", text: $loadNumber)
                    TextField("Delivery Address", text: $address)
                }
                Section("Preferred Contact Method") {
                    Picker("Method", selection: $preferredMethod) {
                        Text("Phone").tag("phone")
                        Text("SMS").tag("sms")
                        Text("Email").tag("email")
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Add Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let contact = DeliveryContact(
                            contactName: name, company: company, phone: phone,
                            email: email, address: address, loadNumber: loadNumber,
                            driverID: appState.driverID, preferredContactMethod: preferredMethod
                        )
                        modelContext.insert(contact)
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
#endif
