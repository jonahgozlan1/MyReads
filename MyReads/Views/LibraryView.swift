//
//  LibraryView.swift
//  MyReads
//
//  Created by Jonah Gozlan on 1/22/26.
//

import SwiftUI
import SwiftData
import UIKit

/// Main library view showing all books with covers as hero elements
struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.dateAdded, order: .reverse) private var books: [Book]
    
    @State private var viewModel = LibraryViewModel()
    @State private var showingSettings = false
    @State private var bookToDelete: Book?
    
    var body: some View {
        NavigationStack {
            ZStack {
                if books.isEmpty && !viewModel.isSearching {
                    EmptyLibraryView(viewModel: viewModel)
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ],
                            spacing: 16
                        ) {
                            ForEach(books) { book in
                                NavigationLink {
                                    BookChatView(book: book)
                                } label: {
                                    BookCoverCard(book: book)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        bookToDelete = book
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .transition(.asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .opacity
                                ))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            .navigationTitle("My Reads")
            .searchable(
                text: $viewModel.searchText,
                isPresented: $viewModel.isSearching,
                placement: .navigationBarDrawer(displayMode: .always)
            )
            .searchSuggestions {
                if viewModel.isSearching && !viewModel.searchText.isEmpty {
                    SearchSuggestionsView(viewModel: viewModel, modelContext: modelContext)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.primary)
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .confirmationDialog(
                "Delete Book",
                isPresented: Binding(
                    get: { bookToDelete != nil },
                    set: { if !$0 { bookToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let book = bookToDelete {
                    Button("Delete", role: .destructive) {
                        viewModel.deleteBook(book, modelContext: modelContext)
                        bookToDelete = nil
                    }
                    Button("Cancel", role: .cancel) {
                        bookToDelete = nil
                    }
                }
            } message: {
                if let book = bookToDelete {
                    Text("Are you sure you want to delete \"\(book.title)\"? This will also delete all conversations about this book.")
                }
            }
            .task(id: viewModel.searchText) {
                if !viewModel.searchText.isEmpty {
                    await viewModel.searchBooks()
                } else {
                    viewModel.searchResults = []
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: books.count)
        }
    }
}

/// Empty state view for when library is empty
private struct EmptyLibraryView: View {
    @Bindable var viewModel: LibraryViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                Text("Your Library is Empty")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Search for books to add to your reading list")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
        }
    }
}

/// Book cover card component
private struct BookCoverCard: View {
    let book: Book
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cover Image
            Group {
                if let coverData = book.coverImageData,
                   let uiImage = UIImage(data: coverData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if let coverURL = book.coverImageURL {
                    AsyncImage(url: URL(string: coverURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        BookPlaceholderView()
                    }
                } else {
                    BookPlaceholderView()
                }
            }
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
            
            // Book Info
            VStack(alignment: .leading, spacing: 3) {
                Text(book.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .foregroundStyle(.primary)
                
                Text(book.author)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                // Progress indicator
                if book.totalPages != nil && book.currentPage > 0 {
                    ProgressView(value: book.readingProgress)
                        .tint(.accentColor)
                        .frame(height: 3)
                    
                    Text("\(book.currentPage) of \(book.totalPages ?? 0) pages")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// Search suggestions view
private struct SearchSuggestionsView: View {
    @Bindable var viewModel: LibraryViewModel
    let modelContext: ModelContext
    
    var body: some View {
        if viewModel.isLoadingSearch {
            HStack {
                ProgressView()
                Text("Searching...")
                    .foregroundStyle(.secondary)
            }
            .padding()
        } else if let error = viewModel.searchError {
            Text("Error: \(error)")
                .foregroundStyle(.red)
                .padding()
        } else if viewModel.searchResults.isEmpty {
            Text("No results found")
                .foregroundStyle(.secondary)
                .padding()
        } else {
            ForEach(viewModel.searchResults) { result in
                Button {
                    Task {
                        await viewModel.addBook(result, modelContext: modelContext)
                        viewModel.isSearching = false
                        viewModel.searchText = ""
                    }
                } label: {
                    HStack(spacing: 12) {
                        // Cover thumbnail
                        Group {
                            if let coverURL = result.coverImageURL {
                                AsyncImage(url: URL(string: coverURL)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    BookPlaceholderView()
                                }
                            } else {
                                BookPlaceholderView()
                            }
                        }
                        .frame(width: 50, height: 75)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(result.title)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                            
                            Text(result.author)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }
}

#Preview {
    LibraryView()
        .modelContainer(PersistenceController.preview)
}
