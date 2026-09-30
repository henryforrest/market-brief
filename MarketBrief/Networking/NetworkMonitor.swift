//
//  NetworkMonitor.swift
//  MarketBrief
//
//  Created by Henry Forrest on 30/09/2026.
//

import Foundation
import Combine
import Network

// MARK: - Network Monitor

/// Publishes the device's connectivity and interface type on the main queue,
/// driving the offline banner and the request button.
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
