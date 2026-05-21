//
//  RouteManager.swift
//  iTruckersCoDriver
//
//  Created by Donald Clark on 3/7/26.
//

import Foundation
import Combine
import CoreLocation
import MapKit

#if canImport(WeatherKit)
import WeatherKit
#endif

// MARK: - Place result

struct PlaceResult: Identifiable {
    let id = UUID()
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D
    let distanceMiles: Double
    let type: PlaceType
}

enum PlaceType: String {
    case fuel = "fuel"
    case rest = "rest"
    case truckStop = "truck_stop"
    case weighStation = "weigh_station"

    var searchQuery: String {
        switch self {
        case .fuel: return "truck fuel diesel"
        case .rest: return "rest area truck"
        case .truckStop: return "truck stop"
        case .weighStation: return "weigh station"
        }
    }

    var icon: String {
        switch self {
        case .fuel: return "⛽"
        case .rest: return "🛏️"
        case .truckStop: return "🚛"
        case .weighStation: return "⚖️"
        }
    }
}

// MARK: - Weather data

struct WeatherData {
    let temperature: Double
    let feelsLike: Double
    let condition: String
    let windSpeedMPH: Double
    let visibility: Double
    let precipitationChance: Double
    let isDangerous: Bool

    var summary: String {
        "\(Int(temperature))°F, \(condition), wind \(Int(windSpeedMPH))mph"
    }
}

// MARK: - Route manager

class RouteManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentLocation: CLLocation?
    @Published var currentWeather: WeatherData?
    @Published var activeRoute: MKRoute?
    @Published var nearbyPlaces: [PlaceResult] = []
    @Published var isLocating = false
    @Published var destinationAnnotation: MKPointAnnotation?

    private let locationManager = CLLocationManager()

    #if canImport(WeatherKit)
    private let weatherService = WeatherService.shared
    #endif

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 100  // update every 100m
    }

    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        isLocating = true
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async {
            self.currentLocation = location
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    // MARK: - Route planning

    func requestRoute(to destination: String) async {
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = destination
        
        let search = MKLocalSearch(request: searchRequest)
        guard let response = try? await search.start(),
              let destinationItem = response.mapItems.first else { return }

        let coordinate = destinationItem.location.coordinate

        let request = MKDirections.Request()
        request.source = MKMapItem.forCurrentLocation()
        request.destination = destinationItem
        request.transportType = .automobile

        guard let directions = try? await MKDirections(request: request).calculate(),
              let route = directions.routes.first else { return }

        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = destination

        DispatchQueue.main.async {
            self.activeRoute = route
            self.destinationAnnotation = annotation
        }
    }

    // MARK: - Nearby places search

    func findNearby(type: PlaceType, radiusMiles: Double = 25) async -> [PlaceResult] {
        let center = currentLocation?.coordinate ?? CLLocationCoordinate2D(latitude: 39.8283, longitude: -98.5795)
        let radiusMeters = radiusMiles * 1609.34

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = type.searchQuery
        request.region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: radiusMeters * 2,
            longitudinalMeters: radiusMeters * 2
        )

        guard let response = try? await MKLocalSearch(request: request).start() else { return [] }

        let results = response.mapItems.prefix(5).map { item -> PlaceResult in
            let distance: Double
            if let currentLoc = currentLocation {
                distance = item.location.distance(from: currentLoc)
            } else {
                distance = 0
            }

            return PlaceResult(
                name: item.name ?? "Unknown",
                address: item.address.map { String(describing: $0) } ?? "",
                coordinate: item.location.coordinate,
                distanceMiles: distance / 1609.34,
                type: type
            )
        }

        DispatchQueue.main.async {
            self.nearbyPlaces = Array(results)
        }
        return Array(results)
    }

    // MARK: - Weather

    func fetchWeather() async -> WeatherData? {
        guard let location = currentLocation else { return mockWeather() }

        #if canImport(WeatherKit)
        do {
            let weather = try await weatherService.weather(for: location)
            let current = weather.currentWeather
            let hourly = weather.hourlyForecast.first

            let data = WeatherData(
                temperature: current.temperature.converted(to: .fahrenheit).value,
                feelsLike: current.apparentTemperature.converted(to: .fahrenheit).value,
                condition: current.condition.description,
                windSpeedMPH: current.wind.speed.converted(to: .milesPerHour).value,
                visibility: current.visibility.converted(to: .miles).value,
                precipitationChance: (hourly?.precipitationChance ?? 0) * 100,
                isDangerous: isDangerousWeather(current)
            )
            DispatchQueue.main.async { self.currentWeather = data }
            return data
        } catch {
            return mockWeather()
        }
        #else
        return mockWeather()
        #endif
    }

    #if canImport(WeatherKit)
    private func isDangerousWeather(_ current: CurrentWeather) -> Bool {
        let windMPH = current.wind.speed.converted(to: .milesPerHour).value
        let visibility = current.visibility.converted(to: .miles).value
        // High-profile vehicles are sensitive to crosswinds
        // 25mph: Warning, 40mph: Dangerous
        return windMPH > 40 || (windMPH > 25 && visibility < 0.5) || visibility < 0.25
    }
    #endif

    private func mockWeather() -> WeatherData {
        WeatherData(
            temperature: 62,
            feelsLike: 58,
            condition: "Partly Cloudy",
            windSpeedMPH: 12,
            visibility: 10,
            precipitationChance: 20,
            isDangerous: false
        )
    }

    // MARK: - Human-readable summaries for Claude tools

    func nearbyPlacesSummary(_ places: [PlaceResult]) -> String {
        guard !places.isEmpty else { return "No places found nearby." }
        return places.enumerated().map { i, place in
            "\(i + 1). \(place.name) — \(String(format: "%.1f", place.distanceMiles)) miles away. \(place.address)"
        }.joined(separator: "\n")
    }
}
