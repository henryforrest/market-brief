//
//  StockService.swift
//  MarketBrief
//
//  Created by Henry Forrest on 30/09/2026.
//

import Foundation

// MARK: - Security Configuration
struct SecurityConfig {
    // IMPORTANT: Always use the same URL for all builds
    static let baseURL = "https://marketbrief-back-end.fly.dev"
    
    // Rate limiting
    static let maxRequestsPerMinute = 10
    static let requestCooldownSeconds = 6
}

// MARK: - Stock Service

/// Fetches `GET {baseURL}/stock/{TICKER}` and maps every failure, whether an
/// HTTP status, a transport error or an undecodable body, to a `StockError`,
/// so the view deals with a single error type.
struct StockService: Sendable {
    private let baseURL: String
    private let session: URLSession
    
    init(baseURL: String = SecurityConfig.baseURL, session: URLSession = StockService.makeSession()) {
        self.baseURL = baseURL
        self.session = session
    }
    
    /// A session relying on the system trust store for TLS validation.
    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }
    
    /// Builds the request for a ticker that has already passed validation.
    func makeRequest(for ticker: String) throws -> URLRequest {
        guard let encodedTicker = ticker.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(baseURL)/stock/\(encodedTicker)") else {
            throw StockError.invalidTicker
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30
        return request
    }
    
    /// Fetches and decodes the stock. The only error type thrown is `StockError`.
    func fetch(ticker: String) async throws -> StockResponse {
        let request = try makeRequest(for: ticker)
        
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            throw Self.error(for: urlError)
        } catch {
            throw StockError.serverError
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw StockError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw Self.error(forStatusCode: httpResponse.statusCode)
        }
        
        do {
            return try JSONDecoder().decode(StockResponse.self, from: data)
        } catch {
            #if DEBUG
            print("StockService: could not decode the response for \(ticker): \(error)")
            #endif
            throw StockError.invalidResponse
        }
    }
    
    // MARK: - Error Mapping
    
    /// Maps a non-200 status code to the error shown to the user.
    static func error(forStatusCode statusCode: Int) -> StockError {
        switch statusCode {
        case 404:
            return .notFound
        case 429:
            return .rateLimited
        case 500...599:
            return .serverError
        default:
            return .invalidResponse
        }
    }
    
    /// Folds transport-level failures into the same error type.
    static func error(for urlError: URLError) -> StockError {
        switch urlError.code {
        case .notConnectedToInternet:
            return .networkUnavailable
        case .secureConnectionFailed, .serverCertificateUntrusted:
            return .securityValidationFailed
        default:
            return .serverError
        }
    }
}
