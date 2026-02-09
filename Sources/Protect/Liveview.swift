//
//  liveview.swift
//  camview
//
//  Created by Peter Richardson on 6/30/25.
//

import Foundation

public struct Slot: Decodable {
    public var cameras: [String]
    public var cycleMode: String
    public var cycleInterval: Int
}

public struct Liveview: ProtectFetchable {

    public static let urlSuffix = "liveviews"

    public var id: String
    public var name: String
    public var isDefault: Bool
    public var isGlobal: Bool
    public var owner: String
    public var layout: Int
    public var slots: [Slot]

    public static let csvHeader: String = "name,id,isDefault,isGlobal,owner,layout"

    public var description: String {
        "\(name.padded(to:17)) <\(id)> \(isDefault ? "(default)" : "")"
    }

    public func csvDescription() -> String {
        "\(name),\(id),\(isDefault),\(isGlobal),\(owner),\(layout)"
    }
}
