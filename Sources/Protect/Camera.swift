//
//  camera.swift
//  camview
//
//  Created by Peter Richardson on 6/30/25.
//

/// Represents a camera in the UniFi Protect system
///
/// This struct contains the basic information about a camera, including its ID, name, state,
/// microphone settings, and video configuration. It conforms to `ProtectFetchable` for
/// automatic API integration.
public struct Camera: ProtectFetchable {
    /// The API endpoint suffix for fetching cameras
    public static let urlSuffix = "cameras"

    /// The unique identifier for the camera
    public var id: String
    /// The current operational state of the camera (e.g., "CONNECTED", "DISCONNECTED")
    public var state: String
    /// The user-assigned name of the camera
    public var name: String
    /// Whether the camera's microphone is enabled
    public var isMicEnabled: Bool
    /// The microphone volume level (0-100)
    public var micVolume: Int
    /// The current video recording mode
    public var videoMode: String
    /// The HDR (High Dynamic Range) type setting
    public var hdrType: String

    // NOT IMPLEMENTED YET
    // osdSettings
    // ledSettings
    // lcdMessage
    // featureFlags
    // smartDetectSettings
    // activePatrolSlot
    // modelKey

    /// CSV header string for exporting camera data
    public static let csvHeader: String = "name,id,state,isMicEnabled,micVolume,videoMode,hdrType"

    /// Human-readable description of the camera
    public var description: String {
        "\(name.padded(to:17)) <\(id)> [\(state)]"
    }

    /// CSV-formatted representation of the camera
    ///
    /// - Returns: A comma-separated string containing all camera properties
    public func csvDescription() -> String {
        "\(name),\(id),\(state),\(isMicEnabled),\(micVolume),\(videoMode),\(hdrType)"
    }
}
