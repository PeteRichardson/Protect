# Protect

A Swift package for interacting with a subset of the Unifi Protect API, providing a clean and type-safe interface for managing cameras, liveviews, and viewports.

## Features

- 🎥 **Camera Management** - Fetch camera details and snapshots
- 📺 **Liveview Control** - Access and manage multi-camera layouts
- 🖥️ **Viewport Management** - Control what's displayed on viewers/displays
- 🔄 **Smart Caching** - Built-in caching to minimize API calls
- 📊 **CSV Export** - Export data to CSV format for analysis
- ⚡ **Async/Await** - Modern Swift concurrency support
- 🔍 **Case-Insensitive Lookups** - Find resources by name without case sensitivity

## Requirements

- macOS 15.0+
- Swift 6.2+
- Unifi Protect console with API access

## Installation

### Swift Package Manager

Add Protect to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/PeteRichardson/Protect.git", from: "1.0.0")
]
```

Then add it to your target dependencies:

```swift
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["Protect"]
    )
]
```

## Usage

### Initialize the Service

```swift
import Protect

let service = try ProtectService(
    host: "192.168.1.100",  // Your Unifi Protect console IP/hostname
    apiKey: "your-api-key"   // API key from Unifi Protect
)
```

The initializer throws `ProtectError.invalidHost` if `host` can't form a valid URL, so a
typo is rejected at construction rather than crashing on the first request. Pass the host
alone — a scheme, path, or query makes it invalid. A port is fine (`10.0.0.1:7443`).

Traffic uses HTTPS, and by default the certificate the console at `host` presents is accepted
even when self-signed, which is what a UniFi console on a LAN requires. To demand a
fully-trusted certificate chain instead:

```swift
let service = try ProtectService(
    host: "protect.example.com",
    apiKey: "your-api-key",
    allowsSelfSignedCertificate: false
)
```

### Fetch Cameras

```swift
let cameras = try await service.cameras()

for camera in cameras {
    print("\(camera.name): \(camera.state)")
}
```

### Get a Camera Snapshot

```swift
let snapshotData = try await service.getSnapshot(
    from: "Front Door",
    with: true  // high quality — appends `highQuality=true` to the request
)

// Save snapshot to file
try snapshotData.write(to: URL(fileURLWithPath: "snapshot.jpg"))
```

### Manage Liveviews

```swift
let liveviews = try await service.liveviews()

for liveview in liveviews {
    print("\(liveview.name) - \(liveview.layout) cameras")
}
```

### Control Viewports

```swift
// Get all viewports
let viewports = try await service.viewports()

// Change what a viewport is displaying, by name
try await service.changeViewportView(
    onViewportNamed: "Kitchen Display",
    toLiveviewNamed: "All Cameras"
)

// Or by raw ID, if you already have them
try await service.changeViewportView(
    on: "viewport-id",
    to: "liveview-id"
)
```

Both names are resolved before any request is sent, so an unknown name throws
`ProtectError.viewportNotFound` or `.liveviewNotFound` without touching the console.

### Lookup by Name

```swift
// Find camera ID by name (case-insensitive)
if let cameraId = try await service.lookupCameraId(byName: "front door") {
    print("Camera ID: \(cameraId)")
}

// Find liveview name by ID
if let liveviewName = try await service.lookupLiveviewName(byId: "lv123") {
    print("Liveview: \(liveviewName)")
}

// ...and the other direction
if let liveviewId = try await service.lookupLiveviewId(byName: "All Cameras") {
    print("Liveview ID: \(liveviewId)")
}

// Find viewport ID by name
if let viewportId = try await service.lookupViewportId(byName: "living room") {
    print("Viewport ID: \(viewportId)")
}
```

### Export to CSV

```swift
let cameras = try await service.cameras()

// Print CSV header
print(Camera.csvHeader)

// Print each camera as CSV row
for camera in cameras {
    print(camera.csvDescription())
}
```

## API Overview

### ProtectService

The main service class for interacting with the Unifi Protect API.

#### Properties

- `baseURL: URL` - The resolved API endpoint, e.g. `https://192.168.1.100/proxy/protect/integration/v1`

#### Methods

- `init(host: String, apiKey: String, allowsSelfSignedCertificate: Bool = true) throws` - Create a service, validating `host`
- `cameras() async throws -> [Camera]` - Fetch all cameras (cached after first call)
- `liveviews() async throws -> [Liveview]` - Fetch all liveviews (cached)
- `viewports() async throws -> [Viewport]` - Fetch all viewports (cached)
- `getSnapshot(from: String, with: Bool) async throws -> Data` - Get camera snapshot; `with: true` requests full resolution
- `changeViewportView(onViewportNamed: String, toLiveviewNamed: String) async throws` - Change viewport display, by name
- `changeViewportView(on: String, to: String) async throws` - Change viewport display, by raw ID
- `lookupCameraId(byName: String) async throws -> String?` - Find camera ID by name
- `lookupLiveviewId(byName: String) async throws -> String?` - Find liveview ID by name
- `lookupLiveviewName(byId: String) async throws -> String?` - Find liveview name by ID
- `lookupViewportId(byName: String) async throws -> String?` - Find viewport ID by name

All four lookups are `public`. Name matching is case-insensitive throughout, and each returns
`nil` rather than throwing when there's no match.

### Data Models

#### Camera

```swift
struct Camera {
    var id: String
    var name: String
    var state: String
    var isMicEnabled: Bool
    var micVolume: Int
    var videoMode: String
    var hdrType: String
}
```

#### Liveview

```swift
struct Liveview {
    var id: String
    var name: String
    var isDefault: Bool
    var isGlobal: Bool
    var owner: String
    var layout: Int
    var slots: [Slot]
}
```

#### Viewport

```swift
struct Viewport {
    var id: String
    var name: String
    var liveview: String
    var state: String
    var streamLimit: Int
}
```

## Testing

The package includes comprehensive unit tests covering all major functionality.

Run tests using:

```bash
swift test
```

Current test coverage includes:
- Extension utilities (String padding, async array mapping)
- JSON parsing for all data models
- CSV export functionality
- Service initialization and URL construction
- Lookup functions with case-insensitive matching
- Caching behavior

## How It Works

### Caching

The service automatically caches API responses for cameras, liveviews, and viewports after the first request. This dramatically reduces API load and improves performance for subsequent calls.

### API Integration

Protect uses the Unifi Protect Integration API v1:

```
https://{host}/proxy/protect/integration/v1
```

All requests include authentication via the `X-API-KEY` header, which is why the transport is
TLS: on plain HTTP that header crosses the network in cleartext.

### Logging

The package uses `OSLog` for structured logging. You can monitor API requests and responses using Console.app by filtering for the `ProtectService` category.

## Error Handling

Everything this package originates is a `ProtectError`, so failures are distinguished by
pattern matching rather than by status codes on an `NSError`:

```swift
public enum ProtectError: Error, Equatable, LocalizedError {
    case invalidHost(String)              // bad host at initialization
    case cameraNotFound(String)           // no camera matched that name
    case httpStatus(Int, body: String?)   // non-2xx, with the server's explanation
    case invalidResponse                  // reply wasn't an HTTP response
}
```

`httpStatus` carries the console's response body (truncated to 1 KB) when it sent one. The
Protect API returns a JSON payload explaining *why* a request failed, and it is usually far
more specific than the status code — a `401` body distinguishes an expired API key from one
that was never valid.

Failures originating below this package still surface as their own types: `URLSession` raises
`URLError` for an unreachable host, a TLS trust failure, or a cancelled task, and `cameras()`
and friends rethrow `DecodingError` when the console's JSON doesn't match the model.

```swift
do {
    let cameras = try await service.cameras()
} catch ProtectError.httpStatus(401, let body) {
    print("Check the API key: \(body ?? "no detail")")
} catch let error as ProtectError {
    print("Protect rejected the request: \(error.localizedDescription)")
} catch {
    print("Failed to fetch cameras: \(error)")
}
```

## License

This project is available under the MIT License. See LICENSE file for details.

## Related Projects

- [camview](https://github.com/PeteRichardson/camview) - Application using this package
