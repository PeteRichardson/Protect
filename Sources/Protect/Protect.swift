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

/// Errors thrown by `ProtectService`.
public enum ProtectError: Error, Equatable, LocalizedError {
    /// The host supplied at initialization could not form a valid URL.
    ///
    /// The associated value is the host exactly as the caller supplied it.
    case invalidHost(String)

    public var errorDescription: String? {
        switch self {
        case .invalidHost(let host):
            return """
                '\(host)' is not a valid UniFi Protect host. Supply a hostname or IP address, \
                optionally with a port and nothing else — for example '192.168.1.1', \
                'protect.local', or '10.0.0.1:7443'.
                """
        }
    }
}

/// Accepts the self-signed certificate a UniFi console presents, for one host only.
///
/// UniFi consoles serve the integration API over HTTPS with a self-signed certificate, and a
/// publicly-trusted certificate cannot be issued for a private IP address at all. Default TLS
/// evaluation therefore rejects every request to a console on a LAN. This delegate narrows the
/// exception as far as it can go while still connecting: any host other than the one the
/// service was initialized with falls through to default handling, as does any challenge that
/// isn't a server-trust challenge.
///
/// This trusts *whatever* certificate the configured host presents, so it does not defend
/// against an attacker who can already redirect traffic for that host. What it does buy over
/// plain HTTP is encryption of the `X-API-KEY` header in transit against a passive observer on
/// the network.
final class SelfSignedTrustDelegate: NSObject, URLSessionDelegate {
    /// The only host for which the certificate check is relaxed.
    private let trustedHost: String

    init(trustedHost: String) {
        self.trustedHost = trustedHost
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @Sendable (
            URLSession.AuthChallengeDisposition, URLCredential?
        ) -> Void
    ) {
        guard
            challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
            challenge.protectionSpace.host == trustedHost,
            let serverTrust = challenge.protectionSpace.serverTrust
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: serverTrust))
    }
}

/// Service class for interacting with the UniFi Protect API
///
/// `ProtectService` provides methods to fetch cameras, liveviews, and viewports from a UniFi Protect instance,
/// retrieve camera snapshots, and manage viewport views. It implements caching for improved performance.
///
/// Example usage:
/// ```swift
/// let service = try ProtectService(host: "192.168.1.1", apiKey: "your-api-key")
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

    /// The API key for authentication with the Protect API
    private let apiKey: String

    /// Additional HTTP headers for API requests
    private var headers: [String: String] = [:]

    /// The session all requests go through.
    ///
    /// An instance session rather than `URLSession.shared`, because only an instance session
    /// can carry the delegate that accepts a UniFi console's self-signed certificate.
    private let session: URLSession

    /// The path the integration API is served under, appended to the host.
    private static let apiPath = "/proxy/protect/integration/v1"

    /// The base URL for the Protect API v1 integration endpoint
    ///
    /// Validated and resolved once at initialization, so reading it can neither fail nor trap.
    public let baseURL: URL

    /// Initializes a new ProtectService instance
    ///
    /// - Parameters:
    ///   - host: The hostname or IP address of the UniFi Protect controller, optionally with a
    ///     port (`10.0.0.1:7443`). Supply the host alone — a scheme, path, or query makes it
    ///     invalid.
    ///   - apiKey: The API key for authentication
    ///   - allowsSelfSignedCertificate: Whether to accept the self-signed certificate served by
    ///     the console at `host`. Defaults to `true`, which is what a UniFi console on a LAN
    ///     requires; pass `false` to demand a fully-trusted certificate chain. See
    ///     ``SelfSignedTrustDelegate`` for exactly how far the exception reaches.
    /// - Throws: ``ProtectError/invalidHost(_:)`` if `host` cannot form a valid URL.
    public init(host: String, apiKey: String, allowsSelfSignedCertificate: Bool = true) throws {
        guard let components = URLComponents(string: "https://\(host)\(Self.apiPath)"),
            let resolvedHost = components.host, !resolvedHost.isEmpty,
            components.path == Self.apiPath,
            components.query == nil, components.fragment == nil, components.user == nil,
            let url = components.url
        else {
            throw ProtectError.invalidHost(host)
        }

        self.apiKey = apiKey
        self.baseURL = url
        self.session =
            allowsSelfSignedCertificate
            ? URLSession(
                configuration: .default,
                delegate: SelfSignedTrustDelegate(trustedHost: resolvedHost),
                delegateQueue: nil)
            : URLSession(configuration: .default)
    }

    /// Releases the session, and with it the delegate the session holds.
    ///
    /// A `URLSession` created with a delegate retains that delegate until the session is
    /// invalidated, so letting the service go out of scope without this leaks both.
    deinit {
        session.finishTasksAndInvalidate()
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

        let url = baseURL.appendingPathComponent("/cameras/\(cameraId)/snapshot")
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
        let resolvedURL = url ?? (path.map { baseURL.appendingPathComponent($0) })!
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
        // Header names only: the values include X-API-KEY, which must never reach the log.
        logger.trace(
            "[\(requestId, privacy: .public)] Request header keys: \(request.allHTTPHeaderFields?.keys.sorted().joined(separator: ", ") ?? "", privacy: .public)"
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

        let (data, response) = try await session.data(for: request)

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
