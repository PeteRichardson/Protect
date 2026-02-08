//
//  protocols.swift
//  camview
//
//  Created by Peter Richardson on 6/30/25.
//

import Foundation

public protocol CustomCSVConvertible {
    static var csvHeader: String { get }
    func csvDescription() -> String
}

public protocol ProtectFetchable: Decodable, Comparable, Identifiable, CustomCSVConvertible, CustomStringConvertible {
    static var urlSuffix : String  { get }
    var description : String { get }
    var name: String { get }
    
    static func < (lhs: Self, rhs: Self) -> Bool
    static func == (lhs: Self, rhs: Self) -> Bool
}

public extension ProtectFetchable {
    static func parse(_ data: Data) throws -> [Self] {
        try JSONDecoder().decode([Self].self, from: data)
    }
    
    var description : String {
        return "\(self.name) [\(self.id)]"
    }
    
    static func < (lhs: Self, rhs: Self) -> Bool {
        return lhs.name < rhs.name
    }
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.name == rhs.name
    }
}
