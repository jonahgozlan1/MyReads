//
//  Message.swift
//  MyReads
//
//  Created by Jonah Gozlan on 1/22/26.
//

import Foundation
import SwiftData

/// Represents a single message in a conversation
@Model
final class Message {
    var id: UUID
    var role: MessageRole
    var content: String
    var createdAt: Date
    var isStreaming: Bool // For streaming responses
    
    enum MessageRole: String, Codable {
        case user
        case assistant
        case system
    }
    
    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        isStreaming: Bool = false
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = Date()
        self.isStreaming = isStreaming
    }
}
