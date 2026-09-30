//
//  RateLimiterTests.swift
//  MarketBriefTests
//
//  Created by Henry Forrest on 30/09/2026.
//

import Foundation
import Testing
@testable import MarketBrief

struct RateLimiterTests {
    @Test func allowsTheLimitThenDeniesUntilTheWindowPasses() async throws {
        let limiter = RateLimiter(maxRequests: 3, perSeconds: 1)
        
        let first = await limiter.canMakeRequest()
        let second = await limiter.canMakeRequest()
        let third = await limiter.canMakeRequest()
        let fourth = await limiter.canMakeRequest()
        
        #expect(first && second && third)
        #expect(!fourth)
        
        try await Task.sleep(for: .milliseconds(1100))
        
        let afterWindow = await limiter.canMakeRequest()
        #expect(afterWindow)
    }
    
    @Test func defaultsToTenRequestsAMinute() async {
        let limiter = RateLimiter()
        var allowed = 0
        
        for _ in 0..<11 {
            if await limiter.canMakeRequest() {
                allowed += 1
            }
        }
        
        #expect(allowed == 10)
    }
}
