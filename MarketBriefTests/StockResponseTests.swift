//
//  StockResponseTests.swift
//  MarketBriefTests
//
//  Created by Henry Forrest on 30/09/2026.
//

import Foundation
import Testing
@testable import MarketBrief

struct StockResponseTests {
    private func decode(_ json: String) throws -> StockResponse {
        try JSONDecoder().decode(StockResponse.self, from: Data(json.utf8))
    }
    
    @Test func fullPayloadDecodesEveryField() throws {
        let stock = try decode("""
        {
            "name": "Apple Inc.",
            "sector": "Technology",
            "summary": { "sector": "Technology", "industry": "Consumer Electronics" },
            "ai_summary": "A steady compounder with a large buyback programme.",
            "price": 189.5,
            "market_cap": 2950000000000,
            "pe_ratio": 29.4,
            "annualized_return": 0.21,
            "volatility": 0.28,
            "sharpe_ratio": 0.75,
            "max_drawdown": -0.31
        }
        """)
        
        #expect(stock.name == "Apple Inc.")
        #expect(stock.sector == "Technology")
        #expect(stock.summary?.sector == "Technology")
        #expect(stock.summary?.industry == "Consumer Electronics")
        #expect(stock.ai_summary == "A steady compounder with a large buyback programme.")
        #expect(stock.price == 189.5)
        #expect(stock.market_cap == 2_950_000_000_000)
        #expect(stock.pe_ratio == 29.4)
        #expect(stock.annualized_return == 0.21)
        #expect(stock.volatility == 0.28)
        #expect(stock.sharpe_ratio == 0.75)
        #expect(stock.max_drawdown == -0.31)
    }
    
    @Test func partialPayloadLeavesMissingFieldsNil() throws {
        // An ETF, say, comes back without a market cap or a P/E ratio.
        let stock = try decode("""
        {
            "name": "Vanguard S&P 500 ETF",
            "price": 512.3,
            "annualized_return": 0.12,
            "volatility": 0.17,
            "sharpe_ratio": 0.6,
            "max_drawdown": -0.24
        }
        """)
        
        #expect(stock.name == "Vanguard S&P 500 ETF")
        #expect(stock.price == 512.3)
        #expect(stock.market_cap == nil)
        #expect(stock.pe_ratio == nil)
        #expect(stock.summary == nil)
        #expect(stock.ai_summary == nil)
    }
    
    @Test func emptyObjectDecodes() throws {
        let stock = try decode("{}")
        
        #expect(stock.name == nil)
        #expect(stock.sector == nil)
        #expect(stock.summary == nil)
        #expect(stock.ai_summary == nil)
        #expect(stock.price == nil)
        #expect(stock.market_cap == nil)
        #expect(stock.pe_ratio == nil)
        #expect(stock.annualized_return == nil)
        #expect(stock.volatility == nil)
        #expect(stock.sharpe_ratio == nil)
        #expect(stock.max_drawdown == nil)
    }
}
