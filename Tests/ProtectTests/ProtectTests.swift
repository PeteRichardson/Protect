import Testing
import Foundation
@testable import Protect

// MARK: - Extension Tests

@Test("String padding adds spaces to reach target length")
func testStringPadding() {
    let shortString = "test"
    let padded = shortString.padded(to: 10)

    #expect(padded.count == 10)
    #expect(padded == "test      ")
}

@Test("String padding truncates when longer than target")
func testStringPaddingTruncates() {
    let longString = "verylongstring"
    let padded = longString.padded(to: 5)

    #expect(padded == "veryl")
    #expect(padded.count == 5)
}

@Test("String padding handles exact length match")
func testStringPaddingExactMatch() {
    let exactString = "exact"
    let padded = exactString.padded(to: 5)

    #expect(padded == exactString)
    #expect(padded.count == 5)
}

@Test("Array asyncMap transforms elements correctly")
func testAsyncMap() async throws {
    let numbers = [1, 2, 3, 4, 5]

    let doubled = await numbers.asyncMap { $0 * 2 }

    #expect(doubled == [2, 4, 6, 8, 10])
}

@Test("Array asyncMap handles async operations")
func testAsyncMapWithDelay() async throws {
    let numbers = [1, 2, 3]

    let result = await numbers.asyncMap { num -> Int in
        try? await Task.sleep(nanoseconds: 1_000_000)
        return num + 10
    }

    #expect(result == [11, 12, 13])
}

// MARK: - Camera Model Tests

@Test("Camera parses from JSON correctly")
func testCameraJSONParsing() throws {
    let json = """
    {
        "id": "camera123",
        "name": "Front Door",
        "state": "CONNECTED",
        "isMicEnabled": true,
        "micVolume": 75,
        "videoMode": "default",
        "hdrType": "auto"
    }
    """

    let data = json.data(using: .utf8)!
    let camera = try JSONDecoder().decode(Camera.self, from: data)

    #expect(camera.id == "camera123")
    #expect(camera.name == "Front Door")
    #expect(camera.state == "CONNECTED")
    #expect(camera.isMicEnabled == true)
    #expect(camera.micVolume == 75)
    #expect(camera.videoMode == "default")
    #expect(camera.hdrType == "auto")
}

@Test("Camera array parses from JSON")
func testCameraArrayParsing() throws {
    let json = """
    [
        {
            "id": "cam1",
            "name": "Camera 1",
            "state": "CONNECTED",
            "isMicEnabled": false,
            "micVolume": 0,
            "videoMode": "default",
            "hdrType": "off"
        },
        {
            "id": "cam2",
            "name": "Camera 2",
            "state": "DISCONNECTED",
            "isMicEnabled": true,
            "micVolume": 50,
            "videoMode": "high",
            "hdrType": "on"
        }
    ]
    """

    let data = json.data(using: .utf8)!
    let cameras = try Camera.parse(data)

    #expect(cameras.count == 2)
    #expect(cameras[0].name == "Camera 1")
    #expect(cameras[1].name == "Camera 2")
}

@Test("Camera CSV export has correct format")
func testCameraCSVExport() throws {
    let camera = Camera(
        id: "cam123",
        state: "CONNECTED",
        name: "Test Camera",
        isMicEnabled: true,
        micVolume: 80,
        videoMode: "default",
        hdrType: "auto"
    )

    let csv = camera.csvDescription()

    #expect(csv == "Test Camera,cam123,CONNECTED,true,80,default,auto")
    #expect(Camera.csvHeader == "name,id,state,isMicEnabled,micVolume,videoMode,hdrType")
}

@Test("Camera description formatting")
func testCameraDescription() {
    let camera = Camera(
        id: "cam123",
        state: "CONNECTED",
        name: "Front",
        isMicEnabled: false,
        micVolume: 0,
        videoMode: "default",
        hdrType: "off"
    )

    let desc = camera.description

    #expect(desc.contains("Front"))
    #expect(desc.contains("cam123"))
    #expect(desc.contains("CONNECTED"))
}

@Test("Camera comparison by name")
func testCameraComparison() {
    let camera1 = Camera(id: "1", state: "CONNECTED", name: "Alpha", isMicEnabled: false, micVolume: 0, videoMode: "default", hdrType: "off")
    let camera2 = Camera(id: "2", state: "CONNECTED", name: "Beta", isMicEnabled: false, micVolume: 0, videoMode: "default", hdrType: "off")
    let camera3 = Camera(id: "3", state: "CONNECTED", name: "Alpha", isMicEnabled: false, micVolume: 0, videoMode: "default", hdrType: "off")

    #expect(camera1 < camera2)
    #expect(camera1 == camera3)
}

// MARK: - Liveview Model Tests

@Test("Liveview parses from JSON correctly")
func testLiveviewJSONParsing() throws {
    let json = """
    {
        "id": "lv123",
        "name": "Main View",
        "isDefault": true,
        "isGlobal": false,
        "owner": "admin",
        "layout": 4,
        "slots": [
            {
                "cameras": ["cam1", "cam2"],
                "cycleMode": "auto",
                "cycleInterval": 30
            }
        ]
    }
    """

    let data = json.data(using: .utf8)!
    let liveview = try JSONDecoder().decode(Liveview.self, from: data)

    #expect(liveview.id == "lv123")
    #expect(liveview.name == "Main View")
    #expect(liveview.isDefault == true)
    #expect(liveview.isGlobal == false)
    #expect(liveview.owner == "admin")
    #expect(liveview.layout == 4)
    #expect(liveview.slots.count == 1)
    #expect(liveview.slots[0].cameras == ["cam1", "cam2"])
    #expect(liveview.slots[0].cycleMode == "auto")
    #expect(liveview.slots[0].cycleInterval == 30)
}

@Test("Liveview CSV export has correct format")
func testLiveviewCSVExport() throws {
    let liveview = Liveview(
        id: "lv123",
        name: "Test View",
        isDefault: true,
        isGlobal: false,
        owner: "admin",
        layout: 2,
        slots: []
    )

    let csv = liveview.csvDescription()

    #expect(csv == "Test View,lv123,true,false,admin,2")
    #expect(Liveview.csvHeader == "name,id,isDefault,isGlobal,owner,layout")
}

@Test("Liveview description includes default marker")
func testLiveviewDescription() {
    let defaultView = Liveview(id: "lv1", name: "Default", isDefault: true, isGlobal: false, owner: "admin", layout: 1, slots: [])
    let normalView = Liveview(id: "lv2", name: "Normal", isDefault: false, isGlobal: false, owner: "admin", layout: 1, slots: [])

    #expect(defaultView.description.contains("(default)"))
    #expect(!normalView.description.contains("(default)"))
}

// MARK: - Viewport Model Tests

@Test("Viewport parses from JSON correctly")
func testViewportJSONParsing() throws {
    let json = """
    {
        "id": "vp123",
        "name": "Living Room Display",
        "liveview": "lv456",
        "state": "ACTIVE",
        "streamLimit": 4
    }
    """

    let data = json.data(using: .utf8)!
    let viewport = try JSONDecoder().decode(Viewport.self, from: data)

    #expect(viewport.id == "vp123")
    #expect(viewport.name == "Living Room Display")
    #expect(viewport.liveview == "lv456")
    #expect(viewport.state == "ACTIVE")
    #expect(viewport.streamLimit == 4)
}

@Test("Viewport CSV export has correct format")
func testViewportCSVExport() {
    let viewport = Viewport(
        id: "vp123",
        liveview: "lv456",
        name: "Test Display",
        state: "ACTIVE",
        streamLimit: 8
    )

    let csv = viewport.csvDescription()

    #expect(csv == "Test Display,vp123,lv456,ACTIVE,8")
    #expect(Viewport.csvHeader == "name,id,liveview,state,streamLimit")
}

@Test("Viewport description shows current liveview")
func testViewportDescription() {
    let viewport = Viewport(
        id: "vp1",
        liveview: "main-view",
        name: "Display",
        state: "ACTIVE",
        streamLimit: 4
    )

    let desc = viewport.description

    #expect(desc.contains("Display"))
    #expect(desc.contains("vp1"))
    #expect(desc.contains("main-view"))
}

// MARK: - ProtectService Tests

@Test("ProtectService initializes with host and API key")
func testServiceInitialization() {
    let service = ProtectService(host: "192.168.1.100", apiKey: "test-key")

    #expect(service.base_url.absoluteString == "http://192.168.1.100/proxy/protect/integration/v1")
}

@Test("ProtectService constructs correct base URL")
func testBaseURLConstruction() {
    let service1 = ProtectService(host: "protect.local", apiKey: "key1")
    let service2 = ProtectService(host: "10.0.0.1:7443", apiKey: "key2")

    #expect(service1.base_url.absoluteString == "http://protect.local/proxy/protect/integration/v1")
    #expect(service2.base_url.absoluteString == "http://10.0.0.1:7443/proxy/protect/integration/v1")
}

@Test("Lookup camera ID returns nil for nonexistent camera")
func testLookupCameraNotFound() async throws {
    let service = MockProtectService(host: "test.local", apiKey: "key")

    let mockCameras = [
        Camera(id: "cam1", state: "CONNECTED", name: "Front Door", isMicEnabled: false, micVolume: 0, videoMode: "default", hdrType: "off"),
        Camera(id: "cam2", state: "CONNECTED", name: "Back Yard", isMicEnabled: false, micVolume: 0, videoMode: "default", hdrType: "off")
    ]
    service.mockCameras = mockCameras

    let result = try await service.lookupCameraId(byName: "Nonexistent")

    #expect(result == nil)
}

@Test("Lookup camera ID is case insensitive")
func testLookupCameraCaseInsensitive() async throws {
    let service = MockProtectService(host: "test.local", apiKey: "key")

    let mockCameras = [
        Camera(id: "cam1", state: "CONNECTED", name: "Front Door", isMicEnabled: false, micVolume: 0, videoMode: "default", hdrType: "off")
    ]
    service.mockCameras = mockCameras

    let result1 = try await service.lookupCameraId(byName: "front door")
    let result2 = try await service.lookupCameraId(byName: "FRONT DOOR")
    let result3 = try await service.lookupCameraId(byName: "Front Door")

    #expect(result1 == "cam1")
    #expect(result2 == "cam1")
    #expect(result3 == "cam1")
}

@Test("Lookup liveview name by ID")
func testLookupLiveviewName() async throws {
    let service = MockProtectService(host: "test.local", apiKey: "key")

    let mockLiveviews = [
        Liveview(id: "lv1", name: "Main View", isDefault: true, isGlobal: false, owner: "admin", layout: 4, slots: []),
        Liveview(id: "lv2", name: "Alternate View", isDefault: false, isGlobal: false, owner: "admin", layout: 2, slots: [])
    ]
    service.mockLiveviews = mockLiveviews

    let result1 = try await service.lookupLiveviewName(byId: "lv1")
    let result2 = try await service.lookupLiveviewName(byId: "lv2")
    let result3 = try await service.lookupLiveviewName(byId: "nonexistent")

    #expect(result1 == "Main View")
    #expect(result2 == "Alternate View")
    #expect(result3 == nil)
}

@Test("Lookup viewport ID by name is case insensitive")
func testLookupViewportCaseInsensitive() async throws {
    let service = MockProtectService(host: "test.local", apiKey: "key")

    let mockViewports = [
        Viewport(id: "vp1", liveview: "lv1", name: "Living Room", state: "ACTIVE", streamLimit: 4)
    ]
    service.mockViewports = mockViewports

    let result1 = try await service.lookupViewportId(byName: "living room")
    let result2 = try await service.lookupViewportId(byName: "LIVING ROOM")

    #expect(result1 == "vp1")
    #expect(result2 == "vp1")
}

// MARK: - Mock Service for Testing

class MockProtectService: ProtectService {
    var mockCameras: [Camera]?
    var mockLiveviews: [Liveview]?
    var mockViewports: [Viewport]?

    override func cameras() async throws -> [Camera] {
        return mockCameras ?? []
    }

    override func liveviews() async throws -> [Liveview] {
        return mockLiveviews ?? []
    }

    override func viewports() async throws -> [Viewport] {
        return mockViewports ?? []
    }
}
