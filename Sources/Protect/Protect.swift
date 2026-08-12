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

/// What a request is addressed to.
///
/// Replaces a pair of optional `path`/`url` parameters that permitted two nonsense states —
/// both `nil`, which trapped on a force-unwrap, and both supplied, which silently ignored one.
/// Neither is representable now.
enum Endpoint {
    /// A path relative to ``ProtectService/baseURL``, e.g. `"cameras"`.
    case path(String)
    /// A fully-formed URL, used where a query string has already been built.
    case url(URL)

    /// Resolves to the URL to request.
    func resolve(against baseURL: URL) -> URL {
        switch self {
        case .path(let path): return baseURL.appendingPathComponent(path)
        case .url(let url): return url
        }
    }
}

/// The HTTP methods this package issues.
///
/// Replaces a `method: String?` that defaulted to `nil` and meant GET — a spelling mistake
/// away from a request that silently did the wrong thing.
enum HTTPMethod: String {
    case get = "GET"
    case patch = "PATCH"
    case post = "POST"
}

/// Errors thrown by `ProtectService`.
///
/// Every failure the package originates is one of these cases, so a caller can distinguish
/// them by pattern-matching rather than by reading a status code out of an `NSError` or
/// matching on a localized string. Errors raised by `URLSession` itself — no route to the
/// host, a TLS trust failure, a cancelled task — still surface as `URLError`.
public enum ProtectError: Error, Equatable, LocalizedError {
    /// The host supplied at initialization could not form a valid URL.
    ///
    /// The associated value is the host exactly as the caller supplied it.
    case invalidHost(String)

    /// No camera on the console matched the requested name.
    ///
    /// The associated value is the name that was searched for. Matching is case-insensitive.
    case cameraNotFound(String)

    /// No viewport on the console matched the requested name.
    ///
    /// The associated value is the name that was searched for. Matching is case-insensitive.
    case viewportNotFound(String)

    /// No liveview on the console matched the requested name.
    ///
    /// The associated value is the name that was searched for. Matching is case-insensitive.
    case liveviewNotFound(String)

    /// The console answered with a non-2xx status.
    ///
    /// `body` carries the server's response body, truncated, when it sent one — the Protect
    /// API returns a JSON payload explaining *why* a request failed, and it is usually more
    /// specific than the status code alone. It is `nil` when the response had no body.
    case httpStatus(Int, body: String?)

    /// The response was not an HTTP response at all, so there is no status code to report.
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .invalidHost(let host):
            return """
                '\(host)' is not a valid UniFi Protect host. Supply a hostname or IP address, \
                optionally with a port and nothing else — for example '192.168.1.1', \
                'protect.local', or '10.0.0.1:7443'.
                """
        case .cameraNotFound(let name):
            return "No camera named '\(name)' was found on this console."
        case .viewportNotFound(let name):
            return "No viewport named '\(name)' was found on this console."
        case .liveviewNotFound(let name):
            return "No liveview named '\(name)' was found on this console."
        case .httpStatus(let code, let body):
            let status = HTTPURLResponse.localizedString(forStatusCode: code)
            let base = "The console returned HTTP \(code) (\(status))."
            guard let body else { return base }
            return "\(base) Response: \(body)"
        case .invalidResponse:
            return "The console's reply was not a valid HTTP response."
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

/// Actor for interacting with the UniFi Protect API
///
/// `ProtectService` provides methods to fetch cameras, liveviews, and viewports from a UniFi Protect instance,
/// retrieve camera snapshots, and manage viewport views. It implements caching for improved performance.
///
/// Example usage:
/// ```swift
/// let service = try ProtectService(host: "192.168.1.1", apiKey: "your-api-key")
/// let cameras = try await service.cameras()
/// ```
///
/// ## Concurrency
///
/// An `actor`, so one instance is safely shared across tasks — a Swift 6 client could not do
/// that with the previous non-`Sendable` class. The whole public API was already
/// `async throws`, so ordinary call sites are unchanged, and ``baseURL`` is declared
/// `nonisolated` so it stays synchronously readable. (An actor's immutable `Sendable` `let`
/// is *not* implicitly `nonisolated`; without the annotation, reading `baseURL` would require
/// `await`.)
///
/// Actors are reentrant: two tasks calling ``cameras()`` concurrently on a cold cache can both
/// find it empty and both fetch, and the second result overwrites the first. That is wasteful
/// rather than incorrect — the values are identical, and the cache converges. Collapsing the
/// duplicate fetch would mean storing an in-flight `Task` per resource, which belongs with the
/// cache-invalidation work in #6 rather than here.
public actor ProtectService {
    /// Logger instance for debugging and diagnostics
    nonisolated let logger = Logger(
        subsystem: "com.peterichardson.protect", category: "ProtectService")

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
    /// can carry the delegate that accepts a UniFi console's self-signed certificate — and
    /// because a caller-supplied session is the seam tests stub `URLProtocol` through.
    private let session: URLSession

    /// Whether this service created ``session`` and is therefore responsible for tearing it down.
    ///
    /// A caller-injected session may outlive this service and be shared with other code;
    /// invalidating it in `deinit` would break its owner's next request.
    private let ownsSession: Bool

    /// The path the integration API is served under, appended to the host.
    private static let apiPath = "/proxy/protect/integration/v1"

    /// How long a request may take before it fails, in seconds.
    ///
    /// `URLSession`'s own default is 60s, which is a very long time to stare at a frozen app
    /// because a LAN appliance is switched off or the host is a typo. A console on the same
    /// network answers in well under a second.
    nonisolated let timeout: TimeInterval

    /// The default request timeout: brisk enough to fail fast on a wrong host, long enough for
    /// a busy console to render a full-resolution snapshot.
    public static let defaultTimeout: TimeInterval = 15

    /// The base URL for the Protect API v1 integration endpoint
    ///
    /// Validated and resolved once at initialization, so reading it can neither fail nor trap.
    ///
    /// Explicitly `nonisolated` so it stays synchronously readable now that `ProtectService`
    /// is an `actor`. It is an immutable `let` of a `Sendable` type, so this is safe — but the
    /// compiler does not infer it, and without the annotation every `service.baseURL` becomes
    /// `await service.baseURL`, which would be a gratuitous source break for a property this
    /// package made public only one release ago.
    nonisolated public let baseURL: URL

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
    ///     ``SelfSignedTrustDelegate`` for exactly how far the exception reaches. Ignored when
    ///     `session` is supplied, since that session's own delegate governs trust.
    ///   - session: The session to issue requests through. Defaults to `nil`, meaning the
    ///     service builds its own. Supply one to stub the transport — a configuration with
    ///     `protocolClasses` set is how the test suite exercises this package without a
    ///     network. An injected session is never invalidated by this service.
    ///   - timeout: How long a request may take before failing, in seconds. Defaults to
    ///     ``defaultTimeout`` (15s) rather than `URLSession`'s 60s, which is a long freeze when
    ///     the console is off or the host is wrong.
    /// - Throws: ``ProtectError/invalidHost(_:)`` if `host` cannot form a valid URL.
    public init(
        host: String, apiKey: String, allowsSelfSignedCertificate: Bool = true,
        session: URLSession? = nil, timeout: TimeInterval = ProtectService.defaultTimeout
    ) throws {
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
        self.timeout = timeout
        self.ownsSession = session == nil
        self.session =
            session
            ?? (allowsSelfSignedCertificate
                ? URLSession(
                    configuration: .default,
                    delegate: SelfSignedTrustDelegate(trustedHost: resolvedHost),
                    delegateQueue: nil)
                : URLSession(configuration: .default))
    }

    /// Releases the session, and with it the delegate the session holds.
    ///
    /// A `URLSession` created with a delegate retains that delegate until the session is
    /// invalidated, so letting the service go out of scope without this leaks both. Only a
    /// session this service created is torn down; see ``ownsSession``.
    deinit {
        if ownsSession { session.finishTasksAndInvalidate() }
    }

    /// Retrieves all cameras from the Protect system
    ///
    /// Results are cached after the first call to improve performance.
    ///
    /// - Returns: An array of `Camera` objects
    /// - Throws: An error if the API request fails
    public func cameras() async throws -> [Camera] {
        if let cachedCameras {
            logger.debug("Returning cached result for \(Camera.urlSuffix)")
            return cachedCameras
        }
        let result: [Camera] = try await fetch()
        cachedCameras = result
        return result
    }

    /// Retrieves all liveviews from the Protect system
    ///
    /// Results are cached after the first call to improve performance.
    ///
    /// - Returns: An array of `Liveview` objects
    /// - Throws: An error if the API request fails
    public func liveviews() async throws -> [Liveview] {
        if let cachedLiveviews {
            logger.debug("Returning cached result for \(Liveview.urlSuffix)")
            return cachedLiveviews
        }
        let result: [Liveview] = try await fetch()
        cachedLiveviews = result
        return result
    }

    /// Retrieves all viewports (viewers) from the Protect system
    ///
    /// Results are cached after the first call to improve performance.
    ///
    /// - Returns: An array of `Viewport` objects
    /// - Throws: An error if the API request fails
    public func viewports() async throws -> [Viewport] {
        if let cachedViewports {
            logger.debug("Returning cached result for \(Viewport.urlSuffix)")
            return cachedViewports
        }
        let result: [Viewport] = try await fetch()
        cachedViewports = result
        return result
    }

    /// Retrieves a snapshot image from a camera
    ///
    /// ## On `quality`
    ///
    /// Passing `true` appends `highQuality=true`, which asks the console for a full-HD-or-better
    /// still. **Not every camera supports it, and the ones that don't reject the request rather
    /// than falling back.** Verified against a live console:
    ///
    /// | Camera | `quality: true` |
    /// |---|---|
    /// | 4MP camera (2688×1512 default) | succeeds |
    /// | Doorbell (1920×2560 default) | succeeds, but identical dimensions — already above full HD |
    /// | G6 180 ultra-wide (1280×360 default) | **HTTP 400**, `Camera does not support full HD snapshot` |
    ///
    /// So `quality: true` is not a safe default: on an unsupported camera it throws
    /// ``ProtectError/httpStatus(_:body:)`` with `400` and that message in `body`, and you get
    /// no image at all. A caller that wants a best-effort snapshot should either pass `false`
    /// or catch the 400 and retry without it.
    ///
    /// Passing `false` sends no query parameter at all, so the standard path is exactly the
    /// request this package has always made and cannot regress.
    ///
    /// - Parameters:
    ///   - camera: The name of the camera to get a snapshot from
    ///   - quality: If true, requests a full-HD-or-better snapshot. See the note above — this
    ///     fails outright on cameras that don't support it.
    /// - Returns: The snapshot image data in JPEG format
    /// - Throws: ``ProtectError/cameraNotFound(_:)`` if no camera matches `camera`, or any
    ///   error the underlying request raises.
    public func getSnapshot(from camera: String, with quality: Bool) async throws -> Data {
        logger.debug("Getting snapshot for camera '\(camera, privacy: .public)'")
        guard let cameraId = try await lookupCameraId(byName: camera) else {
            throw ProtectError.cameraNotFound(camera)
        }

        let url = Self.snapshotURL(base: baseURL, cameraId: cameraId, highQuality: quality)
        return try await request(.url(url))
    }

    /// Builds the snapshot endpoint URL for a camera.
    ///
    /// `highQuality=true` is appended only when requested, so a standard-quality call produces
    /// exactly the URL it always has. The parameter name is the one the Protect integration
    /// API defines for `GET /v1/cameras/{id}/snapshot`, confirmed against a live console — an
    /// unsupported camera answers `400 BAD_REQUEST` with `Camera does not support full HD
    /// snapshot`, which is not how a server responds to a query parameter it doesn't know.
    ///
    /// - Parameters:
    ///   - base: The service's ``ProtectService/baseURL``.
    ///   - cameraId: The opaque camera ID, already resolved from a name.
    ///   - highQuality: Whether to ask the console for a full-resolution still.
    /// - Returns: The snapshot URL, with the query appended when `highQuality` is `true`.
    static func snapshotURL(base: URL, cameraId: String, highQuality: Bool) -> URL {
        let url = base.appendingPathComponent("cameras/\(cameraId)/snapshot")
        guard highQuality else { return url }
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        components.queryItems = [URLQueryItem(name: "highQuality", value: "true")]
        return components.url ?? url
    }

    /// Changes the liveview displayed on a viewport
    ///
    /// - Parameters:
    ///   - viewportId: The ID of the viewport to update
    ///   - liveviewId: The ID of the liveview to display on the viewport
    /// - Throws: An error if the API request fails
    /// Changes the liveview displayed on a viewport, addressing both by name
    ///
    /// The name-based counterpart to ``changeViewportView(on:to:)``. Every other public entry
    /// point takes human names — ``getSnapshot(from:with:)`` resolves a camera name
    /// internally — so this overload exists to let a caller stay in one addressing scheme
    /// rather than reaching for the lookup helpers between calls.
    ///
    /// Both names are resolved before any request is sent, so an unknown name fails without
    /// touching the console.
    ///
    /// - Parameters:
    ///   - viewportName: The name of the viewport to update. Matched case-insensitively.
    ///   - liveviewName: The name of the liveview to display. Matched case-insensitively.
    /// - Throws: ``ProtectError/viewportNotFound(_:)`` or ``ProtectError/liveviewNotFound(_:)``
    ///   if either name has no match, or any error the underlying request raises.
    public func changeViewportView(
        onViewportNamed viewportName: String, toLiveviewNamed liveviewName: String
    ) async throws {
        guard let viewportId = try await lookupViewportId(byName: viewportName) else {
            throw ProtectError.viewportNotFound(viewportName)
        }
        guard let liveviewId = try await lookupLiveviewId(byName: liveviewName) else {
            throw ProtectError.liveviewNotFound(liveviewName)
        }
        try await changeViewportView(on: viewportId, to: liveviewId)
    }

    public func changeViewportView(on viewportId: String, to liveviewId: String) async throws {
        let body = ["liveview": liveviewId]
        let requestBody = try JSONEncoder().encode(body)
        _ = try await request(
            .path("viewers/\(viewportId)"), method: .patch, body: requestBody)
    }

    // MARK: - Helper Functions

    /// Fetches and decodes a resource collection from the Protect API.
    ///
    /// Caching lives in the three public accessors rather than here, deliberately. The previous
    /// shape took the cache as `inout` and wrote it after an `await`, which holds an exclusive
    /// access across a suspension point — an exclusivity hazard the compiler names outright
    /// once the type is an `actor`:
    ///
    /// ```
    /// error: actor-isolated property 'cachedCameras' cannot be passed 'inout' to 'async' function call
    /// ```
    ///
    /// Returning the value and letting the caller assign it keeps every mutation of isolated
    /// state on one side of the `await`.
    ///
    /// - Returns: An array of objects conforming to `ProtectFetchable`
    /// - Throws: An error if the API request or parsing fails
    private func fetch<T: ProtectFetchable>() async throws -> [T] {
        logger.debug(
            "Loading \(T.urlSuffix, privacy: .public) data from server.  Should happen only once!")
        let data = try await request(.path(T.urlSuffix), accepting: .json)
        return try T.parse(data)
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
        _ endpoint: Endpoint, headers: [String: String]? = nil,
        method: HTTPMethod = .get, body: Data? = nil, accepting mimetype: MIMEType = .json
    ) async throws -> Data {
        let requestId = "Req " + String(UUID().uuidString.prefix(6))
        let resolvedURL = endpoint.resolve(against: baseURL)
        logger.debug("[\(requestId, privacy: .public)] Preparing: \(resolvedURL, privacy: .public)")

        var request = URLRequest(url: resolvedURL, timeoutInterval: timeout)

        // Caller headers are merged *over* the defaults, never in place of them. The previous
        // `headers ?? defaults` meant supplying any custom header silently dropped X-API-KEY,
        // turning every request into a 401 for a reason nothing in the code named.
        var allHeaders = [
            "X-API-KEY": apiKey,
            "Content-Type": MIMEType.json.rawValue,
            "Accept": mimetype.rawValue,
        ]
        headers?.forEach { allHeaders[$0] = $1 }

        allHeaders.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        // Header names only: the values include X-API-KEY, which must never reach the log.
        logger.trace(
            "[\(requestId, privacy: .public)] Request header keys: \(request.allHTTPHeaderFields?.keys.sorted().joined(separator: ", ") ?? "", privacy: .public)"
        )
        request.httpMethod = method.rawValue
        if let body = body {
            request.httpBody = body
        }

        logger.info(
            "[\(requestId, privacy: .public)] Sending request to \(request.url?.absoluteString ?? "unknown URL", privacy: .public)"
        )

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProtectError.invalidResponse
        }
        logger.debug(
            "[\(requestId, privacy: .public)] Received response: \(httpResponse.statusCode)")

        guard (200...299).contains(httpResponse.statusCode) else {
            // The Protect API explains the failure in the body; the status code alone rarely
            // distinguishes a bad API key from a missing camera.
            throw ProtectError.httpStatus(
                httpResponse.statusCode, body: Self.errorBody(from: data))
        }

        // `.private` because a response body is camera names, IDs, and states — household
        // topology that has no business being persisted to the system-wide log.
        let bodySnippet = String(decoding: data.prefix(Self.loggedBodyLimit), as: UTF8.self)
        logger.debug(
            "[\(requestId, privacy: .public)] Response body (first \(Self.loggedBodyLimit, privacy: .public) chars): \(bodySnippet, privacy: .private)"
        )

        return data
    }

    /// How much of a response body is written to the debug log.
    private static let loggedBodyLimit = 200

    /// How much of an error response body is carried in a thrown ``ProtectError``.
    ///
    /// Larger than ``loggedBodyLimit`` because this one has to survive as a diagnostic — a
    /// truncated JSON error payload is materially less useful than a whole one.
    static let errorBodyLimit = 1024

    /// Renders a response body for inclusion in a thrown error.
    ///
    /// - Parameters:
    ///   - data: The raw response body.
    ///   - limit: Maximum number of bytes to include before truncating.
    /// - Returns: The body as text, truncated and marked as such when it exceeds `limit`, or
    ///   `nil` when the response carried no body worth reporting. `nil` rather than `""` so
    ///   that ``ProtectError/httpStatus(_:body:)`` can omit the section entirely.
    static func errorBody(from data: Data, limit: Int = errorBodyLimit) -> String? {
        guard !data.isEmpty else { return nil }
        let text = String(decoding: data.prefix(limit), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        return data.count > limit ? "\(text)… (truncated)" : text
    }

    /// Looks up a liveview name by its ID
    ///
    /// - Parameter id: The liveview ID to search for
    /// - Returns: The name of the liveview, or nil if not found
    /// - Throws: An error if fetching liveviews fails
    public func lookupLiveviewName(byId id: String) async throws -> String? {
        logger.debug("\tGetting liveview name for \(id, privacy: .public)")
        return try await liveviews().first(where: { $0.id == id })?.name
    }

    /// Looks up a liveview ID by its name (case-insensitive)
    ///
    /// The inverse of ``lookupLiveviewName(byId:)``, and the one direction the package
    /// previously had no way to travel — which is why addressing a viewport change by name
    /// was impossible from outside.
    ///
    /// - Parameter name: The liveview name to search for
    /// - Returns: The ID of the liveview, or nil if not found
    /// - Throws: An error if fetching liveviews fails
    public func lookupLiveviewId(byName name: String) async throws -> String? {
        logger.debug("\tGetting liveview id for \(name, privacy: .public)")
        return try await liveviews().first(where: { $0.name.lowercased() == name.lowercased() })?
            .id
    }

    /// Looks up a camera ID by its name (case-insensitive)
    ///
    /// - Parameter name: The camera name to search for
    /// - Returns: The ID of the camera, or nil if not found
    /// - Throws: An error if fetching cameras fails
    public func lookupCameraId(byName name: String) async throws -> String? {
        logger.debug("\tGetting camera id for \(name, privacy: .public)")
        return try await cameras().first(where: { $0.name.lowercased() == name.lowercased() })?.id
    }

    /// Looks up a viewport ID by its name (case-insensitive)
    ///
    /// - Parameter name: The viewport name to search for
    /// - Returns: The ID of the viewport, or nil if not found
    /// - Throws: An error if fetching viewports fails
    public func lookupViewportId(byName name: String) async throws -> String? {
        logger.debug("\tGetting viewport id for \(name, privacy: .public)")
        return try await viewports().first(where: { $0.name.lowercased() == name.lowercased() })?.id
    }

}
