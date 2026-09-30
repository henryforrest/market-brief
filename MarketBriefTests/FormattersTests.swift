//
//  FormattersTests.swift
//  MarketBriefTests
//
//  Created by Henry Forrest on 30/09/2026.
//

import Foundation
import Testing
@testable import MarketBrief

struct FormattersTests {
    @Test func marketCapAbbreviatesAtEachThreshold() {
        #expect(Formatters.marketCap(1_250_000_000_000) == "$1.25T")
        #expect(Formatters.marketCap(1_000_000_000_000) == "$1.00T")
        #expect(Formatters.marketCap(2_500_000_000) == "$2.50B")
        #expect(Formatters.marketCap(750_000_000) == "$750.00M")
        #expect(Formatters.marketCap(1_500_000) == "$1.50M")
        #expect(Formatters.marketCap(999_999) == "$999999.00")
        #expect(Formatters.marketCap(nil) == "N/A")
    }
    
    @Test func percentageScalesAFractionToTwoDecimals() {
        #expect(Formatters.percentage(0.1234) == "12.34%")
        #expect(Formatters.percentage(-0.125) == "-12.50%")
        #expect(Formatters.percentage(0) == "0.00%")
        #expect(Formatters.percentage(nil) == "N/A")
    }
    
    @Test func ratioRoundsToTwoDecimals() {
        #expect(Formatters.ratio(29.4) == "29.40")
        #expect(Formatters.ratio(0.756) == "0.76")
        #expect(Formatters.ratio(nil) == "N/A")
    }
    
    @Test func currencyIsUSDToTwoDecimalsInTheGivenLocale() {
        let us = Locale(identifier: "en_US")
        
        #expect(Formatters.currency(1234.5, locale: us) == "$1,234.50")
        #expect(Formatters.currency(189.456, locale: us) == "$189.46")
        #expect(Formatters.currency(nil, locale: us) == "N/A")
    }
}
