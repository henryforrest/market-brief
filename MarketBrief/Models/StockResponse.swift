//
//  StockResponse.swift
//  MarketBrief
//
//  Created by Henry Forrest on 26/01/2026.
//

struct StockResponse: Decodable {
    let name: String?
    let sector: String?
    let summary: Summary?
    let ai_summary: String?
    let price: Double?
    let market_cap: Double?
    let pe_ratio: Double?
    let annualized_return: Double?
    let volatility: Double?
    let sharpe_ratio: Double?
    let max_drawdown: Double?
    
    // Add coding keys to handle snake_case properly
    enum CodingKeys: String, CodingKey {
        case name
        case sector
        case summary
        case ai_summary
        case price
        case market_cap
        case pe_ratio
        case annualized_return
        case volatility
        case sharpe_ratio
        case max_drawdown
    }
}

struct Summary: Decodable {
    let sector: String?
    let industry: String?
}
