//
//  CommunicationLog.swift
//  iTruckersCoDriver
//
//  SwiftData model recording driver ↔ customer communication events.
//  Synced via CloudKit so dispatchers see the full thread.
//

import Foundation
import SwiftData

@Model
final class CommunicationLog {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var driverID: String = ""
    var contactName: String = ""
    var loadNumber: String = ""
    var direction: String = "outbound"
    var channel: String = "phone"
    var content: String = ""
    var confirmed: Bool = false

    init(
        driverID: String,
        contactName: String,
        loadNumber: String = "",
        direction: String,
        channel: String,
        content: String,
        confirmed: Bool = false
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.driverID = driverID
        self.contactName = contactName
        self.loadNumber = loadNumber
        self.direction = direction
        self.channel = channel
        self.content = content
        self.confirmed = confirmed
    }

    var isOutbound: Bool { direction == "outbound" }
}
