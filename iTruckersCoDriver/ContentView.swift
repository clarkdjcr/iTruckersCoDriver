//
//  ContentView.swift
//  iTruckersCoDriver
//
//  Created by Donald Clark on 3/7/26.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        #if os(macOS)
        DispatcherDashboardView()
        #else
        switch appState.role {
        case .driver:
            DriverView()
        case .dispatcher:
            if UIDevice.current.userInterfaceIdiom == .pad {
                DispatcherDashboardView()
            } else {
                DispatcherSummaryView()
            }
        }
        #endif
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
