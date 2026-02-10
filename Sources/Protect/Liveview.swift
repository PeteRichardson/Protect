//
//  liveview.swift
//  camview
//
//  Created by Peter Richardson on 6/30/25.
//

import Foundation

/// Represents a slot in a liveview layout
///
/// Each slot can display one or more cameras and defines how they cycle through views.
public struct Slot: Decodable {
    /// Array of camera IDs to display in this slot
    public var cameras: [String]
    /// The mode for cycling through cameras (e.g., "default", "timelapse")
    public var cycleMode: String
    /// The interval in seconds between camera cycles
    public var cycleInterval: Int
}

/// Represents a liveview in the UniFi Protect system
///
/// A liveview is a pre-configured layout that displays one or more cameras in a grid.
/// Each slot in the layout can show multiple cameras that cycle through at specified intervals.
public struct Liveview: ProtectFetchable {

    /// The API endpoint suffix for fetching liveviews
    public static let urlSuffix = "liveviews"

    /// The unique identifier for the liveview
    public var id: String
    /// The user-assigned name of the liveview
    public var name: String
    /// Whether this is the default liveview
    public var isDefault: Bool
    /// Whether this liveview is available globally to all users
    public var isGlobal: Bool
    /// The user ID of the liveview owner
    public var owner: String
    /// The layout type (number indicating grid configuration)
    public var layout: Int
    /// Array of slots that make up the liveview layout
    public var slots: [Slot]

    /// CSV header string for exporting liveview data
    public static let csvHeader: String = "name,id,isDefault,isGlobal,owner,layout"

    /// Human-readable description of the liveview
    public var description: String {
        "\(name.padded(to:17)) <\(id)> \(isDefault ? "(default)" : "")"
    }

    /// CSV-formatted representation of the liveview
    ///
    /// - Returns: A comma-separated string containing basic liveview properties
    public func csvDescription() -> String {
        "\(name),\(id),\(isDefault),\(isGlobal),\(owner),\(layout)"
    }
}
