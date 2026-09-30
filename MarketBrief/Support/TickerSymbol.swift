//
//  TickerSymbol.swift
//  MarketBrief
//
//  Created by Henry Forrest on 30/09/2026.
//

import Foundation

// MARK: - Ticker Symbol

/// The rules for the symbol typed into the search field.
enum TickerSymbol {
    /// The longest symbol the backend accepts.
    static let maxLength = 5
    
    /// Upper-cases the input and drops anything that is not a letter.
    /// Applied as the user types.
    static func sanitised(_ input: String) -> String {
        input.uppercased().filter { $0.isLetter }
    }
    
    /// One to five letters, ignoring surrounding whitespace.
    static func isValid(_ input: String) -> Bool {
        let cleaned = input.trimmingCharacters(in: .whitespacesAndNewlines)
        return !cleaned.isEmpty &&
               cleaned.count <= maxLength &&
               cleaned.allSatisfy({ $0.isLetter })
    }
}
