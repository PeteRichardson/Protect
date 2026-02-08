//
//  liveview.swift
//  camview
//
//  Created by Peter Richardson on 6/30/25.
//

import Foundation

struct Slot: Decodable {
    var cameras: [String]
    var cycleMode: String
    var cycleInterval: Int
}

public struct Liveview: ProtectFetchable {
    
    public static let urlSuffix = "liveviews"
    
    public var id: String
    public var name: String
    var isDefault: Bool
    var isGlobal: Bool
    var owner: String
    var layout: Int
    var slots: [Slot]

    public static let csvHeader : String = "name,id,isDefault,isGlobal,owner,layout"

    public var description: String {
        "\(name.padded(to:17)) <\(id)> \(isDefault ? "(default)" : "")"
    }
    
    public func csvDescription() -> String {
        "\(name),\(id),\(isDefault),\(isGlobal),\(owner),\(layout)"
    }
}


