//
//  CSVParser.swift
//  Clementime
//
//  CSV parsing utility that properly handles quoted fields
//

import Foundation

struct CSVParser {
    /// Parses a CSV line respecting quoted fields and escaped quotes
    /// - Parameter line: A single CSV line
    /// - Returns: Array of field values with quotes and escapes handled
    static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var insideQuotes = false
        var previousChar: Character? = nil

        for char in line {
            if char == "\"" {
                if insideQuotes && previousChar == "\"" {
                    // Escaped quote (two consecutive quotes)
                    currentField.append(char)
                    previousChar = nil // Reset to avoid counting this as previous quote
                    continue
                } else {
                    // Toggle quote state
                    insideQuotes.toggle()
                }
            } else if char == "," && !insideQuotes {
                // Field separator outside quotes
                fields.append(currentField.trimmingCharacters(in: .whitespaces))
                currentField = ""
            } else {
                currentField.append(char)
            }
            previousChar = char
        }

        // Add the last field
        fields.append(currentField.trimmingCharacters(in: .whitespaces))

        return fields
    }

    /// Parses an entire CSV string into rows and fields
    /// - Parameter csvData: The full CSV file content as a string
    /// - Returns: Array of rows, where each row is an array of field values
    static func parseCSV(_ csvData: String) -> [[String]] {
        let lines = csvData.components(separatedBy: .newlines).filter { !$0.isEmpty }
        return lines.map { parseCSVLine($0) }
    }
}
