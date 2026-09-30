//
//  ContentView.swift
//  MarketBrief
//
//  Created by Henry Forrest on 26/01/2026.
//

import SwiftUI

// MARK: - Content View
struct ContentView: View {
    @State private var ticker = ""
    @State private var stock: StockResponse?
    @State private var isLoading = false
    @State private var error: StockError?
    @State private var showingClearConfirmation = false
    @FocusState private var isTextFieldFocused: Bool
    @StateObject private var securityHandler = SecurityAlertHandler()
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @State private var rateLimiter = RateLimiter()
    @Environment(\.scenePhase) private var scenePhase
    
    private let stockService = StockService()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Security warning banner
                        if !networkMonitor.isConnected {
                            securityBanner(
                                message: "No internet connection",
                                icon: "wifi.slash",
                                color: .orange
                            )
                        } else if networkMonitor.connectionType == "other" {
                            securityBanner(
                                message: "Connected to unknown network",
                                icon: "exclamationmark.shield",
                                color: .yellow
                            )
                        }
                        
                        searchSection
                        
                        if isLoading {
                            loadingView
                        } else if let error = error {
                            errorView(error: error)
                        } else if let stock = stock {
                            StockDetailsView(stock: stock, ticker: ticker)
                                .onDisappear {
                                    // Clear sensitive data when view disappears
                                    if !isLoading {
                                        self.stock = nil
                                    }
                                }
                        } else {
                            emptyStateView
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Market Brief")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingClearConfirmation = true }) {
                        Image(systemName: "trash")
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel("Clear result")
                }
            }
            .alert("Security Alert", isPresented: $securityHandler.showSecurityAlert) {
                Button("OK", role: .cancel) { }
                Button("Clear Data", role: .destructive) {
                    clearAllData()
                }
            } message: {
                Text(securityHandler.securityMessage)
            }
            .alert("Clear Sensitive Data", isPresented: $showingClearConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    clearAllData()
                }
            } message: {
                Text("This will clear all stock data from memory.")
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                Task {
                    await rateLimiter.resetIfNeeded()
                }
            }
        }
    }
    
    // MARK: - Security Banner
    private func securityBanner(message: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
            Text(message)
            Spacer()
        }
        .font(.caption)
        .foregroundColor(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Search Section
    private var searchSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Enter ticker symbol", text: $ticker)
                    .textFieldStyle(.plain)
                    .autocapitalization(.allCharacters)
                    .disableAutocorrection(true)
                    .focused($isTextFieldFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        Task {
                            await fetchStock()
                        }
                    }
                    .onChange(of: ticker) { oldValue, newValue in
                        // Auto-uppercase and filter
                        ticker = TickerSymbol.sanitised(newValue)
                    }
                
                if !ticker.isEmpty {
                    Button(action: { ticker = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            
            Button(action: {
                Task {
                    await fetchStock()
                }
            }) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Analyze Stock")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isValidTicker && !isLoading && networkMonitor.isConnected ? Color.accentColor : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!isValidTicker || isLoading || !networkMonitor.isConnected)
        }
    }
    
    // MARK: - Ticker Validation
    private var isValidTicker: Bool {
        TickerSymbol.isValid(ticker)
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 20) {
            GradientLoader()
            Text("Analyzing \(ticker.uppercased())...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("Get Started")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Enter a stock ticker symbol above to view detailed analysis")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if !networkMonitor.isConnected {
                Text("⚠️ You appear to be offline")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
    
    // MARK: - Error View
    private func errorView(error: StockError) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                
                Text(error.localizedDescription)
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
            
            if error == .rateLimited {
                Text("Please wait \(SecurityConfig.requestCooldownSeconds) seconds")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Network Request
    @MainActor
    func fetchStock() async {
        // Validation
        let cleanedTicker = ticker.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard isValidTicker else {
            error = .invalidTicker
            return
        }
        
        guard networkMonitor.isConnected else {
            error = .networkUnavailable
            return
        }
        
        // Rate limiting
        guard await rateLimiter.canMakeRequest() else {
            error = .rateLimited
            return
        }
        
        // Security check - warn on untrusted networks
        if networkMonitor.connectionType == "other" {
            NotificationCenter.default.post(
                name: .securityAlert,
                object: nil,
                userInfo: ["message": "Connected to unknown network. Proceed with caution."]
            )
        }
        
        ticker = cleanedTicker
        isLoading = true
        error = nil
        stock = nil
        isTextFieldFocused = false
        
        do {
            stock = try await stockService.fetch(ticker: cleanedTicker)
        } catch {
            self.error = error as? StockError ?? .serverError
        }
        
        isLoading = false
    }
    
    // MARK: - Clear Data
    private func clearAllData() {
        stock = nil
        error = nil
        ticker = ""
    }
}

// MARK: - Preview
#Preview {
    ContentView()
}
