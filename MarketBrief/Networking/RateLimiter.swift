//
//  RateLimiter.swift
//  MarketBrief
//
//  Created by Henry Forrest on 30/09/2026.
//

import Foundation

// MARK: - Rate Limiter

/// Sliding-window limiter: at most `maxRequests` in any `timeWindow` seconds,
/// so a fast tapper cannot hammer the backend.
actor RateLimiter {
    private var requestTimestamps: [TimeInterval] = []
    private let maxRequests: Int
    private let timeWindow: TimeInterval
    private let maxTimestampAge: TimeInterval = 3600 // 1 hour safety
    
    init(maxRequests: Int = SecurityConfig.maxRequestsPerMinute, perSeconds: TimeInterval = 60) {
        self.maxRequests = maxRequests
        self.timeWindow = perSeconds
    }
    
    func canMakeRequest() -> Bool {
        let now = Date().timeIntervalSince1970
        
        // Clean up old timestamps - use absolute comparison
        requestTimestamps = requestTimestamps.filter { now - $0 < timeWindow }
        
        // Safety: if timestamps are unreasonably old, clear them
        if let oldest = requestTimestamps.first, now - oldest > maxTimestampAge {
            requestTimestamps.removeAll()
        }
        
        // Check if under limit
        if requestTimestamps.count < maxRequests {
            requestTimestamps.append(now)
            return true
        }
        
        return false
    }
    
    // Force reset when app becomes active
    func resetIfNeeded() {
        let now = Date().timeIntervalSince1970
        
        // If all timestamps are from a previous session, clear them
        if let oldest = requestTimestamps.first, now - oldest > timeWindow * 2 {
            requestTimestamps.removeAll()
        }
    }
}
