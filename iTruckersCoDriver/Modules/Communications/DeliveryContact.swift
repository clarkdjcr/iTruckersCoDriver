//
//  DeliveryContact.swift
//  iTruckersCoDriver
//
//  SwiftData model for destination/customer contacts associated with loads.
//

import Foundation
import SwiftData

@Model
final class DeliveryContact {
    var id: UUID
    var contactName: String
    var company: String
    var phone: String
    var email: String
    var address: String
    var associatedLoadNumber: String
    var preferredContactMethod: String  // "phone", "email", "sms"
    var driverID: String
    var createdAt: Date

    init(
        contactName: String,
        company: String = "",
        phone: String = "",
        email: String = "",
        address: String = "",
        loadNumber: String = "",
        driverID: String,
        preferredContactMethod: String = "phone"
    ) {
        self.id = UUID()
        self.contactName = contactName
        self.company = company
        self.phone = phone
        self.email = email
        self.address = address
        self.associatedLoadNumber = loadNumber
        self.preferredContactMethod = preferredContactMethod
        self.driverID = driverID
        self.createdAt = Date()
    }
}
