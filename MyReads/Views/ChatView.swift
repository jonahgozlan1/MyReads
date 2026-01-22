//
//  ChatView.swift
//  MyReads
//
//  Created by Jonah Gozlan on 1/22/26.
//

import SwiftUI
import SwiftData
import UIKit

/// Chat interface for conversing with AI about a book
struct ChatView: View {
    let book: Book
    let conversation: Conversation?
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var viewModel = ChatViewModel()
    @FocusState private var isInputFocused: Bool
    @State private var showingAPIKeyAlert = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages List
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            // Welcome message
                            if viewModel.messages.isEmpty {
                                WelcomeMessageView(book: book)
                                    .padding(.top, 32)
                            }
                            
                            // Chat messages
                            ForEach(viewModel.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                            
                            // Loading indicator
                            if viewModel.isSending {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Thinking...")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        if let lastMessage = viewModel.messages.last {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: viewModel.messages.last?.content) { _, _ in
                        if let lastMessage = viewModel.messages.last {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Error message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
                
                // Input Area
                HStack(spacing: 12) {
                    TextField("Ask about the book...", text: $viewModel.currentMessage, axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .focused($isInputFocused)
                        .lineLimit(1...4)
                        .disabled(viewModel.isSending)
                    
                    Button {
                        // Haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        
                        Task {
                            await viewModel.sendMessage()
                        }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(
                                viewModel.currentMessage.isEmpty || viewModel.isSending
                                ? .gray
                                : .accentColor
                            )
                    }
                    .disabled(viewModel.currentMessage.isEmpty || viewModel.isSending)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
            }
            .navigationTitle(book.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                viewModel.setup(book: book, conversation: conversation, modelContext: modelContext)
                
                // Check if API key is configured
                if !KeychainService.shared.hasAPIKey {
                    showingAPIKeyAlert = true
                }
            }
            .alert("API Key Required", isPresented: $showingAPIKeyAlert) {
                Button("Open Settings") {
                    dismiss()
                    // Note: In a real app, you might want to navigate to settings
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Please configure your OpenAI API key in Settings to use the chat feature.")
            }
        }
    }
}

/// Individual message bubble
private struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .foregroundStyle(message.role == .user ? .white : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        message.role == .user
                        ? Color.accentColor
                        : Color(.systemGray5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                
                if message.isStreaming {
                    ProgressView()
                        .scaleEffect(0.7)
                        .padding(.top, 4)
                }
            }
            
            if message.role == .assistant {
                Spacer(minLength: 60)
            }
        }
    }
}

/// Welcome message when chat is empty
private struct WelcomeMessageView: View {
    let book: Book
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "message.bubble.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)
            
            VStack(spacing: 8) {
                Text("Ask About \(book.title)")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("I can help you understand characters, clarify plot points, and remind you of what happened—all without spoiling what's ahead.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
    }
}

#Preview {
    ChatView(
        book: Book(
            title: "The Great Gatsby",
            author: "F. Scott Fitzgerald",
            totalPages: 180
        ),
        conversation: nil
    )
    .modelContainer(PersistenceController.preview)
}
