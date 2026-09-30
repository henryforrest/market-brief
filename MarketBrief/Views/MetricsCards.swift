//
//  MetricsCards.swift
//  MarketBrief
//
//  Created by Henry Forrest on 30/09/2026.
//

import SwiftUI

// MARK: - Stock Details View

/// The result: a header card followed by the Valuation, Performance & Risk
/// and AI Analysis cards.
struct StockDetailsView: View {
    let stock: StockResponse
    let ticker: String
    
    var body: some View {
        VStack(spacing: 20) {
            HeaderCard(stock: stock, ticker: ticker)
            ValuationCard(stock: stock)
            PerformanceCard(stock: stock)
            AISummaryCard(stock: stock)
        }
    }
}

// MARK: - Header Card
struct HeaderCard: View {
    let stock: StockResponse
    let ticker: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(stock.name ?? ticker.uppercased())
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 12) {
                Text(ticker.uppercased())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
                
                if let sector = stock.sector ?? stock.summary?.sector {
                    Text(sector)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accentColor)
                        .cornerRadius(8)
                }
            }
            
            if let industry = stock.summary?.industry {
                Text(industry)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }
}

// MARK: - Valuation Card
struct ValuationCard: View {
    let stock: StockResponse
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Valuation")
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                MetricRow(
                    icon: "dollarsign.circle.fill",
                    title: "Current Price",
                    value: Formatters.currency(stock.price),
                    color: .green
                )
                
                Divider()
                
                MetricRow(
                    icon: "building.2.fill",
                    title: "Market Cap",
                    value: Formatters.marketCap(stock.market_cap),
                    color: .blue
                )
                
                Divider()
                
                MetricRow(
                    icon: "chart.bar.fill",
                    title: "P/E Ratio",
                    value: Formatters.ratio(stock.pe_ratio),
                    color: .orange
                )
            }
        }
        .cardStyle()
    }
}

// MARK: - Performance & Risk Card
struct PerformanceCard: View {
    let stock: StockResponse
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance & Risk")
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                MetricRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Annualized Return",
                    value: Formatters.percentage(stock.annualized_return),
                    color: (stock.annualized_return ?? 0) >= 0 ? .green : .red
                )
                
                Divider()
                
                MetricRow(
                    icon: "waveform.path.ecg",
                    title: "Volatility",
                    value: Formatters.percentage(stock.volatility),
                    color: .purple
                )
                
                Divider()
                
                MetricRow(
                    icon: "arrow.up.right.circle.fill",
                    title: "Sharpe Ratio",
                    value: Formatters.ratio(stock.sharpe_ratio),
                    color: .cyan
                )
                
                Divider()
                
                MetricRow(
                    icon: "arrow.down.right.circle.fill",
                    title: "Max Drawdown",
                    value: Formatters.percentage(stock.max_drawdown),
                    color: .red
                )
            }
        }
        .cardStyle()
    }
}

// MARK: - AI Summary Card
struct AISummaryCard: View {
    let stock: StockResponse
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                Text("AI Analysis (not financial advice)")
                    .font(.headline)
            }
            .foregroundColor(.secondary)
            
            if let summary = stock.ai_summary, !summary.isEmpty {
                Text(summary)
                    .font(.body)
                    .lineSpacing(4)
            } else {
                Text("No analysis available")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

// MARK: - Metric Row Component
struct MetricRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
                .frame(width: 28)
            
            Text(title)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

// MARK: - Card Style
private extension View {
    /// The rounded, softly shadowed container shared by every card.
    func cardStyle() -> some View {
        self
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}
