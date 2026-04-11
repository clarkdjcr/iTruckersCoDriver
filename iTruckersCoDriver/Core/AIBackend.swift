//
//  AIBackend.swift
//  iTruckersCoDriver
//
//  Identifies which AI backend powers the Co-Driver voice experience.
//

import Foundation

enum AIBackend: String, CaseIterable {
    case appleIntelligence = "appleIntelligence"
    case claude = "claude"

    var displayName: String {
        switch self {
        case .appleIntelligence: return "Apple Intelligence"
        case .claude: return "Claude (Anthropic)"
        }
    }

    var iconName: String {
        switch self {
        case .appleIntelligence: return "apple.logo"
        case .claude: return "brain"
        }
    }

    var modelLabel: String {
        switch self {
        case .appleIntelligence: return "On-Device (Apple Intelligence)"
        case .claude: return "Claude Opus 4.6"
        }
    }
}
