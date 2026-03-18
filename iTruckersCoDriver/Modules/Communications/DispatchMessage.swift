//
//  DispatchMessage.swift
//  iTruckersCoDriver
//
//  Created by Donald Clark on 3/7/26.
//
//  SwiftData model for dispatch messages, synced via CloudKit.
//

import Foundation
import SwiftData

@Model
final class DispatchMessage {
    var id: UUID
    var timestamp: Date
    var sender: String      // "driver" or "dispatch"
    var content: String
    var isRead: Bool
    var deliveryAddress: String
    var loadNumber: String
    var attachmentURL: String
    var driverID: String    // identifies which driver this thread belongs to

    init(
        sender: String,
        content: String,
        driverID: String = "",
        deliveryAddress: String = "",
        loadNumber: String = "",
        attachmentURL: String = ""
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.sender = sender
        self.content = content
        self.isRead = sender == "driver"
        self.driverID = driverID
        self.deliveryAddress = deliveryAddress
        self.loadNumber = loadNumber
        self.attachmentURL = attachmentURL
    }

    var isFromDriver: Bool { sender == "driver" }
    var hasDeliveryInfo: Bool { !deliveryAddress.isEmpty || !loadNumber.isEmpty }
}
