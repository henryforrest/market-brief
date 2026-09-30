//
//  Formatters.swift
//  MarketBrief
//
//  Created by Henry Forrest on 30/09/2026.
//

import Foundation

// MARK: - Formatters

/// Display formatting for the metric cards. A missing value renders as
/// "N/A" rather than breaking the layout.
enum Formatters {
    static let missing = "N/A"
    
    /// USD to two decimals, for example "$1,234.50" in a US locale.
    static func currency(_ value: Double?, locale: Locale = .current) -> String {
        guard let value = value else { return missing }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.locale = locale
        return formatter.string(from: NSNumber(value: value)) ?? missing
    }
    
    /// Abbreviated to millions, billions or trillions: "$1.25T", "$2.50B",
    /// "$750.00M". Values under a million are shown in full.
    static func marketCap(_ value: Double?) -> String {
        guard let value = value else { return missing }
        if value >= 1_000_000_000_000 {
            return String(format: "$%.2fT", value / 1_000_000_000_000)
        } else if value >= 1_000_000_000 {
            return String(format: "$%.2fB", value / 1_000_000_000)
        } else if value >= 1_000_000 {
            return String(format: "$%.2fM", value / 1_000_000)
        } else {
            return String(format: "$%.2f", value)
        }
    }
    
    /// A fraction as a percentage to two decimals: 0.1234 becomes "12.34%".
    static func percentage(_ value: Double?) -> String {
        guard let value = value else { return missing }
        return String(format: "%.2f%%", value * 100)
    }
    
    /// A plain ratio to two decimals, used for the P/E and Sharpe ratios.
    static func ratio(_ value: Double?) -> String {
        guard let value = value else { return missing }
        return String(format: "%.2f", value)
    }
}
