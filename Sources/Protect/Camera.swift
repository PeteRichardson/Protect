//
//  camera.swift
//  camview
//
//  Created by Peter Richardson on 6/30/25.
//

public struct Camera: ProtectFetchable {
    //static let v1APIPath = "cameras"
    public static let urlSuffix = "cameras"

    public var id: String
    public var state: String
    public var name: String
    public var isMicEnabled: Bool
    public var micVolume: Int
    public var videoMode: String
    public var hdrType: String

    // NOT IMPLEMENTED YET
    // osdSettings
    // ledSettings
    // lcdMessage
    // featureFlags
    // smartDetectSettings
    // activePatrolSlot
    // modelKey

    public static let csvHeader: String = "name,id,state,isMicEnabled,micVolume,videoMode,hdrType"

    public var description: String {
        "\(name.padded(to:17)) <\(id)> [\(state)]"
    }

    public func csvDescription() -> String {
        "\(name),\(id),\(state),\(isMicEnabled),\(micVolume),\(videoMode),\(hdrType)"
    }
}
