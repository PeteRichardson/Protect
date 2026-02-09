//
//  viewport.swift
//  camview
//
//  Created by Peter Richardson on 6/30/25.
//

public struct Viewport: ProtectFetchable {
    //static let v1APIPath = "viewers"
    public static let urlSuffix = "viewers"

    public var id: String
    public var liveview: String
    public var name: String
    public var state: String
    public var streamLimit: Int

    public static let csvHeader: String = "name,id,liveview,state,streamLimit"

    public var description: String {
        "\(name.padded(to:17)) <\(id)> (viewing '\(liveview)')"
    }
    public func csvDescription() -> String {
        "\(name),\(id),\(liveview),\(state),\(streamLimit)"
    }
}
