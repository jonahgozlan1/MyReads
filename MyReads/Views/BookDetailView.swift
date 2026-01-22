//
//  BookDetailView.swift
//  MyReads
//
//  Created by Jonah Gozlan on 1/22/26.
//

import SwiftUI
import SwiftData
import UIKit

/// Detail view for a book with reading progress and chat access
struct BookDetailView: View {
    @Bindable var book: Book
    @Environment(\.modelContext) private var modelContext
    @Query private var conversations: [Conversation]
    
    @State private var showingChat = false
    @State private var showingProgressEditor = false
    
    private var bookConversation: Conversation? {
        conversations.first { $0.bookID == book.id }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Hero Cover Image
                Group {
                    if let coverData = book.coverImageData,
                       let uiImage = UIImage(data: coverData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else if let coverURL = book.coverImageURL {
                        AsyncImage(url: URL(string: coverURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            BookPlaceholderView()
                                .frame(height: 400)
                        }
                    } else {
                        BookPlaceholderView()
                            .frame(height: 400)
                    }
                }
                .frame(maxHeight: 400)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                
                // Book Information
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(book.title)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text(book.author)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    
                    Divider()
                    
                    // Reading Progress
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Reading Progress")
                                .font(.headline)
                            
                            Spacer()
                            
                            if book.totalPages != nil {
                                Text("\(book.progressPercentage)%")
                                    .font(.headline)
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        
                        if let totalPages = book.totalPages {
                            ProgressView(value: book.readingProgress)
                                .tint(.accentColor)
                                .frame(height: 8)
                            
                            if let ch = book.currentChapter, !ch.isEmpty {
                                Text(ch)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            
                            HStack {
                                Text("Page \(book.currentPage) of \(totalPages)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                Spacer()
                                
                                Button {
                                    showingProgressEditor = true
                                } label: {
                                    Text("Update")
                                        .font(.subheadline)
                                }
                            }
                        } else {
                            if let ch = book.currentChapter, !ch.isEmpty {
                                Text(ch)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Button {
                                showingProgressEditor = true
                            } label: {
                                HStack {
                                    Text("Update Progress")
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                                Button {
                                    // Haptic feedback
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                    
                                    showingChat = true
                                } label: {
                                    HStack {
                                        Image(systemName: "message.fill")
                                        Text("Start Conversation")
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                    }
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.accentColor)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 32)
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingChat) {
            ChatView(book: book, conversation: bookConversation)
        }
        .sheet(isPresented: $showingProgressEditor) {
            ProgressEditorView(book: book)
        }
            .task {
                // Load cover image if needed
                await loadCoverImage()
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: book.readingProgress)
    }
    
    /// Loads and caches the cover image
    private func loadCoverImage() async {
        guard book.coverImageData == nil,
              let coverURL = book.coverImageURL,
              let url = URL(string: coverURL) else {
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            await MainActor.run {
                book.coverImageData = data
            }
        } catch {
            print("Error loading cover image: \(error.localizedDescription)")
        }
    }
}

#Preview {
    let container = PersistenceController.preview
    let book = Book(
        title: "The Great Gatsby",
        author: "F. Scott Fitzgerald",
        totalPages: 180,
        chapters: ["Chapter 1", "Chapter 2", "Chapter 3", "Chapter 4", "Chapter 5"]
    )
    book.currentChapter = "Chapter 1"
    book.currentPage = 36
    book.updateProgress(page: 36)
    container.mainContext.insert(book)
    return NavigationStack {
        BookDetailView(book: book)
    }
    .modelContainer(container)
}
