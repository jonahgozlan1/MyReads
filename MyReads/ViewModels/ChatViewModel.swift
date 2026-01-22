//
//  ChatViewModel.swift
//  MyReads
//
//  Created by Jonah Gozlan on 1/22/26.
//

import Foundation
import SwiftData

/// ViewModel for the chat interface
@Observable
final class ChatViewModel {
    var messages: [Message] = []
    var currentMessage: String = ""
    var isSending: Bool = false
    var errorMessage: String?
    
    private let aiChatService = AIChatService.shared
    private var conversation: Conversation?
    private var book: Book?
    private var modelContext: ModelContext?
    
    /// Initializes the chat with a book and conversation
    func setup(book: Book, conversation: Conversation?, modelContext: ModelContext) {
        self.book = book
        self.modelContext = modelContext
        
        if let existingConversation = conversation {
            self.conversation = existingConversation
            self.messages = existingConversation.sortedMessages
        } else {
            // Create new conversation
            let newConversation = Conversation(bookID: book.id)
            modelContext.insert(newConversation)
            self.conversation = newConversation
            self.messages = []
            
            do {
                try modelContext.save()
            } catch {
                print("Error creating conversation: \(error.localizedDescription)")
            }
        }
    }
    
    /// Sends a message to the AI
    func sendMessage() async {
        guard !currentMessage.trimmingCharacters(in: .whitespaces).isEmpty,
              let book = book,
              let conversation = conversation,
              let modelContext = modelContext else {
            return
        }
        
        let userMessageText = currentMessage
        currentMessage = ""
        isSending = true
        errorMessage = nil
        
        // Create user message
        let userMessage = Message(role: .user, content: userMessageText)
        modelContext.insert(userMessage)
        conversation.addMessage(userMessage)
        messages.append(userMessage)
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving user message: \(error.localizedDescription)")
        }
        
        // Create assistant message for streaming
        let assistantMessage = Message(role: .assistant, content: "", isStreaming: true)
        modelContext.insert(assistantMessage)
        conversation.addMessage(assistantMessage)
        messages.append(assistantMessage)
        
        // Stream response from AI
        do {
            var fullResponse = ""
            for try await chunk in try await aiChatService.sendMessage(
                userMessage: userMessageText,
                book: book,
                conversationHistory: messages.filter { $0.id != assistantMessage.id }
            ) {
                fullResponse += chunk
                assistantMessage.content = fullResponse
                assistantMessage.isStreaming = true
            }
            
            assistantMessage.isStreaming = false
            
            do {
                try modelContext.save()
            } catch {
                print("Error saving assistant message: \(error.localizedDescription)")
            }
        } catch {
            errorMessage = error.localizedDescription
            modelContext.delete(assistantMessage)
            messages.removeAll { $0.id == assistantMessage.id }
            
            do {
                try modelContext.save()
            } catch {
                print("Error cleaning up failed message: \(error.localizedDescription)")
            }
        }
        
        isSending = false
    }
}
