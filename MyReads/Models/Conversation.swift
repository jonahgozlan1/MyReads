//
//  Conversation.swift
//  MyReads
//
//  Created by Jonah Gozlan on 1/22/26.
//

import Foundation
import SwiftData

/// Represents a conversation thread about a specific book
@Model
final class Conversation {
    var id: UUID
    var bookID: UUID
    var createdAt: Date
    var updatedAt: Date
    
    @Relationship(deleteRule: .cascade) var messages: [Message]?
    
    init(bookID: UUID) {
        self.id = UUID()
        self.bookID = bookID
        self.createdAt = Date()
        self.updatedAt = Date()
        self.messages = []
    }
    
    /// Adds a new message to the conversation
    func addMessage(_ message: Message) {
        messages?.append(message)
        updatedAt = Date()
    }
    
    /// Gets all messages sorted by creation date
    var sortedMessages: [Message] {
        (messages ?? []).sorted { $0.createdAt < $1.createdAt }
    }
}
