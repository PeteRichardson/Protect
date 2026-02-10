//
//  viewport.swift
//  camview
//
//  Created by Peter Richardson on 6/30/25.
//

/// Represents a viewport (viewer) in the UniFi Protect system
///
/// A viewport is a physical or virtual display that shows a liveview. Viewports can be
/// updated to display different liveviews dynamically.
public struct Viewport: ProtectFetchable {
    /// The API endpoint suffix for fetching viewports
    public static let urlSuffix = "viewers"

    /// The unique identifier for the viewport
    public var id: String
    /// The ID of the liveview currently being displayed
    public var liveview: String
    /// The user-assigned name of the viewport
    public var name: String
    /// The current operational state of the viewport
    public var state: String
    /// The maximum number of simultaneous streams allowed
    public var streamLimit: Int

    /// CSV header string for exporting viewport data
    public static let csvHeader: String = "name,id,liveview,state,streamLimit"

    /// Human-readable description of the viewport
    public var description: String {
        "\(name.padded(to:17)) <\(id)> (viewing '\(liveview)')"
    }

    /// CSV-formatted representation of the viewport
    ///
    /// - Returns: A comma-separated string containing all viewport properties
    public func csvDescription() -> String {
        "\(name),\(id),\(liveview),\(state),\(streamLimit)"
    }
}
