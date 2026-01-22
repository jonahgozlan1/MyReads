//
//  AIChatService.swift
//  MyReads
//
//  Created by Jonah Gozlan on 1/22/26.
//

import Foundation

/// Service for interacting with OpenAI API for book conversations
@MainActor
final class AIChatService {
    static let shared = AIChatService()
    
    private let apiURL = "https://api.openai.com/v1/chat/completions"
    private let keychainService = KeychainService.shared
    
    private init() {}
    
    /// Sends a message to OpenAI and returns a streaming response
    func sendMessage(
        userMessage: String,
        book: Book,
        conversationHistory: [Message]
    ) async throws -> AsyncThrowingStream<String, Error> {
        guard let apiKey = keychainService.getAPIKey(), !apiKey.isEmpty else {
            throw AIChatError.noAPIKey
        }
        
        // Build context from book and reading progress
        let systemPrompt = buildSystemPrompt(book: book)
        
        // Build messages array
        var messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt]
        ]
        
        // Add conversation history (last 10 messages to manage token usage)
        let recentHistory = Array(conversationHistory.suffix(10))
        for message in recentHistory {
            messages.append([
                "role": message.role.rawValue,
                "content": message.content
            ])
        }
        
        // Add current user message
        messages.append([
            "role": "user",
            "content": userMessage
        ])
        
        // Create request
        guard let url = URL(string: apiURL) else {
            throw AIChatError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini", // Using mini for cost efficiency, can be upgraded
            "messages": messages,
            "stream": true,
            "temperature": 0.7
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // Perform streaming request
        let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AIChatError.networkError
        }
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in asyncBytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))
                            
                            if jsonString == "[DONE]" {
                                continuation.finish()
                                return
                            }
                            
                            guard let data = jsonString.data(using: .utf8),
                                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                                  let choices = json["choices"] as? [[String: Any]],
                                  let firstChoice = choices.first,
                                  let delta = firstChoice["delta"] as? [String: Any],
                                  let content = delta["content"] as? String else {
                                continue
                            }
                            
                            continuation.yield(content)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    /// Builds the system prompt with book context and spoiler prevention
    private func buildSystemPrompt(book: Book) -> String {
        var prompt = """
        You are a helpful reading companion for the book "\(book.title)" by \(book.author).
        
        Your role is to:
        1. Answer questions about the book based ONLY on what the reader has read so far
        2. Clarify characters, plot points, and themes up to their current reading position
        3. Remind them of what happened earlier in the book
        4. Help deepen their understanding without spoiling future events
        
        CRITICAL: The reader is currently on page \(book.currentPage)\(book.totalPages != nil ? " of \(book.totalPages!)" : "").
        You must NEVER reveal anything that happens after page \(book.currentPage).
        If asked about future events, politely decline and suggest they continue reading.
        
        """
        
        if let summary = book.summary {
            prompt += "Book Summary: \(summary)\n\n"
        }
        
        // Add text context up to current position if available
        if let textUpToPosition = book.getTextUpToCurrentPosition() {
            let contextLength = min(textUpToPosition.count, 8000) // Limit context size
            let context = String(textUpToPosition.prefix(contextLength))
            prompt += "Context from the book (up to reader's current position):\n\(context)\n\n"
        }
        
        prompt += """
        Be conversational, helpful, and engaging. Use the book's tone and style when appropriate.
        Always be mindful of spoilers and respect the reader's journey through the book.
        """
        
        return prompt
    }
}

enum AIChatError: LocalizedError {
    case noAPIKey
    case invalidURL
    case networkError
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "OpenAI API key not configured. Please add your API key in Settings."
        case .invalidURL:
            return "Invalid API URL"
        case .networkError:
            return "Network error occurred"
        case .decodingError:
            return "Failed to decode response"
        }
    }
}
