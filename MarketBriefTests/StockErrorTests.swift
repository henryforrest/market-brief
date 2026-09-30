//
//  StockErrorTests.swift
//  MarketBriefTests
//
//  Created by Henry Forrest on 30/09/2026.
//

import Foundation
import Testing
@testable import MarketBrief

struct StockErrorTests {
    @Test(arguments: StockError.allCases)
    func everyCaseHasUserFacingCopy(error: StockError) throws {
        let description = try #require(error.errorDescription)
        
        #expect(!description.isEmpty)
        // LocalizedError only feeds localizedDescription when errorDescription is
        // non-nil; otherwise the user sees a generic system message.
        #expect(error.localizedDescription == description)
    }
}
