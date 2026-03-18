//
//  RouteView.swift
//  iTruckersCoDriver
//
//  Created by Donald Clark on 3/7/26.
//

import SwiftUI
import MapKit

#if os(iOS)
struct RouteView: View {
    @StateObject private var routeManager = RouteManager()
    @State private var destinationText = ""
    @State private var showingSearch = false
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                // Map
                Map(position: $cameraPosition) {
                    UserAnnotation()
                    if let route = routeManager.activeRoute {
                        MapPolyline(route.polyline)
                            .stroke(.blue, lineWidth: 4)
                    }
                    if let dest = routeManager.destinationAnnotation {
                        Marker(dest.title ?? "Destination", coordinate: dest.coordinate)
                            .tint(.red)
                    }
                    ForEach(routeManager.nearbyPlaces) { place in
                        Annotation(place.name, coordinate: place.coordinate) {
                            Text(place.type.icon)
                                .font(.title2)
                                .shadow(radius: 2)
                        }
                    }
                }
                .ignoresSafeArea(edges: .top)

                // Bottom panel
                VStack(spacing: 0) {
                    // Weather bar
                    if let weather = routeManager.currentWeather {
                        weatherBar(weather)
                    }

                    // Navigation card
                    VStack(spacing: 12) {
                        // Search bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            TextField("Search destination...", text: $destinationText)
                                .submitLabel(.go)
                                .onSubmit {
                                    Task { await routeManager.requestRoute(to: destinationText) }
                                }
                            if !destinationText.isEmpty {
                                Button { destinationText = "" } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(10)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(10)

                        // Active route info
                        if let route = routeManager.activeRoute {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(formatDistance(route.distance))
                                        .font(.headline)
                                    Text(formatTime(route.expectedTravelTime))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button("Clear") {
                                    routeManager.activeRoute = nil
                                    routeManager.destinationAnnotation = nil
                                }
                                .foregroundColor(.red)
                            }
                        }

                        // Quick-find buttons
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach([PlaceType.fuel, .rest, .truckStop, .weighStation], id: \.rawValue) { type in
                                    Button {
                                        Task {
                                            _ = await routeManager.findNearby(type: type)
                                        }
                                    } label: {
                                        Text(type.icon + " " + type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                            .font(.caption)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color(uiColor: .secondarySystemBackground))
                                            .cornerRadius(16)
                                    }
                                    .foregroundColor(.primary)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                }
            }
            .navigationTitle("Route")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            routeManager.requestLocationPermission()
            Task { await routeManager.fetchWeather() }
        }
    }

    // MARK: - Weather bar

    private func weatherBar(_ weather: WeatherData) -> some View {
        HStack {
            if weather.isDangerous {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.yellow)
            }
            Text(weather.summary)
                .font(.caption)
                .foregroundColor(.white)
            Spacer()
            if weather.precipitationChance > 30 {
                Text("🌧️ \(Int(weather.precipitationChance))%")
                    .font(.caption)
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(weather.isDangerous ? Color.red : Color.blue.opacity(0.8))
    }

    // MARK: - Formatters

    private func formatDistance(_ meters: Double) -> String {
        let miles = meters / 1609.34
        if miles < 0.1 { return "Arrived" }
        return String(format: "%.1f mi", miles)
    }

    private func formatTime(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes) min"
    }
}
#endif
