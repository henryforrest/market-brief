//
//  ContentView.swift
//  MarketBrief
//
//  Created by Henry Forrest on 26/01/2026.
//

import SwiftUI
import Network

// MARK: - Security Configuration
struct SecurityConfig {
    // IMPORTANT: Always use the same URL for all builds
    static let baseURL = "https://marketbrief-back-end.fly.dev"
    
    // Rate limiting
    static let maxRequestsPerMinute = 10
    static let requestCooldownSeconds = 6
}

// MARK: - Rate Limiter
actor RateLimiter {
    private var requestTimestamps: [TimeInterval] = []
    private let maxRequests: Int
    private let timeWindow: TimeInterval
    private let maxTimestampAge: TimeInterval = 3600 // 1 hour safety
    
    init(maxRequests: Int, perSeconds: TimeInterval) {
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

// MARK: - Security Alert Handler
class SecurityAlertHandler: ObservableObject {
    @Published var showSecurityAlert = false
    @Published var securityMessage = ""
    
    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSecurityAlert),
            name: NSNotification.Name("SecurityAlert"),
            object: nil
        )
    }
    
    @objc private func handleSecurityAlert(_ notification: Notification) {
        if let message = notification.userInfo?["message"] as? String {
            DispatchQueue.main.async {
                self.securityMessage = message
                self.showSecurityAlert = true
            }
        }
    }
}

// MARK: - Network Monitor
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    private let monitor = NWPathMonitor()
    @Published var isConnected = true
    @Published var connectionType = "unknown"
    
    private init() {
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                self.isConnected = path.status == .satisfied
                if path.usesInterfaceType(.wifi) {
                    self.connectionType = "WiFi"
                } else if path.usesInterfaceType(.cellular) {
                    self.connectionType = "Cellular"
                } else {
                    self.connectionType = "other"
                }
            }
        }
        monitor.start(queue: DispatchQueue.global(qos: .background))
    }
}

// MARK: - Secure Storage
class SecureStorage {
    static func clearSensitiveData() {
        UserDefaults.standard.removeObject(forKey: "lastTicker")
        UserDefaults.standard.synchronize()
    }
}

// MARK: - Stock Error
enum StockError: LocalizedError {
    case invalidTicker
    case networkUnavailable
    case notFound
    case rateLimited
    case serverError
    case securityValidationFailed
    case invalidResponse
    
    var errorDescription: String {
        switch self {
        case .invalidTicker:
            return "Please enter a valid stock ticker (1-5 letters)"
        case .networkUnavailable:
            return "No internet connection. Please check your network."
        case .notFound:
            return "Stock not found. Please check the ticker symbol."
        case .rateLimited:
            return "Too many requests. Please wait a few seconds."
        case .serverError:
            return "Server error. Please try again later."
        case .securityValidationFailed:
            return "⚠️ Secure connection could not be established"
        case .invalidResponse:
            return "Unable to parse stock data"
        }
    }
}

// MARK: - Content View
struct ContentView: View {
    @State private var ticker = ""
    @State private var stock: StockResponse?
    @State private var isLoading = false
    @State private var error: Error?
    @State private var showingClearConfirmation = false
    @FocusState private var isTextFieldFocused: Bool
    @StateObject private var securityHandler = SecurityAlertHandler()
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @State private var rateLimiter = RateLimiter(
        maxRequests: SecurityConfig.maxRequestsPerMinute,
        perSeconds: 60
    )
    @State private var lastRequestTime: Date?
    @Environment(\.scenePhase) private var scenePhase
    
    // URLSession relying on the system trust store for TLS validation
    private let secureSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()
    
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
                            stockDetailsView(stock: stock)
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
                        Image(systemName: "lock.shield")
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel("Security settings")
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
                        ticker = newValue.uppercased().filter { $0.isLetter }
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
        let cleaned = ticker.trimmingCharacters(in: .whitespacesAndNewlines)
        return !cleaned.isEmpty &&
               cleaned.count <= 5 &&
               cleaned.allSatisfy({ $0.isLetter })
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
    
    // MARK: - Gradient Loader
    struct GradientLoader: View {
        @State private var animate = false
        
        var body: some View {
            Circle()
                .trim(from: 0.15, to: 1)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [.blue, .purple, .pink, .blue]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .frame(width: 60, height: 60)
                .rotationEffect(.degrees(animate ? 360 : 0))
                .animation(.linear(duration: 1.4).repeatForever(autoreverses: false), value: animate)
                .onAppear { animate = true }
        }
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
    private func errorView(error: Error) -> some View {
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
            
            if let stockError = error as? StockError,
               stockError == .rateLimited {
                Text("Please wait \(SecurityConfig.requestCooldownSeconds) seconds")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Stock Details View
    private func stockDetailsView(stock: StockResponse) -> some View {
        VStack(spacing: 20) {
            headerSection(stock: stock)
            priceMetricsSection(stock: stock)
            performanceMetricsSection(stock: stock)
            aiSummarySection(stock: stock)
        }
    }
    
    private func headerSection(stock: StockResponse) -> some View {
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
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    private func priceMetricsSection(stock: StockResponse) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Valuation")
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                MetricRow(
                    icon: "dollarsign.circle.fill",
                    title: "Current Price",
                    value: formatCurrency(stock.price),
                    color: .green
                )
                
                Divider()
                
                MetricRow(
                    icon: "building.2.fill",
                    title: "Market Cap",
                    value: formatMarketCap(stock.market_cap),
                    color: .blue
                )
                
                Divider()
                
                MetricRow(
                    icon: "chart.bar.fill",
                    title: "P/E Ratio",
                    value: formatPERatio(stock.pe_ratio),
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    private func performanceMetricsSection(stock: StockResponse) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance & Risk")
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                MetricRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Annualized Return",
                    value: formatPercentage(stock.annualized_return),
                    color: (stock.annualized_return ?? 0) >= 0 ? .green : .red
                )
                
                Divider()
                
                MetricRow(
                    icon: "waveform.path.ecg",
                    title: "Volatility",
                    value: formatPercentage(stock.volatility),
                    color: .purple
                )
                
                Divider()
                
                MetricRow(
                    icon: "arrow.up.right.circle.fill",
                    title: "Sharpe Ratio",
                    value: formatRatio(stock.sharpe_ratio),
                    color: .cyan
                )
                
                Divider()
                
                MetricRow(
                    icon: "arrow.down.right.circle.fill",
                    title: "Max Drawdown",
                    value: formatPercentage(stock.max_drawdown),
                    color: .red
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    private func aiSummarySection(stock: StockResponse) -> some View {
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
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Network Request
    @MainActor
    func fetchStock() async {
        // Validation
        let cleanedTicker = ticker.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard isValidTicker else {
            self.error = StockError.invalidTicker
            return
        }
        
        guard networkMonitor.isConnected else {
            self.error = StockError.networkUnavailable
            return
        }
        
        // Rate limiting
        let canMakeRequest = await rateLimiter.canMakeRequest()
        guard canMakeRequest else {
            self.error = StockError.rateLimited
            return
        }
        
        // Security check - warn on untrusted networks
        if networkMonitor.connectionType == "other" {
            NotificationCenter.default.post(
                name: NSNotification.Name("SecurityAlert"),
                object: nil,
                userInfo: ["message": "Connected to unknown network. Proceed with caution."]
            )
        }
        
        ticker = cleanedTicker
        isLoading = true
        error = nil
        stock = nil
        isTextFieldFocused = false
        
        // URL construction with percent encoding
        guard let encodedTicker = cleanedTicker.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(SecurityConfig.baseURL)/stock/\(encodedTicker)") else {
            self.error = StockError.invalidTicker
            isLoading = false
            return
        }
        
        print("🌐 Fetching URL: \(url)")
        print("BASE URL: \(SecurityConfig.baseURL)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30
        
        do {
            let (data, response) = try await secureSession.data(for: request)
            
            // Print raw response for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📦 Raw JSON response: \(jsonString)")
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw StockError.invalidResponse
            }
            
            print("📡 HTTP Status: \(httpResponse.statusCode)")
            
            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()
                
                do {
                    let decoded = try decoder.decode(StockResponse.self, from: data)
                    
                    self.stock = decoded
                    self.error = nil
                    print("✅ Successfully decoded stock data for: \(cleanedTicker)")
                    
                } catch let decodingError {
                    print("❌ Decoding error: \(decodingError)")
                    
                    // Try manual decoding to find the issue
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("📊 All JSON keys: \(json.keys)")
                    }
                    
                    throw StockError.invalidResponse
                }
                
            case 404:
                print("❌ 404 - Stock not found")
                throw StockError.notFound
            case 429:
                print("⚠️ 429 - Rate limited")
                throw StockError.rateLimited
            case 500...599:
                print("🔥 Server error: \(httpResponse.statusCode)")
                throw StockError.serverError
            default:
                print("❌ Unexpected status: \(httpResponse.statusCode)")
                throw StockError.invalidResponse
            }
            
        } catch let error as StockError {
            self.error = error
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet:
                self.error = StockError.networkUnavailable
            case .secureConnectionFailed, .serverCertificateUntrusted:
                self.error = StockError.securityValidationFailed
            default:
                print("🌐 URL Error: \(error)")
                self.error = StockError.serverError
            }
        } catch {
            print("❌ Unknown error: \(error)")
            self.error = StockError.serverError
        }
        
        isLoading = false
        lastRequestTime = Date()
    }
    
    // MARK: - Clear Data
    private func clearAllData() {
        stock = nil
        error = nil
        ticker = ""
        SecureStorage.clearSensitiveData()
    }
    
    // MARK: - Formatting Helpers
    private func formatCurrency(_ value: Double?) -> String {
        guard let value = value else { return "N/A" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "N/A"
    }
    
    private func formatMarketCap(_ value: Double?) -> String {
        guard let value = value else { return "N/A" }
        if value >= 1_000_000_000_000 {
            return String(format: "$%.2fT", value / 1_000_000_000_000)
        } else if value >= 1_000_000_000 {
            return String(format: "$%.2fB", value / 1_000_000_000)
        } else if value >= 1_000_000 {
            return String(format: "$%.2fM", value / 1_000_000)
        } else {
            return String(format: "$%.2f", value)
        }
    }
    
    private func formatPERatio(_ value: Double?) -> String {
        guard let value = value else { return "N/A" }
        return String(format: "%.2f", value)
    }
    
    private func formatPercentage(_ value: Double?) -> String {
        guard let value = value else { return "N/A" }
        return String(format: "%.2f%%", value * 100)
    }
    
    private func formatRatio(_ value: Double?) -> String {
        guard let value = value else { return "N/A" }
        return String(format: "%.2f", value)
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

// MARK: - Preview
#Preview {
    ContentView()
}
