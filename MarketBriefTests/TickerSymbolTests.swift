//
//  TickerSymbolTests.swift
//  MarketBriefTests
//
//  Created by Henry Forrest on 30/09/2026.
//

import Testing
@testable import MarketBrief

struct TickerSymbolTests {
    @Test(arguments: ["A", "VOO", "AAPL", "GOOGL"])
    func acceptsOneToFiveLetters(symbol: String) {
        #expect(TickerSymbol.isValid(symbol))
    }
    
    @Test(arguments: ["", "   ", "ABCDEF", "AA1", "BRK.B", "AA PL"])
    func rejectsAnythingElse(symbol: String) {
        #expect(!TickerSymbol.isValid(symbol))
    }
    
    @Test func ignoresSurroundingWhitespace() {
        #expect(TickerSymbol.isValid(" VOO\n"))
    }
    
    @Test func sanitisingUpperCasesAndDropsNonLetters() {
        #expect(TickerSymbol.sanitised("brk.b") == "BRKB")
        #expect(TickerSymbol.sanitised("aa 1pl") == "AAPL")
        #expect(TickerSymbol.sanitised("123") == "")
    }
}
