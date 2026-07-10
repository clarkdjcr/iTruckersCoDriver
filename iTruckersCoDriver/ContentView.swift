//
//  ContentView.swift
//  iTruckersCoDriver
//
//  Created by Donald Clark on 3/7/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        DriverView()
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
