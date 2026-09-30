//
//  StockServiceTests.swift
//  MarketBriefTests
//
//  Created by Henry Forrest on 30/09/2026.
//

import Foundation
import Testing
@testable import MarketBrief

// MARK: - Error mapping and request building

struct StockServiceTests {
    @Test(arguments: zip(
        [404, 429, 500, 503, 418],
        [StockError.notFound, .rateLimited, .serverError, .serverError, .invalidResponse]
    ))
    func statusCodeMapsToStockError(code: Int, expected: StockError) {
        #expect(StockService.error(forStatusCode: code) == expected)
    }
    
    @Test func offlineMapsToNetworkUnavailable() {
        #expect(StockService.error(for: URLError(.notConnectedToInternet)) == .networkUnavailable)
    }
    
    @Test func tlsFailuresMapToSecurityValidationFailed() {
        #expect(StockService.error(for: URLError(.secureConnectionFailed)) == .securityValidationFailed)
        #expect(StockService.error(for: URLError(.serverCertificateUntrusted)) == .securityValidationFailed)
    }
    
    @Test func otherTransportErrorsMapToServerError() {
        #expect(StockService.error(for: URLError(.timedOut)) == .serverError)
        #expect(StockService.error(for: URLError(.cannotFindHost)) == .serverError)
    }
    
    @Test func requestTargetsTheStockEndpoint() throws {
        let request = try StockService(baseURL: "https://example.test").makeRequest(for: "AAPL")
        
        #expect(request.url?.absoluteString == "https://example.test/stock/AAPL")
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(request.timeoutInterval == 30)
    }
    
    @Test func sessionWaitsForConnectivityWithTheProductionTimeouts() {
        let configuration = StockService.makeSession().configuration
        
        #expect(configuration.timeoutIntervalForRequest == 30)
        #expect(configuration.timeoutIntervalForResource == 60)
        #expect(configuration.waitsForConnectivity)
    }
}

// MARK: - Fetch path against a stubbed transport

/// Serialised because the stub's canned response is shared state.
@Suite(.serialized)
struct StockServiceFetchTests {
    private static func makeService() -> StockService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return StockService(baseURL: "https://stub.test", session: URLSession(configuration: configuration))
    }
    
    @Test func successfulResponseIsDecoded() async throws {
        StubURLProtocol.respond(status: 200, body: #"{"name": "Apple Inc.", "price": 189.5}"#)
        
        let stock = try await Self.makeService().fetch(ticker: "AAPL")
        
        #expect(stock.name == "Apple Inc.")
        #expect(stock.price == 189.5)
    }
    
    @Test func notFoundStatusThrowsNotFound() async {
        StubURLProtocol.respond(status: 404, body: #"{"detail": "Not Found"}"#)
        
        await #expect(throws: StockError.notFound) {
            try await Self.makeService().fetch(ticker: "ZZZZ")
        }
    }
    
    @Test func serverStatusThrowsServerError() async {
        StubURLProtocol.respond(status: 503, body: "")
        
        await #expect(throws: StockError.serverError) {
            try await Self.makeService().fetch(ticker: "AAPL")
        }
    }
    
    @Test func undecodableBodyThrowsInvalidResponse() async {
        StubURLProtocol.respond(status: 200, body: "<html>not json</html>")
        
        await #expect(throws: StockError.invalidResponse) {
            try await Self.makeService().fetch(ticker: "AAPL")
        }
    }
    
    @Test func transportFailureIsFoldedIntoStockError() async {
        StubURLProtocol.fail(with: URLError(.notConnectedToInternet))
        
        await #expect(throws: StockError.networkUnavailable) {
            try await Self.makeService().fetch(ticker: "AAPL")
        }
    }
}

// MARK: - Stub URL Protocol

/// Answers every request from a canned response, so no test touches the network.
final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) private static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    
    static func respond(status: Int, body: String) {
        handler = { request in
            guard let url = request.url,
                  let response = HTTPURLResponse(
                    url: url,
                    statusCode: status,
                    httpVersion: "HTTP/1.1",
                    headerFields: ["Content-Type": "application/json"]
                  ) else {
                throw URLError(.badURL)
            }
            return (response, Data(body.utf8))
        }
    }
    
    static func fail(with error: Error) {
        handler = { _ in throw error }
    }
    
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    
    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    
    override func stopLoading() { }
}
