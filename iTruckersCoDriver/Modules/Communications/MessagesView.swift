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
            ZStack {
                Theme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Picker("Section", selection: $selectedTab) {
                        Text("Dispatch").tag(0)
                        Text("Contacts").tag(1)
                        Text("Log").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding()

                    switch selectedTab {
                    case 0: dispatchTab
                    case 1: contactsTab
                    default: commLogTab
                    }
                }
            }
            .navigationTitle("Communications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Sample Message", systemImage: "plus") { addSampleDispatchMessage() }
                        Button("Add Contact", systemImage: "person.badge.plus") { showAddContact = true }
                    } label: { 
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(Theme.primary)
                    }
                }
            }
            .sheet(isPresented: $showAddContact) { AddDeliveryContactView() }
        }
        .colorScheme(.dark)
        .onAppear { updateUnreadCount() }
    }

    // MARK: - Dispatch Tab

    private var dispatchTab: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
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
                        withAnimation(.spring()) { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            
            // Premium input area
            VStack(spacing: 0) {
                Divider().background(Color.white.opacity(0.1))
                HStack(spacing: 12) {
                    TextField("Message dispatch...", text: $newMessageText, axis: .vertical)
                        .font(Theme.Typography.body(14))
                        .padding(12)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(20)
                        .focused($isInputFocused)
                    
                    Button { sendMessage() } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(newMessageText.isEmpty ? .gray : .white)
                            .frame(width: 44, height: 44)
                            .background(newMessageText.isEmpty ? AnyShapeStyle(Color.white.opacity(0.1)) : AnyShapeStyle(Theme.primaryGradient))
                            .clipShape(Circle())
                    }
                    .disabled(newMessageText.isEmpty)
                }
                .padding()
                .background(.ultraThinMaterial)
            }
        }
    }

    // MARK: - Contacts Tab

    private var contactsTab: some View {
        Group {
            if myContacts.isEmpty {
                emptyStateView(title: "No Contacts", subtitle: "Add delivery contacts for quick ETA updates.", icon: "person.2.fill")
            } else {
                List(myContacts) { contact in
                    contactRow(contact)
                        .listRowBackground(Color.white.opacity(0.05))
                        .listRowSeparatorTint(Color.white.opacity(0.1))
                }
                .listStyle(.plain)
            }
        }
    }

    private func contactRow(_ contact: DeliveryContact) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Theme.primary.opacity(0.1))
                    .frame(width: 44, height: 44)
                Text(String(contact.contactName.prefix(1)).uppercased())
                    .font(Theme.Typography.body(18))
                    .fontWeight(.bold)
                    .foregroundColor(Theme.primary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(contact.contactName).font(Theme.Typography.body()).fontWeight(.bold)
                    if !contact.associatedLoadNumber.isEmpty {
                        Text(contact.associatedLoadNumber)
                            .font(Theme.Typography.caption(10))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Theme.primary.opacity(0.2)).cornerRadius(6)
                    }
                }
                if !contact.company.isEmpty {
                    Text(contact.company).font(Theme.Typography.caption()).foregroundColor(Theme.textSecondary)
                }
                
                HStack(spacing: 16) {
                    if !contact.phone.isEmpty {
                        Link(destination: URL(string: "tel:\(contact.phone.filter { $0.isNumber })")!) {
                            Label(contact.phone, systemImage: "phone.fill").font(Theme.Typography.caption())
                        }
                    }
                }
                .foregroundColor(Theme.primary)
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }

    // MARK: - Communication Log Tab

    private var commLogTab: some View {
        Group {
            if myCommLogs.isEmpty {
                emptyStateView(title: "No Logs", subtitle: "Customer communications will appear here.", icon: "bubble.left.and.bubble.right.fill")
            } else {
                List(myCommLogs) { log in
                    commLogRow(log)
                        .listRowBackground(Color.white.opacity(0.05))
                        .listRowSeparatorTint(Color.white.opacity(0.1))
                }
                .listStyle(.plain)
            }
        }
    }

    private func commLogRow(_ log: CommunicationLog) -> some View {
        HStack(spacing: 12) {
            Image(systemName: log.isOutbound ? "arrow.up.right" : "arrow.down.left")
                .foregroundColor(log.isOutbound ? Theme.primary : Theme.success)
                .font(.system(size: 14, weight: .bold))
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(log.contactName).font(Theme.Typography.body(14)).fontWeight(.bold)
                    if !log.loadNumber.isEmpty {
                        Text("· \(log.loadNumber)").font(Theme.Typography.caption()).foregroundColor(Theme.textSecondary)
                    }
                }
                Text(log.content).font(Theme.Typography.caption()).foregroundColor(Theme.textSecondary).lineLimit(2)
                Text(log.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(Theme.Typography.caption(10)).foregroundColor(Theme.textSecondary)
            }
            Spacer()
            if log.confirmed {
                Image(systemName: "checkmark.circle.fill").foregroundColor(Theme.success).font(.caption)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Message bubble

    private func messageBubble(_ message: DispatchMessage) -> some View {
        HStack {
            if message.isFromDriver { Spacer(minLength: 60) }
            
            VStack(alignment: message.isFromDriver ? .trailing : .leading, spacing: 4) {
                if !message.isFromDriver {
                    Text("DISPATCH").font(Theme.Typography.caption(10)).kerning(1.0).foregroundColor(Theme.textSecondary)
                        .padding(.leading, 4)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(message.content).font(Theme.Typography.body())
                    
                    if message.hasDeliveryInfo { deliveryInfoCard(message) }
                    
                    Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(Theme.Typography.caption(10))
                        .foregroundColor(message.isFromDriver ? .white.opacity(0.6) : Theme.textSecondary)
                }
                .padding(14)
                .background(message.isFromDriver ? Theme.primary : Color.white.opacity(0.1))
                .foregroundColor(.white)
                .cornerRadius(18, corners: message.isFromDriver ? [.topLeft, .topRight, .bottomLeft] : [.topLeft, .topRight, .bottomRight])
            }
            
            if !message.isFromDriver { Spacer(minLength: 60) }
        }
    }

    private func deliveryInfoCard(_ message: DispatchMessage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !message.loadNumber.isEmpty {
                HStack {
                    Image(systemName: "shippingbox.fill")
                    Text(message.loadNumber)
                }
                .font(Theme.Typography.caption())
                .fontWeight(.bold)
            }
            
            if !message.deliveryAddress.isEmpty {
                Button {
                    let encoded = message.deliveryAddress.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    if let url = URL(string: "maps://?daddr=\(encoded)") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack {
                        Image(systemName: "map.fill")
                        Text(message.deliveryAddress)
                            .underline()
                    }
                    .font(Theme.Typography.caption())
                    .foregroundColor(.white)
                }
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.2))
        .cornerRadius(12)
    }

    private var emptyDispatchView: some View {
        emptyStateView(title: "No Messages", subtitle: "Communication with dispatch will appear here.", icon: "tray.fill")
    }
    
    private func emptyStateView(title: String, subtitle: String, icon: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(Color.white.opacity(0.1))
            Text(title)
                .font(Theme.Typography.title(20))
            Text(subtitle)
                .font(Theme.Typography.body())
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
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
