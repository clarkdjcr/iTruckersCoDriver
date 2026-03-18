//
//  ContentView.swift
//  iTruckersCoDriver
//
//  Created by Donald Clark on 3/7/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        #if os(iOS)
        DriverView()
        #else
        DispatcherDashboardView()
        #endif
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
