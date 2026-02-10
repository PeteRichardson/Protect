//
//  protect.swift
//  camview
//
//  Created by Peter Richardson on 6/25/25.
//

import AppKit
import Foundation
import OSLog

/// MIME types supported by the Protect API
enum MIMEType: String {
    /// JSON content type
    case json = "application/json"
    /// JPEG image content type
    case jpeg = "application/jpeg"
}

/// Service class for interacting with the UniFi Protect API
///
/// `ProtectService` provides methods to fetch cameras, liveviews, and viewports from a UniFi Protect instance,
/// retrieve camera snapshots, and manage viewport views. It implements caching for improved performance.
///
/// Example usage:
/// ```swift
/// let service = ProtectService(host: "192.168.1.1", apiKey: "your-api-key")
/// let cameras = try await service.cameras()
/// ```
public class ProtectService {
    /// Logger instance for debugging and diagnostics
    let logger = Logger(subsystem: "com.peterichardson.protect", category: "ProtectService")

    /// Cache for camera data to avoid redundant API calls
    private var cachedCameras: [Camera]? = nil
    /// Cache for liveview data to avoid redundant API calls
    private var cachedLiveviews: [Liveview]? = nil
    /// Cache for viewport data to avoid redundant API calls
    private var cachedViewports: [Viewport]? = nil

    /// The hostname or IP address of the UniFi Protect controller
    private let host: String
    /// The API key for authentication with the Protect API
    private let apiKey: String

    /// Additional HTTP headers for API requests
    private var headers: [String: String] = [:]

    /// The base URL for the Protect API v1 integration endpoint
    var base_url: URL {
        URL(string: "http://\(host)/proxy/protect/integration/v1")!
    }

    /// Initializes a new ProtectService instance
    ///
    /// - Parameters:
    ///   - host: The hostname or IP address of the UniFi Protect controller
    ///   - apiKey: The API key for authentication
    public init(host: String, apiKey: String) {
        self.host = host
        self.apiKey = apiKey
    }

    /// Retrieves all cameras from the Protect system
    ///
    /// Results are cached after the first call to improve performance.
    ///
    /// - Returns: An array of `Camera` objects
    /// - Throws: An error if the API request fails
    public func cameras() async throws -> [Camera] {
        try await fetchAndCache(cache: &cachedCameras)
    }

    /// Retrieves all liveviews from the Protect system
    ///
    /// Results are cached after the first call to improve performance.
    ///
    /// - Returns: An array of `Liveview` objects
    /// - Throws: An error if the API request fails
    public func liveviews() async throws -> [Liveview] {
        try await fetchAndCache(cache: &cachedLiveviews)
    }

    /// Retrieves all viewports (viewers) from the Protect system
    ///
    /// Results are cached after the first call to improve performance.
    ///
    /// - Returns: An array of `Viewport` objects
    /// - Throws: An error if the API request fails
    public func viewports() async throws -> [Viewport] {
        try await fetchAndCache(cache: &cachedViewports)
    }

    /// Retrieves a snapshot image from a camera
    ///
    /// - Parameters:
    ///   - camera: The name of the camera to get a snapshot from
    ///   - quality: If true, requests a high-quality snapshot
    /// - Returns: The snapshot image data in JPEG format
    /// - Throws: An error if the camera is not found or the API request fails
    public func getSnapshot(from camera: String, with quality: Bool) async throws -> Data {
        logger.debug("Getting snapshot for camera '\(camera, privacy: .public)'")
        guard let cameraId = try await lookupCameraId(byName: camera) else {
            throw NSError(
                domain: "ProtectService", code: 1001,
                userInfo: [
                    NSLocalizedDescriptionKey: "Camera '\(camera)' not found"
                ])
        }

        let url = base_url.appendingPathComponent("/cameras/\(cameraId)/snapshot")
        return try await request(url: url)
    }

    /// Changes the liveview displayed on a viewport
    ///
    /// - Parameters:
    ///   - viewportId: The ID of the viewport to update
    ///   - liveviewId: The ID of the liveview to display on the viewport
    /// - Throws: An error if the API request fails
    public func changeViewportView(on viewportId: String, to liveviewId: String) async throws {
        let body = ["liveview": liveviewId]
        let requestBody = try JSONEncoder().encode(body)
        _ = try await request(path: "/viewers/\(viewportId)", method: "PATCH", body: requestBody)
    }

    // MARK: - Helper Functions

    /// Generic method to fetch and cache data from the Protect API
    ///
    /// This method implements a simple caching strategy: if data exists in the cache,
    /// it returns the cached data; otherwise, it fetches from the API and caches the result.
    ///
    /// - Parameter cache: An inout reference to the cache variable
    /// - Returns: An array of objects conforming to `ProtectFetchable`
    /// - Throws: An error if the API request or parsing fails
    private func fetchAndCache<T: ProtectFetchable>(cache: inout [T]?) async throws -> [T] {
        if let cached = cache {
            logger.debug("Returning cached result for \(T.urlSuffix)")
            return cached
        }
        logger.debug(
            "Loading \(T.urlSuffix, privacy: .public) data from server.  Should happen only once!")
        let data = try await request(path: T.urlSuffix, accepting: .json)
        let result = try T.parse(data)
        cache = result
        return result
    }

    /// Makes an HTTP request to the Protect API
    ///
    /// - Parameters:
    ///   - path: The API path relative to the base URL (optional if url is provided)
    ///   - url: The full URL to request (optional if path is provided)
    ///   - headers: Additional HTTP headers to include in the request
    ///   - method: The HTTP method (GET, POST, PATCH, etc.). Defaults to GET if not specified
    ///   - body: The request body data for POST/PATCH requests
    ///   - mimetype: The expected MIME type for the Accept header. Defaults to JSON
    /// - Returns: The response data from the API
    /// - Throws: An error if the request fails or returns a non-2xx status code
    func request(
        path: String? = nil, url: URL? = nil, headers: [String: String]? = nil,
        method: String? = nil, body: Data? = nil, accepting mimetype: MIMEType? = .json
    ) async throws -> Data {
        let requestId = "Req " + String(UUID().uuidString.prefix(6))
        let resolvedURL = url ?? (path.map { base_url.appendingPathComponent($0) })!
        logger.debug("[\(requestId, privacy: .public)] Preparing: \(resolvedURL, privacy: .public)")

        var request = URLRequest(url: resolvedURL)
        let allHeaders =
            headers ?? [
                "X-API-KEY": apiKey,
                "Content-Type": "application/json",
                "Accept": mimetype?.rawValue ?? "application/json",
            ]

        allHeaders.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        logger.trace(
            "[\(requestId, privacy: .public)] Request headers: \(request.allHTTPHeaderFields ?? [:], privacy: .public)"
        )
        if let method = method {
            request.httpMethod = method
        }
        if let body = body {
            request.httpBody = body
        }

        logger.info(
            "[\(requestId, privacy: .public)] Sending request to \(request.url?.absoluteString ?? "unknown URL", privacy: .public)"
        )

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        logger.debug(
            "[\(requestId, privacy: .public)] Received response: \(httpResponse.statusCode)")

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NSError(
                domain: "ProtectService",
                code: httpResponse.statusCode,
                userInfo: [
                    NSLocalizedDescriptionKey: HTTPURLResponse.localizedString(
                        forStatusCode: httpResponse.statusCode)
                ]
            )
        }

        let bodySnippet = String(decoding: data.prefix(200), as: UTF8.self)
        logger.debug(
            "[\(requestId, privacy: .public)] Response body (first 200 chars): \(bodySnippet, privacy: .public)"
        )

        return data
    }

    /// Looks up a liveview name by its ID
    ///
    /// - Parameter id: The liveview ID to search for
    /// - Returns: The name of the liveview, or nil if not found
    /// - Throws: An error if fetching liveviews fails
    func lookupLiveviewName(byId id: String) async throws -> String? {
        logger.debug("\tGetting liveview name for \(id, privacy: .public)")
        return try await liveviews().first(where: { $0.id == id })?.name
    }

    /// Looks up a camera ID by its name (case-insensitive)
    ///
    /// - Parameter name: The camera name to search for
    /// - Returns: The ID of the camera, or nil if not found
    /// - Throws: An error if fetching cameras fails
    func lookupCameraId(byName name: String) async throws -> String? {
        logger.debug("\tGetting camera id for \(name, privacy: .public)")
        return try await cameras().first(where: { $0.name.lowercased() == name.lowercased() })?.id
    }

    /// Looks up a viewport ID by its name (case-insensitive)
    ///
    /// - Parameter name: The viewport name to search for
    /// - Returns: The ID of the viewport, or nil if not found
    /// - Throws: An error if fetching viewports fails
    func lookupViewportId(byName name: String) async throws -> String? {
        logger.debug("\tGetting viewport id for \(name, privacy: .public)")
        return try await viewports().first(where: { $0.name.lowercased() == name.lowercased() })?.id
    }

}
