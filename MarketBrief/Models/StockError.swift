//
//  StockError.swift
//  MarketBrief
//
//  Created by Henry Forrest on 30/09/2026.
//

import Foundation

// MARK: - Stock Error

/// Every way a lookup can fail, each with the message shown to the user.
enum StockError: LocalizedError {
    case invalidTicker
    case networkUnavailable
    case notFound
    case rateLimited
    case serverError
    case securityValidationFailed
    case invalidResponse
    
    var errorDescription: String {
        switch self {
        case .invalidTicker:
            return "Please enter a valid stock ticker (1-5 letters)"
        case .networkUnavailable:
            return "No internet connection. Please check your network."
        case .notFound:
            return "Stock not found. Please check the ticker symbol."
        case .rateLimited:
            return "Too many requests. Please wait a few seconds."
        case .serverError:
            return "Server error. Please try again later."
        case .securityValidationFailed:
            return "⚠️ Secure connection could not be established"
        case .invalidResponse:
            return "Unable to parse stock data"
        }
    }
}
