# iTrucker's Co-Driver — Claude Code Instructions

## Project Vision
AI-powered trucking companion app. Provides independent truckers with a voice-driven intelligent companion that acts like a personal assistant. Handles dispatch communications, determines best route (weather + traffic), presents schedule based on HOS compliance, automates compliance record keeping & tax documentation, works with eLogs and paper logs, safety monitoring through friendly intuitive interaction. Makes Them Laugh Occasionally! 😄🚛

## Platform Architecture
- **iOS (iPhone + iPad)** — Driver interface: voice-first, hands-free
- **macOS** — Dispatcher dashboard: fleet overview, messages, loads, maintenance
- Shared SwiftData + CloudKit sync between platforms

## File Structure (current as of 2026-03-17)

```
iTruckersCoDriver/
├── Core/
│   ├── AppState.swift           # ObservableObject: driverName, hosCycle, cdlState, healthMonitoringEnabled, driverID
│   ├── ClaudeService.swift      # Claude API via URLSession SSE streaming + tool use loop
│   ├── KeychainHelper.swift     # Keychain CRUD for API keys
│   ├── DriverState.swift        # ObservableObject: conversation, dutyStatus, HOS, speed, fuelLevel, estimatedRange
│   ├── DriverProfile.swift      # SwiftData+CloudKit: fleet-visible driver state (speed, fuel, fatigue)
│   ├── DispatcherState.swift    # ObservableObject for macOS dispatcher
│   ├── DriverAccount.swift      # SwiftData: per-driver account, onboarding state, API key ref
│   └── OnboardingManager.swift  # Validates API key, completes onboarding flow
├── Modules/
│   ├── HOS/
│   │   ├── HOSModels.swift      # SwiftData: HOSEntry, ExpenseEntry
│   │   ├── HOSManager.swift     # FMCSA HOS calculations (11hr, 14hr, 30min break, 70/8 cycle)
│   │   └── HOSView.swift        # HOS log + duty status buttons [iOS]
│   ├── Route/
│   │   ├── RouteManager.swift   # CLLocationManager + MapKit + WeatherKit
│   │   └── RouteView.swift      # Map view + route overlay [iOS]
│   ├── Communications/
│   │   ├── DispatchMessage.swift    # SwiftData+CloudKit: driver↔dispatch messages
│   │   ├── MessagesView.swift       # 3-tab: Dispatch / Contacts / Comm Log [iOS]
│   │   ├── DeliveryContact.swift    # SwiftData: customer/consignee contacts per load
│   │   └── CommunicationLog.swift   # SwiftData: driver↔customer comms history
│   ├── Compliance/
│   │   ├── TripRecord.swift     # SwiftData: trips, IFTA mileage, revenue
│   │   └── ComplianceView.swift # Trips / IFTA / Expenses + link to DocumentView [iOS]
│   ├── Fleet/
│   │   ├── VehicleMetrics.swift # SwiftData: GPS, speed, fuel snapshots (60s interval)
│   │   ├── FuelRecord.swift     # SwiftData: fuel fill-ups for IFTA + rolling MPG
│   │   └── TelemetryManager.swift # iOS: polls location, writes VehicleMetrics, updates DriverState
│   ├── Maintenance/
│   │   ├── MaintenanceItem.swift    # SwiftData: scheduled items (oil/tires/brakes) with due/overdue
│   │   ├── MaintenanceReport.swift  # SwiftData: driver-reported issues (low/medium/high severity)
│   │   └── MaintenanceView.swift    # Schedule + Reports tabs + ReportIssueView sheet [iOS]
│   ├── Health/
│   │   ├── HealthManager.swift  # HealthKit: HR, HRV, sleep → fatigue score 0–100 [iOS]
│   │   └── HealthView.swift     # Fatigue score card + health stats grid [iOS]
│   └── Documents/
│       ├── DocumentRepository.swift # Template library: IFTA forms, BOL, log sheets, permits
│       └── DocumentView.swift       # Category filter + search + ShareLink [iOS]
├── Views/
│   ├── DriverView.swift         # 9-tab iOS UI + TelemetryManager + fuel warning banner [iOS]
│   ├── SettingsView.swift       # API key + driver profile (name, CDL state) + HOS cycle
│   └── OnboardingView.swift     # 3-step onboarding: welcome → profile → API key [iOS]
├── macOS/
│   ├── DispatcherDashboardView.swift  # 6-sidebar macOS UI (Fleet/Messages/Communications/Loads/Compliance/Maintenance)
│   ├── MaintenanceDashboardView.swift # Fleet maintenance grid: overdue + urgent reports [macOS]
│   └── DispatcherSettingsView.swift   # macOS settings
├── ContentView.swift            # OS router: iOS→RootView, macOS→DispatcherDashboardView
├── VoiceManager.swift           # SFSpeechRecognizer + AVSpeechSynthesizer + ClaudeToolHandler [iOS]
├── iTruckersCoDriverApp.swift   # @main, SwiftData schema (13 models), CloudKit, RootView onboarding gate
├── Item.swift                   # Legacy scaffold model (keep, in schema)
└── Info.plist                   # Mic + Speech + Location + HealthKit permissions
```

## Key Types

### AppState (Core/AppState.swift)
- `driverName: String` — persisted in UserDefaults
- `hosCycle: HOSCycle` — `.sixtyHour` | `.seventyHour`
- `cdlState: String` — CDL issuing state abbreviation
- `healthMonitoringEnabled: Bool` — opt-in HealthKit
- `driverID: String` — stable UUID per device
- `apiKey: String?` — loaded from Keychain

### DutyStatus enum (AppState.swift)
`.offDuty` | `.sleeperBerth` | `.driving` | `.onDuty`

### HOSSummary struct (AppState.swift)
`driveTimeRemaining`, `onDutyTimeRemaining`, `breakTimeUntilRequired`, `cycleHoursRemaining`, `currentCycleDay`, `isCompliant`, `alerts`

### DriverState (Core/DriverState.swift)
Published: `conversationHistory`, `currentDutyStatus`, `hosRemaining`, `currentLocation`, `activeRoute`, `unreadMessageCount`, `isSpeaking`, `isProcessingAI`, `lastAIError`, `currentSpeedMPH`, `fuelLevel` (%), `estimatedRange` (miles)

## Claude Integration

- **Model:** `claude-opus-4-6`, thinking: `{type: "adaptive"}`, streaming: true
- **API key:** per-driver, stored in Keychain under `anthropic_api_key_<driverID>`; global fallback `anthropic_api_key`
- **ClaudeService:** accepts `apiKey` as parameter — no global state
- **Tool use loop:** `ClaudeService.runToolLoop()` handles multi-turn tool calls
- **SSE parsing:** `SSEStreamDelegate` (URLSessionDataDelegate)
- **TTS:** sentence-chunked — speaks as sentences arrive, not after full response

### Claude Tools (13 total)
| Tool | Purpose |
|------|---------|
| `log_duty_status` | Record HOS duty status change |
| `get_hos_summary` | Get remaining drive/on-duty/cycle time |
| `find_places` | Find fuel/rest/truck stop/weigh station |
| `get_weather` | Current weather at driver location |
| `navigate_to` | Start route to destination |
| `send_dispatch_message` | Send message to dispatcher |
| `log_expense` | Log business expense |
| `contact_customer` | Send ETA/message to consignee |
| `get_delivery_contact` | Look up contact info for a load |
| `report_maintenance_issue` | File a maintenance/safety report |
| `get_health_summary` | Get fatigue score and health stats |
| `get_document` | Retrieve a compliance form or template |

### ClaudeToolHandler Protocol
Implemented by `VoiceManager`. All 12 methods must be implemented. New tools → add to protocol + `executeTool()` switch + `VoiceManager` implementation.

## SwiftData Schema (13 models)
All registered in `iTruckersCoDriverApp.sharedModelContainer`:

| Model | File | Key Fields |
|-------|------|-----------|
| `HOSEntry` | HOSModels.swift | timestamp, dutyStatusRaw, locationName, notes |
| `ExpenseEntry` | HOSModels.swift | date, category, amount, note |
| `TripRecord` | TripRecord.swift | startDate, origin, destination, miles, fuelGallons, grossRevenue, stateMileageJSON |
| `DispatchMessage` | DispatchMessage.swift | timestamp, sender, content, isRead, driverID, deliveryAddress, loadNumber |
| `DriverProfile` | DriverProfile.swift | driverID, name, dutyStatusRaw, driveTimeRemaining, speedMPH, fuelLevel, estimatedRange, hasFatigueAlert |
| `DriverAccount` | DriverAccount.swift | driverID, name, cdlNumber, cdlState, cloudFolderID, onboardingComplete |
| `DeliveryContact` | DeliveryContact.swift | contactName, company, phone, email, address, associatedLoadNumber, driverID |
| `CommunicationLog` | CommunicationLog.swift | timestamp, driverID, contactName, loadNumber, direction, channel, content, confirmed |
| `VehicleMetrics` | VehicleMetrics.swift | timestamp, driverID, speedMPH, fuelLevelGallons, fuelCapacityGallons, odometer |
| `FuelRecord` | FuelRecord.swift | date, driverID, gallons, pricePerGallon, odometer, stateCode |
| `MaintenanceItem` | MaintenanceItem.swift | vehicleID, driverID, category, itemDescription, intervalMiles, intervalDays, isDue, isOverdue |
| `MaintenanceReport` | MaintenanceReport.swift | driverID, issueDescription, severity (low/medium/high), resolved |
| `Item` | Item.swift | legacy scaffold — keep in schema |

CloudKit container: `.automatic` — requires Xcode capability setup (see below).

## Required Xcode Capabilities (not yet configured)
1. **WeatherKit** — Signing & Capabilities → + WeatherKit
2. **iCloud / CloudKit** — + iCloud → CloudKit → create/select container
3. **Push Notifications** — required by CloudKit sync
4. **Background Modes → Remote notifications** — required by CloudKit sync
5. **HealthKit** — + HealthKit (for HealthManager.swift)

## Info.plist Permissions
- `NSMicrophoneUsageDescription` ✓
- `NSSpeechRecognitionUsageDescription` ✓
- `NSLocationWhenInUseUsageDescription` ✓
- `NSHealthShareUsageDescription` ✓
- `NSHealthUpdateUsageDescription` ✓

## Platform Guards
- `#if os(iOS)` — VoiceManager, all driver views, TelemetryManager, HealthManager, HealthView, OnboardingView, DocumentView, MaintenanceView
- `#if os(macOS)` — DispatcherDashboardView, MaintenanceDashboardView, DispatcherSettingsView
- Models and Core files have **no platform guards** — compile on both

## iOS 26 MapKit / AVFoundation API Notes (breaking changes)
- `MKMapItem.location` is **non-optional** `CLLocation` — no `?.` chaining
- `MKMapItem.address` → `MKAddress?` struct, not `String?` — use `item.address.map { String(describing: $0) } ?? ""`
- `CLGeocoder` deprecated → use `MKLocalSearch` or `MKGeocodingRequest`
- `MKPlacemark` deprecated → use `item.location`, `item.address`, `item.name` directly
- `AVAudioSession.sharedInstance().recordPermission` → `AVAudioApplication.shared.recordPermission`
- `AVAudioSession.sharedInstance().requestRecordPermission` → `AVAudioApplication.requestRecordPermission`

## Development Notes
- **SourceKit errors in subdirectory files** are indexing lag, not real errors — Xcode resolves on build
- **Stale warnings:** `rm -rf ~/Library/Developer/Xcode/DerivedData/iTruckersCoDriver*` then clean build
- **`._*.swift` files** are AppleDouble macOS resource forks — ignored by compiler
- **Every file using `ObservableObject` or `@Published`** needs explicit `import Combine`
- **Project uses `fileSystemSynchronizedGroups`** (Xcode 16) — new Swift files in subdirectories are automatically compiled, no `project.pbxproj` edits needed
- **Health data privacy** — raw HealthKit data never leaves device; dispatcher sees only binary `hasFatigueAlert` flag; requires explicit driver opt-in via `appState.healthMonitoringEnabled`

## Onboarding Flow
`iTruckersCoDriverApp` → `RootView` → checks for existing `DriverAccount` with `onboardingComplete == true` OR existing API key → if neither, shows `OnboardingView` (3 steps: welcome → profile → API key validation via test call to `claude-haiku-4-5-20251001`).

## DriverView Tab Order (iOS)
0. Co-Driver (voice)
1. HOS
2. Route
3. Dispatch (badge: unread messages)
4. Compliance
5. Maintenance (badge: overdue count)
6. Health
7. Documents
8. Settings

## DispatcherDashboardView Sidebar Order (macOS)
Fleet · Messages · Communications · Loads · Compliance · Maintenance
