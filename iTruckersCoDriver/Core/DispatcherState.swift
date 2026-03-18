//
//  DispatcherState.swift
//  iTruckersCoDriver
//
//  Created by Donald Clark on 3/7/26.
//

import Foundation
import Combine

class DispatcherState: ObservableObject {
    // Dispatcher-specific state — grows as dispatcher features are added
    @Published var selectedDriverId: String?
    @Published var isMonitoringFleet: Bool = false
}
