//
//  SecurityAlertHandler.swift
//  MarketBrief
//
//  Created by Henry Forrest on 30/09/2026.
//

import Foundation
import Combine

extension Notification.Name {
    /// Posted, with a "message" entry in userInfo, when a request is about to
    /// go out over an unrecognised network type.
    static let securityAlert = Notification.Name("SecurityAlert")
}

// MARK: - Security Alert Handler

/// Turns security notices posted on NotificationCenter into an alert.
class SecurityAlertHandler: ObservableObject {
    @Published var showSecurityAlert = false
    @Published var securityMessage = ""
    
    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSecurityAlert),
            name: .securityAlert,
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
