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
func testServiceInitialization() throws {
    let service = try ProtectService(host: "192.168.1.100", apiKey: "test-key")

    #expect(service.baseURL.absoluteString == "https://192.168.1.100/proxy/protect/integration/v1")
}

@Test("ProtectService constructs correct base URL")
func testBaseURLConstruction() throws {
    let service1 = try ProtectService(host: "protect.local", apiKey: "key1")
    let service2 = try ProtectService(host: "10.0.0.1:7443", apiKey: "key2")

    #expect(service1.baseURL.absoluteString == "https://protect.local/proxy/protect/integration/v1")
    #expect(service2.baseURL.absoluteString == "https://10.0.0.1:7443/proxy/protect/integration/v1")
}

@Test("ProtectService always uses TLS")
func testBaseURLUsesTLS() throws {
    let service = try ProtectService(host: "192.168.1.100", apiKey: "test-key")

    #expect(service.baseURL.scheme == "https")
}

@Test("A host containing a space is rejected at construction")
func testHostWithSpaceIsRejected() {
    #expect(throws: ProtectError.invalidHost("my console")) {
        _ = try ProtectService(host: "my console", apiKey: "key")
    }
}

@Test("An empty host is rejected at construction")
func testEmptyHostIsRejected() {
    #expect(throws: ProtectError.invalidHost("")) {
        _ = try ProtectService(host: "", apiKey: "key")
    }
}

@Test("A host carrying its own scheme is rejected at construction")
func testHostWithSchemeIsRejected() {
    #expect(throws: ProtectError.invalidHost("http://192.168.1.100")) {
        _ = try ProtectService(host: "http://192.168.1.100", apiKey: "key")
    }
}

@Test("invalidHost error names the offending host")
func testInvalidHostErrorIsDescriptive() {
    let error = ProtectError.invalidHost("bad host")

    #expect(error.errorDescription?.contains("bad host") == true)
}

// MARK: - ProtectError Tests

@Test("cameraNotFound error names the camera")
func testCameraNotFoundIsDescriptive() {
    let error = ProtectError.cameraNotFound("Front Door")

    #expect(error.errorDescription?.contains("Front Door") == true)
}

@Test("httpStatus error reports the code and the server's body")
func testHTTPStatusIncludesBody() throws {
    let error = ProtectError.httpStatus(404, body: "{\"error\":\"camera not found\"}")

    let description = try #require(error.errorDescription)
    #expect(description.contains("404"))
    #expect(description.contains("camera not found"))
}

@Test("httpStatus error without a body omits it rather than printing nil")
func testHTTPStatusWithoutBody() throws {
    let error = ProtectError.httpStatus(500, body: nil)

    let description = try #require(error.errorDescription)
    #expect(description.contains("500"))
    #expect(!description.lowercased().contains("nil"))
}

@Test("invalidResponse error has a description")
func testInvalidResponseIsDescriptive() {
    let error = ProtectError.invalidResponse

    #expect(error.errorDescription?.isEmpty == false)
}

@Test("viewportNotFound and liveviewNotFound name what was missing")
func testNotFoundErrorsAreDescriptive() throws {
    let viewport = try #require(ProtectError.viewportNotFound("Kitchen").errorDescription)
    let liveview = try #require(ProtectError.liveviewNotFound("Main View").errorDescription)

    #expect(viewport.contains("Kitchen"))
    #expect(liveview.contains("Main View"))
}

// MARK: - Snapshot URL Tests

@Test("A standard-quality snapshot URL carries no query")
func testSnapshotURLStandardQuality() throws {
    let base = try #require(URL(string: "https://192.168.1.100/proxy/protect/integration/v1"))

    let url = ProtectService.snapshotURL(base: base, cameraId: "cam1", highQuality: false)

    #expect(
        url.absoluteString
            == "https://192.168.1.100/proxy/protect/integration/v1/cameras/cam1/snapshot")
}

@Test("A high-quality snapshot URL carries highQuality=true")
func testSnapshotURLHighQuality() throws {
    let base = try #require(URL(string: "https://192.168.1.100/proxy/protect/integration/v1"))

    let url = ProtectService.snapshotURL(base: base, cameraId: "cam1", highQuality: true)

    #expect(
        url.absoluteString
            == "https://192.168.1.100/proxy/protect/integration/v1/cameras/cam1/snapshot?highQuality=true"
    )
}

// MARK: - Error Body Rendering Tests

@Test("An empty response body renders as no body at all")
func testErrorBodyEmptyIsNil() {
    #expect(ProtectService.errorBody(from: Data()) == nil)
}

@Test("A whitespace-only response body renders as no body at all")
func testErrorBodyWhitespaceIsNil() {
    let data = Data("   \n\t  ".utf8)

    #expect(ProtectService.errorBody(from: data) == nil)
}

@Test("A short response body is returned verbatim")
func testErrorBodyShortIsVerbatim() {
    let data = Data("{\"error\":\"nope\"}".utf8)

    #expect(ProtectService.errorBody(from: data) == "{\"error\":\"nope\"}")
}

@Test("An oversized response body is truncated and marked as truncated")
func testErrorBodyLongIsTruncated() throws {
    let data = Data(String(repeating: "x", count: 40).utf8)

    let rendered = try #require(ProtectService.errorBody(from: data, limit: 10))

    #expect(rendered.hasPrefix(String(repeating: "x", count: 10)))
    #expect(rendered.count < 40)
    #expect(rendered.lowercased().contains("truncated"))
}

// MARK: - Networking and Caching Tests
//
// These drive the real `request` / caching path through a stubbed `URLProtocol`, which is
// what the injectable session exists for. The suite is `.serialized` because `StubURLProtocol`
// registers its canned responses in process-wide static state — `URLSession` instantiates
// protocol objects on its own threads, so there is nowhere task-local to put them.

@Suite("Networking", .serialized)
struct NetworkingTests {

    /// Builds a service wired to the stub, with no cameras/liveviews/viewports configured.
    private func makeService() throws -> ProtectService {
        try ProtectService(
            host: "test.local", apiKey: "test-key", session: StubURLProtocol.makeSession())
    }

    init() {
        StubURLProtocol.reset()
    }

    // MARK: Caching

    @Test("A cold cache fetches once, and a second call does not hit the network")
    func testCachePopulatesOnce() async throws {
        StubURLProtocol.stub(path: "/cameras", json: Fixtures.twoCameras)
        let service = try makeService()

        let first = try await service.cameras()
        let second = try await service.cameras()

        #expect(first.count == 2)
        #expect(second.count == 2)
        #expect(StubURLProtocol.requests(matching: "/cameras").count == 1)
    }

    @Test("Each resource type caches independently")
    func testCachesAreIndependent() async throws {
        StubURLProtocol.stub(path: "/cameras", json: Fixtures.twoCameras)
        StubURLProtocol.stub(path: "/viewers", json: Fixtures.oneViewport)
        let service = try makeService()

        _ = try await service.cameras()
        _ = try await service.viewports()
        _ = try await service.cameras()

        #expect(StubURLProtocol.requests(matching: "/cameras").count == 1)
        #expect(StubURLProtocol.requests(matching: "/viewers").count == 1)
    }

    @Test("A failed fetch is not cached, so a later call retries")
    func testFailedFetchIsNotCached() async throws {
        StubURLProtocol.stub(path: "/cameras", status: 500, json: "{}")
        let service = try makeService()

        await #expect(throws: ProtectError.self) { _ = try await service.cameras() }

        StubURLProtocol.stub(path: "/cameras", json: Fixtures.twoCameras)
        let recovered = try await service.cameras()

        #expect(recovered.count == 2)
        #expect(StubURLProtocol.requests(matching: "/cameras").count == 2)
    }

    // MARK: Request construction

    @Test("Every request carries the API key")
    func testRequestSendsAPIKey() async throws {
        StubURLProtocol.stub(path: "/cameras", json: Fixtures.twoCameras)
        let service = try makeService()

        _ = try await service.cameras()

        let recorded = try #require(StubURLProtocol.requests(matching: "/cameras").first)
        #expect(recorded.headers["X-API-KEY"] == "test-key")
    }

    @Test("Fetches are GETs against the versioned integration path")
    func testFetchIsGetOnIntegrationPath() async throws {
        StubURLProtocol.stub(path: "/liveviews", json: Fixtures.oneLiveview)
        let service = try makeService()

        _ = try await service.liveviews()

        let recorded = try #require(StubURLProtocol.requests(matching: "/liveviews").first)
        #expect(recorded.method == "GET")
        #expect(recorded.url.contains("/proxy/protect/integration/v1/liveviews"))
    }

    // MARK: Failure paths

    @Test("A non-2xx response throws httpStatus carrying the code and the server's body")
    func testNonSuccessThrowsWithCodeAndBody() async throws {
        StubURLProtocol.stub(
            path: "/cameras", status: 401, json: "{\"error\":\"invalid api key\"}")
        let service = try makeService()

        await #expect(
            throws: ProtectError.httpStatus(401, body: "{\"error\":\"invalid api key\"}")
        ) {
            _ = try await service.cameras()
        }
    }

    @Test("A 404 with an empty body throws httpStatus with no body rather than an empty one")
    func testNonSuccessWithEmptyBody() async throws {
        StubURLProtocol.stub(path: "/cameras", status: 404, json: "")
        let service = try makeService()

        await #expect(throws: ProtectError.httpStatus(404, body: nil)) {
            _ = try await service.cameras()
        }
    }

    @Test("Malformed JSON surfaces as a decoding error, not as success")
    func testMalformedJSONThrows() async throws {
        StubURLProtocol.stub(path: "/cameras", json: "{ this is not json ")
        let service = try makeService()

        await #expect(throws: DecodingError.self) {
            _ = try await service.cameras()
        }
    }

    @Test("JSON of the wrong shape surfaces as a decoding error")
    func testWrongShapeJSONThrows() async throws {
        StubURLProtocol.stub(path: "/cameras", json: "[{\"unexpected\":true}]")
        let service = try makeService()

        await #expect(throws: DecodingError.self) {
            _ = try await service.cameras()
        }
    }

    // MARK: Writes

    @Test("changeViewportView issues a PATCH carrying the liveview id")
    func testChangeViewportViewIssuesPatch() async throws {
        StubURLProtocol.stub(path: "/viewers/vp1", json: "{}")
        let service = try makeService()

        try await service.changeViewportView(on: "vp1", to: "lv9")

        let recorded = try #require(StubURLProtocol.requests(matching: "/viewers/vp1").first)
        #expect(recorded.method == "PATCH")

        let body = try #require(recorded.body)
        let decoded = try JSONDecoder().decode([String: String].self, from: body)
        #expect(decoded == ["liveview": "lv9"])
    }

    @Test("The name-based viewport change resolves both names, then PATCHes by id")
    func testChangeViewportViewByNameResolvesThenPatches() async throws {
        StubURLProtocol.stub(path: "/viewers/vp1", json: "{}")
        StubURLProtocol.stub(path: "/viewers", json: Fixtures.oneViewport)
        StubURLProtocol.stub(path: "/liveviews", json: Fixtures.oneLiveview)
        let service = try makeService()

        try await service.changeViewportView(
            onViewportNamed: "kitchen display", toLiveviewNamed: "all cameras")

        let recorded = try #require(StubURLProtocol.requests(matching: "/viewers/vp1").first)
        #expect(recorded.method == "PATCH")

        let body = try #require(recorded.body)
        let decoded = try JSONDecoder().decode([String: String].self, from: body)
        #expect(decoded == ["liveview": "lv1"])
    }

    // MARK: Snapshots

    @Test("getSnapshot resolves the camera name and returns the image bytes")
    func testGetSnapshotReturnsImageData() async throws {
        StubURLProtocol.stub(path: "/cameras", json: Fixtures.twoCameras)
        StubURLProtocol.stub(path: "/cameras/cam1/snapshot", data: Data([0xFF, 0xD8, 0xFF, 0xE0]))
        let service = try makeService()

        let image = try await service.getSnapshot(from: "front door", with: false)

        #expect(image == Data([0xFF, 0xD8, 0xFF, 0xE0]))
    }

    @Test("A high-quality snapshot request carries highQuality=true on the wire")
    func testGetSnapshotHighQualityQueryReachesTheWire() async throws {
        StubURLProtocol.stub(path: "/cameras", json: Fixtures.twoCameras)
        StubURLProtocol.stub(path: "/cameras/cam1/snapshot", data: Data([0xFF, 0xD8]))
        let service = try makeService()

        _ = try await service.getSnapshot(from: "Front Door", with: true)

        let recorded = try #require(
            StubURLProtocol.requests(matching: "/cameras/cam1/snapshot").first)
        #expect(recorded.query == "highQuality=true")
    }

    @Test("An unsupported high-quality snapshot surfaces the console's own explanation")
    func testGetSnapshotHighQualityRejection() async throws {
        StubURLProtocol.stub(path: "/cameras", json: Fixtures.twoCameras)
        StubURLProtocol.stub(
            path: "/cameras/cam1/snapshot", status: 400,
            json: "{\"error\":\"Camera does not support full HD snapshot\",\"name\":\"BAD_REQUEST\"}")
        let service = try makeService()

        await #expect(
            throws: ProtectError.httpStatus(
                400,
                body:
                    "{\"error\":\"Camera does not support full HD snapshot\",\"name\":\"BAD_REQUEST\"}"
            )
        ) {
            _ = try await service.getSnapshot(from: "Front Door", with: true)
        }
    }

    // MARK: Lookups

    @Test("Lookup camera ID is case insensitive")
    func testLookupCameraCaseInsensitive() async throws {
        StubURLProtocol.stub(path: "/cameras", json: Fixtures.twoCameras)
        let service = try makeService()

        #expect(try await service.lookupCameraId(byName: "FRONT DOOR") == "cam1")
        #expect(try await service.lookupCameraId(byName: "front door") == "cam1")
    }

    @Test("Lookup camera ID returns nil for a nonexistent camera")
    func testLookupCameraNotFound() async throws {
        StubURLProtocol.stub(path: "/cameras", json: Fixtures.twoCameras)
        let service = try makeService()

        #expect(try await service.lookupCameraId(byName: "Nonexistent") == nil)
    }

    @Test("Lookup liveview name by ID")
    func testLookupLiveviewName() async throws {
        StubURLProtocol.stub(path: "/liveviews", json: Fixtures.oneLiveview)
        let service = try makeService()

        #expect(try await service.lookupLiveviewName(byId: "lv1") == "All Cameras")
        #expect(try await service.lookupLiveviewName(byId: "nope") == nil)
    }

    @Test("Lookup liveview ID by name is case insensitive")
    func testLookupLiveviewIdByName() async throws {
        StubURLProtocol.stub(path: "/liveviews", json: Fixtures.oneLiveview)
        let service = try makeService()

        #expect(try await service.lookupLiveviewId(byName: "all cameras") == "lv1")
        #expect(try await service.lookupLiveviewId(byName: "Nope") == nil)
    }

    @Test("Lookup viewport ID by name is case insensitive")
    func testLookupViewportCaseInsensitive() async throws {
        StubURLProtocol.stub(path: "/viewers", json: Fixtures.oneViewport)
        let service = try makeService()

        #expect(try await service.lookupViewportId(byName: "KITCHEN DISPLAY") == "vp1")
    }

    // MARK: Name resolution failures

    @Test("getSnapshot throws cameraNotFound for an unknown camera")
    func testGetSnapshotThrowsCameraNotFound() async throws {
        StubURLProtocol.stub(path: "/cameras", json: Fixtures.twoCameras)
        let service = try makeService()

        // "Garage" is deliberately absent from the fixture. Naming a camera that *is* present
        // would resolve fine and then 404 on the unstubbed snapshot path, which passes for the
        // wrong reason.
        await #expect(throws: ProtectError.cameraNotFound("Garage")) {
            _ = try await service.getSnapshot(from: "Garage", with: false)
        }
    }

    @Test("Changing a viewport by name rejects an unknown viewport before any PATCH")
    func testChangeViewportByNameUnknownViewport() async throws {
        StubURLProtocol.stub(path: "/viewers", json: "[]")
        StubURLProtocol.stub(path: "/liveviews", json: Fixtures.oneLiveview)
        let service = try makeService()

        await #expect(throws: ProtectError.viewportNotFound("Kitchen")) {
            try await service.changeViewportView(
                onViewportNamed: "Kitchen", toLiveviewNamed: "All Cameras")
        }
        #expect(StubURLProtocol.requests(matching: "PATCH").isEmpty)
    }

    @Test("Changing a viewport by name rejects an unknown liveview before any PATCH")
    func testChangeViewportByNameUnknownLiveview() async throws {
        StubURLProtocol.stub(path: "/viewers", json: Fixtures.oneViewport)
        StubURLProtocol.stub(path: "/liveviews", json: "[]")
        let service = try makeService()

        await #expect(throws: ProtectError.liveviewNotFound("All Cameras")) {
            try await service.changeViewportView(
                onViewportNamed: "Kitchen Display", toLiveviewNamed: "All Cameras")
        }
        #expect(StubURLProtocol.requests(matching: "PATCH").isEmpty)
    }

    // MARK: Concurrency

    @Test("One service instance is safely shared across concurrent tasks")
    func testConcurrentAccessFromTaskGroup() async throws {
        StubURLProtocol.stub(path: "/cameras", json: Fixtures.twoCameras)
        StubURLProtocol.stub(path: "/liveviews", json: Fixtures.oneLiveview)
        StubURLProtocol.stub(path: "/viewers", json: Fixtures.oneViewport)
        let service = try makeService()

        // This is the shape #8 reported as a compile error against the old non-Sendable class:
        // "non-Sendable type 'ProtectService' of let 'service' cannot exit main actor-isolated
        // context". That it compiles at all is the regression test.
        try await withThrowingTaskGroup(of: Int.self) { group in
            for _ in 0..<8 {
                group.addTask { try await service.cameras().count }
                group.addTask { try await service.liveviews().count }
                group.addTask { try await service.viewports().count }
            }
            var total = 0
            for try await count in group { total += count }
            #expect(total == 8 * (2 + 1 + 1))
        }
    }
}

// MARK: - Fixtures

enum Fixtures {
    static let twoCameras = """
        [
          {"id":"cam1","name":"Front Door","state":"CONNECTED","isMicEnabled":false,
           "micVolume":0,"videoMode":"default","hdrType":"off"},
          {"id":"cam2","name":"Back Yard","state":"CONNECTED","isMicEnabled":true,
           "micVolume":50,"videoMode":"default","hdrType":"off"}
        ]
        """

    static let oneLiveview = """
        [
          {"id":"lv1","name":"All Cameras","isDefault":true,"isGlobal":false,
           "owner":"admin","layout":4,"slots":[]}
        ]
        """

    static let oneViewport = """
        [
          {"id":"vp1","name":"Kitchen Display","liveview":"lv1","state":"ACTIVE","streamLimit":4}
        ]
        """
}

// MARK: - URLProtocol Stub
//
// Replaces the former `MockProtectService`, which subclassed `ProtectService` and overrode
// `cameras()` / `liveviews()` / `viewports()` — the very methods that call the networking and
// caching code, so everything worth testing was bypassed rather than exercised. Subclassing is
// also impossible now that `ProtectService` is an `actor`.

/// A `URLProtocol` that answers requests from canned responses and records what it was asked.
///
/// Registered on a `URLSessionConfiguration` and injected via
/// `ProtectService.init(host:apiKey:allowsSelfSignedCertificate:session:)`, so requests are
/// intercepted below `URLSession` without any network access.
///
/// State is static and lock-guarded because `URLSession` instantiates protocol objects itself,
/// on its own threads — there is no instance for a test to hold and no task-local context to
/// use. `NetworkingTests` is `.serialized` for the same reason.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {

    /// A request the stub answered, captured for assertions.
    struct Recorded: Sendable {
        let method: String
        let url: String
        let path: String
        let query: String?
        let body: Data?
        let headers: [String: String]
    }

    private struct Response {
        let status: Int
        let data: Data
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var responses: [String: Response] = [:]
    nonisolated(unsafe) private static var recorded: [Recorded] = []

    // MARK: Test-facing API

    /// Builds a session that routes every request through this stub.
    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    /// Clears all canned responses and the recorded request log.
    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        responses = [:]
        recorded = []
    }

    /// Registers a JSON (or arbitrary text) response for a path suffix.
    static func stub(path: String, status: Int = 200, json: String) {
        stub(path: path, status: status, data: Data(json.utf8))
    }

    /// Registers a raw-bytes response for a path suffix — used for snapshot image data.
    static func stub(path: String, status: Int = 200, data: Data) {
        lock.lock()
        defer { lock.unlock() }
        responses[path] = Response(status: status, data: data)
    }

    /// Every recorded request whose method, URL, or path contains `fragment`.
    static func requests(matching fragment: String) -> [Recorded] {
        lock.lock()
        defer { lock.unlock() }
        return recorded.filter {
            $0.path.hasSuffix(fragment) || $0.url.contains(fragment) || $0.method == fragment
        }
    }

    // MARK: URLProtocol

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let path = components?.path ?? url.path

        Self.lock.lock()
        Self.recorded.append(
            Recorded(
                method: request.httpMethod ?? "GET",
                url: url.absoluteString,
                path: path,
                query: components?.query,
                body: Self.bodyData(from: request),
                headers: request.allHTTPHeaderFields ?? [:]))
        // Longest matching suffix wins, so "/viewers/vp1" is not shadowed by "/viewers".
        let match =
            Self.responses
            .filter { path.hasSuffix($0.key) }
            .max { $0.key.count < $1.key.count }?
            .value
        Self.lock.unlock()

        let response = match ?? Response(status: 404, data: Data())

        guard
            let httpResponse = HTTPURLResponse(
                url: url, statusCode: response.status, httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"])
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        if !response.data.isEmpty {
            client?.urlProtocol(self, didLoad: response.data)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    /// Reads a request body from either `httpBody` or `httpBodyStream`.
    ///
    /// `URLProtocol` receives the request after `URLSession` has converted `httpBody` into
    /// `httpBodyStream`, so reading `httpBody` alone returns `nil` for every PATCH this
    /// package sends — the trap that makes body assertions look impossible.
    private static func bodyData(from request: URLRequest) -> Data? {
        if let body = request.httpBody, !body.isEmpty { return body }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 1024
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data.isEmpty ? nil : data
    }
}
