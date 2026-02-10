//
//  extensions.swift
//  camview
//
//  Created by Peter Richardson on 6/29/25.
//

import Foundation

extension String {
    /// Pads the string with spaces to reach the specified length
    ///
    /// - Parameter length: The desired total length of the string
    /// - Returns: A new string padded with spaces on the right to reach the specified length
    func padded(to length: Int) -> String {
        return self.padding(toLength: length, withPad: " ", startingAt: 0)
    }
}

extension Array {
    /// Asynchronously maps each element of the array using the provided transform function
    ///
    /// This method processes elements sequentially, awaiting each transformation before
    /// moving to the next element.
    ///
    /// - Parameter transform: An async closure that transforms each element
    /// - Returns: An array containing the transformed elements
    /// - Throws: Rethrows any errors thrown by the transform closure
    func asyncMap<T>(
        _ transform: @escaping (Element) async throws -> T
    ) async rethrows -> [T] {
        var results = [T]()
        for element in self {
            results.append(try await transform(element))
        }
        return results
    }
}

