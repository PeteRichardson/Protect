//
//  protocols.swift
//  camview
//
//  Created by Peter Richardson on 6/30/25.
//

import Foundation

/// Protocol for types that can be converted to CSV format
public protocol CustomCSVConvertible {
    /// The CSV header row containing column names
    static var csvHeader: String { get }

    /// Converts the instance to a CSV-formatted string
    ///
    /// - Returns: A comma-separated string representation of the instance
    func csvDescription() -> String
}

/// Protocol for types that can be fetched from the Protect API
///
/// Conforming types automatically gain JSON parsing, comparison, and CSV export capabilities.
/// This protocol combines `Decodable` for JSON parsing, `Comparable` for sorting,
/// `Identifiable` for uniqueness, and custom protocols for CSV export and string descriptions.
public protocol ProtectFetchable: Decodable, Comparable, Identifiable, CustomCSVConvertible,
    CustomStringConvertible
{
    /// The API endpoint suffix for fetching this resource type
    static var urlSuffix: String { get }

    /// A human-readable description of the instance
    var description: String { get }

    /// The name of the instance
    var name: String { get }

    /// Compares two instances by name
    static func < (lhs: Self, rhs: Self) -> Bool

    /// Checks if two instances are equal by name
    static func == (lhs: Self, rhs: Self) -> Bool
}

public extension ProtectFetchable {
    /// Parses JSON data into an array of instances
    ///
    /// - Parameter data: The JSON data to parse
    /// - Returns: An array of decoded instances
    /// - Throws: A decoding error if the JSON is invalid or doesn't match the expected structure
    static func parse(_ data: Data) throws -> [Self] {
        try JSONDecoder().decode([Self].self, from: data)
    }

    /// Default implementation of description that shows name and ID
    var description: String {
        return "\(self.name) [\(self.id)]"
    }

    /// Default comparison based on name (lexicographic ordering)
    static func < (lhs: Self, rhs: Self) -> Bool {
        return lhs.name < rhs.name
    }

    /// Default equality check based on name
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.name == rhs.name
    }
}
